using backend_caulong.Models;

namespace backend_caulong.Repositories;

public interface IOrderRepository
{
    Task<OrderDocument> GetOrderAsync(
        string orderId,
        CancellationToken cancellationToken = default);

    Task<OrderDocument> GetOrderForUserAsync(
        string orderId,
        string userId,
        CancellationToken cancellationToken = default);

    Task<OrderDocument> GetOrderByPaymentContentAsync(
        string paymentContent,
        CancellationToken cancellationToken = default);

    Task SetPaymentContentIfMissingAsync(
        string orderId,
        string paymentContent,
        CancellationToken cancellationToken = default);

    Task EnsureOrderBelongsToUserAsync(
        string orderId,
        string userId,
        CancellationToken cancellationToken = default);

    Task<OrderRewardPointWriteResult> AddPointsOnCompletedOrderAsync(
        string orderId,
        double vndPerPoint,
        CancellationToken cancellationToken = default);

    Task<OrderPaymentWriteResult> ProcessPaidWebhookAsync(
        OrderPaymentWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<string>> GetExpiredPendingOrderIdsAsync(
        DateTime cutoffUtc,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task CancelPendingOrderIfExpiredAsync(
        string orderId,
        DateTime cutoffUtc,
        CancellationToken cancellationToken = default);
}

public sealed record OrderRewardPointWriteResult(
    string OrderId,
    int PointsAdded,
    bool Added);

public sealed record OrderPaymentWriteRequest(
    string OrderId,
    double Amount,
    string? Provider,
    string? TransactionId,
    IReadOnlyList<string>? BookingIds);

public sealed record OrderPaymentWriteResult(
    OrderPaymentWriteAction Action,
    string Message,
    string UserId,
    double RefundAmount);

public enum OrderPaymentWriteAction
{
    Confirmed,
    RefundToWallet,
    AlreadyProcessed,
}

public sealed class OrderNotFoundException : Exception
{
    public OrderNotFoundException(string orderId)
        : base($"Order '{orderId}' was not found.")
    {
    }
}

public sealed class OrderForbiddenException : Exception
{
    public OrderForbiddenException(string orderId)
        : base($"Current user is not allowed to access order '{orderId}'.")
    {
    }
}

public sealed class InsufficientPaymentException : Exception
{
    public InsufficientPaymentException(
        string orderId,
        double paidAmount,
        double requiredAmount)
        : base($"Payment for order '{orderId}' is insufficient. Paid {paidAmount}, required {requiredAmount}.")
    {
    }
}
