using backend_caulong.Repositories;

namespace backend_caulong.Services;

public interface IRewardPointService
{
    Task<RewardPointResult> AddPointsOnOrderCompletedAsync(
        string orderId,
        CancellationToken cancellationToken = default);
}

public sealed class RewardPointService : IRewardPointService
{
    private const double VndPerPoint = 10000d;

    private readonly IOrderRepository _orderRepository;

    public RewardPointService(IOrderRepository orderRepository)
    {
        _orderRepository = orderRepository;
    }

    public async Task<RewardPointResult> AddPointsOnOrderCompletedAsync(
        string orderId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("orderId is required.", nameof(orderId));
        }

        var result = await _orderRepository.AddPointsOnCompletedOrderAsync(
            orderId.Trim(),
            VndPerPoint,
            cancellationToken);

        return new RewardPointResult(
            result.OrderId,
            result.PointsAdded,
            result.Added);
    }
}

public sealed record RewardPointResult(
    string OrderId,
    int PointsAdded,
    bool Added);
