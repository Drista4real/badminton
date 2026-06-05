using backend_caulong.Models;
using Google.Cloud.Firestore;

namespace backend_caulong.Repositories;

public sealed class WalletRepository : IWalletRepository
{
    private readonly FirestoreDb _firestoreDb;

    public WalletRepository(FirestoreDb firestoreDb)
    {
        _firestoreDb = firestoreDb;
    }

    public async Task<IReadOnlyList<WalletTransactionDocument>> GetUserTransactionsAsync(
        string userId,
        int limit = 50,
        CancellationToken cancellationToken = default)
    {
        var trimmedUserId = userId.Trim();
        var topLevelSnapshot = await _firestoreDb
            .Collection("walletTransactions")
            .WhereEqualTo("userId", trimmedUserId)
            .GetSnapshotAsync(cancellationToken);

        var subCollectionSnapshot = await _firestoreDb
            .Collection("users")
            .Document(trimmedUserId)
            .Collection("walletTransactions")
            .GetSnapshotAsync(cancellationToken);

        return topLevelSnapshot.Documents
            .Concat(subCollectionSnapshot.Documents)
            .Where(document => document.Exists)
            .Select(document => document.ConvertTo<WalletTransactionDocument>())
            .GroupBy(transaction => transaction.Id, StringComparer.Ordinal)
            .Select(group => group.First())
            .OrderByDescending(transaction => transaction.CreatedAt)
            .Take(Math.Clamp(limit, 1, 100))
            .ToArray();
    }

