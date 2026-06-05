using backend_caulong.Models;

namespace backend_caulong.Repositories;

public interface IWalletRepository
{
    Task<IReadOnlyList<WalletTransactionDocument>> GetUserTransactionsAsync(
        string userId,
        int limit = 50,
        CancellationToken cancellationToken = default);

    Task<WalletRefundWriteResult> RefundToWalletAsync(
        string userId,
        double amount,
        WalletRefundMetadata metadata,
        CancellationToken cancellationToken = default);

    Task<WalletWithdrawWriteResult> WithdrawAsync(
        WalletWithdrawWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<WalletWithdrawSettlementWriteResult> SettleWithdrawAsync(
        WalletWithdrawSettlementWriteRequest request,
        CancellationToken cancellationToken = default);
}

public sealed record WalletWithdrawWriteRequest(
    string UserId,
    double Amount,
    string BankName,
    string BankAccountNumber,
    string BankAccountName);

public sealed record WalletRefundWriteResult(
    string TransactionId,
    bool Applied,
    double WalletBalance,
    double AvailableBalance);

public sealed record WalletWithdrawWriteResult(
    string TransactionId,
    double NewBalance,
    double AvailableBalance,
    double PendingWithdrawal);

public sealed record WalletWithdrawSettlementWriteRequest(
    string AdminUserId,
    string TransactionId,
    WalletWithdrawSettlementStatus Status);

public sealed record WalletWithdrawSettlementWriteResult(
    string TransactionId,
    string UserId,
    string Status,
    double WalletBalance,
    double AvailableBalance,
    double PendingWithdrawal);

public enum WalletWithdrawSettlementStatus
{
    Success,
    Failed,
}

public sealed class InsufficientWalletBalanceException : Exception
{
    public InsufficientWalletBalanceException()
        : base("Wallet balance is not enough for this withdrawal.")
    {
    }
}

public sealed class WalletAdminForbiddenException : Exception
{
    public WalletAdminForbiddenException()
        : base("Current user is not allowed to settle withdrawal requests.")
    {
    }
}
