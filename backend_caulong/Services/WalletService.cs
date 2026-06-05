using backend_caulong.Models;
using backend_caulong.Repositories;

namespace backend_caulong.Services;

public interface IWalletService
{
    Task<IReadOnlyList<WalletTransactionResult>> GetTransactionsAsync(
        string userId,
        CancellationToken cancellationToken = default);

    Task<WalletRefundResult> RefundToWalletAsync(
        string userId,
        double amount,
        CancellationToken cancellationToken = default);

    Task<WalletRefundResult> RefundToWalletAsync(
        string userId,
        double amount,
        WalletRefundMetadata metadata,
        CancellationToken cancellationToken = default);

    Task<WalletWithdrawResult> WithdrawAsync(
        string userId,
        WalletWithdrawRequest request,
        CancellationToken cancellationToken = default);

    Task<WalletWithdrawSettlementResult> SettleWithdrawAsync(
        string adminUserId,
        WalletWithdrawSettlementRequest request,
        CancellationToken cancellationToken = default);
}

public sealed class WalletService : IWalletService
{
    private readonly IWalletRepository _walletRepository;

    public WalletService(IWalletRepository walletRepository)
    {
        _walletRepository = walletRepository;
    }

    public async Task<IReadOnlyList<WalletTransactionResult>> GetTransactionsAsync(
        string userId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        var transactions = await _walletRepository.GetUserTransactionsAsync(
            userId.Trim(),
            cancellationToken: cancellationToken);

        return transactions.Select(transaction => new WalletTransactionResult(
            transaction.Id,
            transaction.UserId,
            transaction.Amount,
            transaction.Type,
            transaction.Status,
            transaction.Description,
            transaction.SourceOrderId,
            transaction.ProviderTransactionId,
            transaction.CreatedAt.ToDateTime())).ToArray();
    }

    public Task<WalletRefundResult> RefundToWalletAsync(
        string userId,
        double amount,
        CancellationToken cancellationToken = default)
    {
        return RefundToWalletAsync(
            userId,
            amount,
            new WalletRefundMetadata(),
            cancellationToken);
    }

    public async Task<WalletRefundResult> RefundToWalletAsync(
        string userId,
        double amount,
        WalletRefundMetadata metadata,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Refund amount must be greater than zero.");
        }

        var normalizedAmount = Math.Round(amount, 0, MidpointRounding.AwayFromZero);
        var result = await _walletRepository.RefundToWalletAsync(
            userId.Trim(),
            normalizedAmount,
            metadata,
            cancellationToken);

        return new WalletRefundResult(
            result.TransactionId,
            result.Applied,
            result.WalletBalance,
            result.AvailableBalance);
    }

    public async Task<WalletWithdrawResult> WithdrawAsync(
        string userId,
        WalletWithdrawRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        if (request.Amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(request), "amount must be greater than zero.");
        }

        if (string.IsNullOrWhiteSpace(request.BankName))
        {
            throw new ArgumentException("bankName is required.", nameof(request));
        }

        if (string.IsNullOrWhiteSpace(request.BankAccountNumber))
        {
            throw new ArgumentException("bankAccountNumber is required.", nameof(request));
        }

        if (string.IsNullOrWhiteSpace(request.BankAccountName))
        {
            throw new ArgumentException("bankAccountName is required.", nameof(request));
        }

        var result = await _walletRepository.WithdrawAsync(
            new WalletWithdrawWriteRequest(
                userId.Trim(),
                request.Amount,
                request.BankName.Trim(),
                request.BankAccountNumber.Trim(),
                request.BankAccountName.Trim()),
            cancellationToken);

        return new WalletWithdrawResult(
            result.TransactionId,
            result.NewBalance,
            result.AvailableBalance,
            result.PendingWithdrawal);
    }

    public async Task<WalletWithdrawSettlementResult> SettleWithdrawAsync(
        string adminUserId,
        WalletWithdrawSettlementRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(adminUserId))
        {
            throw new ArgumentException("adminUserId is required.", nameof(adminUserId));
        }

        if (string.IsNullOrWhiteSpace(request.TransactionId))
        {
            throw new ArgumentException("transactionId is required.", nameof(request));
        }

        if (!TryParseSettlementStatus(request.Status, out var status))
        {
            throw new ArgumentException("status must be Success or Failed.", nameof(request));
        }

        var result = await _walletRepository.SettleWithdrawAsync(
            new WalletWithdrawSettlementWriteRequest(
                adminUserId.Trim(),
                request.TransactionId.Trim(),
                status),
            cancellationToken);

        return new WalletWithdrawSettlementResult(
            result.TransactionId,
            result.UserId,
            result.Status,
            result.WalletBalance,
            result.AvailableBalance,
            result.PendingWithdrawal);
    }

    private static bool TryParseSettlementStatus(
        string? value,
        out WalletWithdrawSettlementStatus status)
    {
        if (string.Equals(value, "success", StringComparison.OrdinalIgnoreCase))
        {
            status = WalletWithdrawSettlementStatus.Success;
            return true;
        }

        if (string.Equals(value, "failed", StringComparison.OrdinalIgnoreCase))
        {
            status = WalletWithdrawSettlementStatus.Failed;
            return true;
        }

        status = default;
        return false;
    }
}

public sealed record WalletWithdrawRequest(
    double Amount,
    string BankName,
    string BankAccountNumber,
    string BankAccountName);

public sealed record WalletRefundResult(
    string TransactionId,
    bool Applied,
    double WalletBalance,
    double AvailableBalance);

public sealed record WalletTransactionResult(
    string Id,
    string UserId,
    double Amount,
    string Type,
    string Status,
    string Description,
    string? SourceOrderId,
    string? ProviderTransactionId,
    DateTime CreatedAt);

public sealed record WalletWithdrawResult(
    string TransactionId,
    double NewBalance,
    double AvailableBalance,
    double PendingWithdrawal);

public sealed record WalletWithdrawSettlementRequest(
    string TransactionId,
    string Status);

public sealed record WalletWithdrawSettlementResult(
    string TransactionId,
    string UserId,
    string Status,
    double WalletBalance,
    double AvailableBalance,
    double PendingWithdrawal);