    public async Task<WalletRefundWriteResult> RefundToWalletAsync(
        string userId,
        double amount,
        WalletRefundMetadata metadata,
        CancellationToken cancellationToken = default)
    {
        var trimmedUserId = userId.Trim();
        var now = Timestamp.FromDateTime(DateTime.UtcNow);
        var userRef = _firestoreDb.Collection("users").Document(trimmedUserId);
        var transactionRef = _firestoreDb
            .Collection("walletTransactions")
            .Document(BuildRefundTransactionId(metadata));
        WalletRefundWriteResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var userSnapshot = await transaction.GetSnapshotAsync(userRef, cancellationToken);
            var currentBalance = userSnapshot.Exists
                ? GetDouble(userSnapshot, "walletBalance")
                : 0d;
            var currentPendingWithdrawal = userSnapshot.Exists
                ? GetDouble(userSnapshot, "pendingWithdrawal")
                : 0d;
            currentPendingWithdrawal = Math.Max(0d, currentPendingWithdrawal);

            var walletTransactionSnapshot = await transaction.GetSnapshotAsync(
                transactionRef,
                cancellationToken);

            if (walletTransactionSnapshot.Exists)
            {
                result = new WalletRefundWriteResult(
                    transactionRef.Id,
                    Applied: false,
                    WalletBalance: currentBalance,
                    AvailableBalance: currentBalance - currentPendingWithdrawal);
                return;
            }

            var normalizedAmount = NormalizeMoney(amount);
            var newBalance = NormalizeMoney(currentBalance + normalizedAmount);
            var availableBalance = newBalance - currentPendingWithdrawal;

            transaction.Set(userRef, new Dictionary<string, object>
            {
                ["walletBalance"] = newBalance,
                ["availableBalance"] = availableBalance,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            transaction.Set(transactionRef, new WalletTransactionDocument
            {
                UserId = trimmedUserId,
                Amount = normalizedAmount,
                Type = WalletTransactionTypes.Refund,
                Status = WalletTransactionStatuses.Completed,
                SourceOrderId = metadata.SourceOrderId,
                ProviderTransactionId = metadata.ProviderTransactionId,
                Provider = metadata.Provider,
                Description = metadata.Description,
                CreatedAt = now,
            });

            if (!string.IsNullOrWhiteSpace(metadata.SourceOrderId))
            {
                var orderRef = _firestoreDb.Collection("orders").Document(metadata.SourceOrderId.Trim());
                transaction.Set(orderRef, new Dictionary<string, object>
                {
                    ["paymentStatus"] = "refunded",
                    ["refundStatus"] = "completed",
                    ["refundedAmount"] = FieldValue.Increment(normalizedAmount),
                    ["refundedAt"] = now,
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            result = new WalletRefundWriteResult(
                transactionRef.Id,
                Applied: true,
                WalletBalance: newBalance,
                AvailableBalance: availableBalance);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not refund to wallet.");
    }

    public async Task<WalletWithdrawWriteResult> WithdrawAsync(
        WalletWithdrawWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var trimmedUserId = request.UserId.Trim();
        var now = Timestamp.FromDateTime(DateTime.UtcNow);
        var userRef = _firestoreDb.Collection("users").Document(trimmedUserId);
        var transactionRef = _firestoreDb.Collection("walletTransactions").Document();
        var newBalance = 0d;
        var availableBalance = 0d;
        var pendingWithdrawal = 0d;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var userSnapshot = await transaction.GetSnapshotAsync(userRef, cancellationToken);
            if (!userSnapshot.Exists)
            {
                throw new InvalidOperationException($"User '{trimmedUserId}' was not found.");
            }

            var currentBalance = GetDouble(userSnapshot, "walletBalance");
            var currentPendingWithdrawal = Math.Max(0d, GetDouble(userSnapshot, "pendingWithdrawal"));
            var currentAvailableBalance = currentBalance - currentPendingWithdrawal;
            if (currentAvailableBalance < request.Amount)
            {
                throw new InsufficientWalletBalanceException();
            }

            newBalance = currentBalance;
            pendingWithdrawal = currentPendingWithdrawal + request.Amount;
            availableBalance = currentBalance - pendingWithdrawal;
            transaction.Set(userRef, new Dictionary<string, object>
            {
                ["availableBalance"] = availableBalance,
                ["pendingWithdrawal"] = pendingWithdrawal,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            transaction.Set(transactionRef, new WalletTransactionDocument
            {
                UserId = trimmedUserId,
                Amount = -request.Amount,
                Type = WalletTransactionTypes.Withdraw,
                Status = WalletTransactionStatuses.Pending,
                BankName = request.BankName,
                BankAccountNumber = request.BankAccountNumber,
                BankAccountName = request.BankAccountName,
                Description = "Withdrawal request.",
                CreatedAt = now,
            });
        }, cancellationToken: cancellationToken);

        return new WalletWithdrawWriteResult(
            transactionRef.Id,
            newBalance,
            availableBalance,
            pendingWithdrawal);
    }

    public async Task<WalletWithdrawSettlementWriteResult> SettleWithdrawAsync(
        WalletWithdrawSettlementWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var trimmedAdminUserId = request.AdminUserId.Trim();
        var trimmedTransactionId = request.TransactionId.Trim();
        var adminRef = _firestoreDb.Collection("users").Document(trimmedAdminUserId);
        var transactionRef = _firestoreDb.Collection("walletTransactions").Document(trimmedTransactionId);
        WalletWithdrawSettlementWriteResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var adminSnapshot = await transaction.GetSnapshotAsync(adminRef, cancellationToken);
            if (!adminSnapshot.Exists ||
                !string.Equals(GetString(adminSnapshot, "role"), UserRoles.Admin, StringComparison.OrdinalIgnoreCase))
            {
                throw new WalletAdminForbiddenException();
            }

            var withdrawalSnapshot = await transaction.GetSnapshotAsync(transactionRef, cancellationToken);
            if (!withdrawalSnapshot.Exists)
            {
                throw new InvalidOperationException($"Wallet transaction '{trimmedTransactionId}' was not found.");
            }

            if (!string.Equals(
                    GetString(withdrawalSnapshot, "type"),
                    WalletTransactionTypes.Withdraw,
                    StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException($"Wallet transaction '{trimmedTransactionId}' is not a withdrawal.");
            }

            var currentStatus = GetString(withdrawalSnapshot, "status");
            if (!string.Equals(currentStatus, WalletTransactionStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException($"Wallet transaction '{trimmedTransactionId}' is already settled.");
            }

            var userId = GetString(withdrawalSnapshot, "userId");
            if (string.IsNullOrWhiteSpace(userId))
            {
                throw new InvalidOperationException($"Wallet transaction '{trimmedTransactionId}' does not contain userId.");
            }

            var withdrawalAmount = Math.Abs(GetDouble(withdrawalSnapshot, "amount"));
            if (withdrawalAmount <= 0)
            {
                throw new InvalidOperationException($"Wallet transaction '{trimmedTransactionId}' does not contain a valid amount.");
            }

            var userRef = _firestoreDb.Collection("users").Document(userId);
            var userSnapshot = await transaction.GetSnapshotAsync(userRef, cancellationToken);
            if (!userSnapshot.Exists)
            {
                throw new InvalidOperationException($"User '{userId}' was not found.");
            }

            var currentBalance = GetDouble(userSnapshot, "walletBalance");
            var currentPendingWithdrawal = Math.Max(0d, GetDouble(userSnapshot, "pendingWithdrawal"));
            var settledStatus = request.Status == WalletWithdrawSettlementStatus.Success
                ? WalletTransactionStatuses.Completed
                : WalletTransactionStatuses.Failed;
            var walletBalance = request.Status == WalletWithdrawSettlementStatus.Success
                ? currentBalance - withdrawalAmount
                : currentBalance;
            var pendingWithdrawal = Math.Max(0d, currentPendingWithdrawal - withdrawalAmount);
            var availableBalance = walletBalance - pendingWithdrawal;
            var now = Timestamp.FromDateTime(DateTime.UtcNow);

            transaction.Set(userRef, new Dictionary<string, object>
            {
                ["walletBalance"] = walletBalance,
                ["availableBalance"] = availableBalance,
                ["pendingWithdrawal"] = pendingWithdrawal,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            transaction.Set(transactionRef, new Dictionary<string, object>
            {
                ["status"] = settledStatus,
                ["settledBy"] = trimmedAdminUserId,
                ["settledAt"] = now,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            result = new WalletWithdrawSettlementWriteResult(
                trimmedTransactionId,
                userId,
                settledStatus,
                walletBalance,
                availableBalance,
                pendingWithdrawal);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not settle withdrawal request.");
    }

    private static string BuildRefundTransactionId(WalletRefundMetadata metadata)
    {
        if (!string.IsNullOrWhiteSpace(metadata.IdempotencyKey))
        {
            return $"refund_{SanitizeDocumentId(metadata.IdempotencyKey.Trim())}";
        }

        var sourceKey = string.IsNullOrWhiteSpace(metadata.SourceOrderId)
            ? Guid.NewGuid().ToString("N")
            : metadata.SourceOrderId.Trim();

        var providerKey = string.IsNullOrWhiteSpace(metadata.ProviderTransactionId)
            ? string.Empty
            : $"_{metadata.ProviderTransactionId.Trim()}";

        return $"refund_{SanitizeDocumentId(sourceKey + providerKey)}";
    }

    private static double NormalizeMoney(double value)
    {
        return Math.Round(value, 0, MidpointRounding.AwayFromZero);
    }

    private static string SanitizeDocumentId(string value)
    {
        var chars = value
            .Select(ch => char.IsLetterOrDigit(ch) || ch is '-' or '_' ? ch : '_')
            .ToArray();

        return new string(chars);
    }

    private static double GetDouble(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.ContainsField(field))
        {
            return 0;
        }

        try
        {
            return snapshot.GetValue<double>(field);
        }
        catch (InvalidCastException)
        {
            return snapshot.GetValue<long>(field);
        }
    }

    private static string GetString(DocumentSnapshot snapshot, string field)
    {
        return snapshot.ContainsField(field)
            ? snapshot.GetValue<string>(field)
            : string.Empty;
    }
}
