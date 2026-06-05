using backend_caulong.Repositories;
using backend_caulong.Services;

namespace backend_caulong.BackgroundWorkers;

public sealed class CompletedOrderRewardPointService : BackgroundService
{
    private static readonly TimeSpan RunInterval = TimeSpan.FromMinutes(5);
    private const int PageSize = 100;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<CompletedOrderRewardPointService> _logger;

    public CompletedOrderRewardPointService(
        IServiceScopeFactory scopeFactory,
        ILogger<CompletedOrderRewardPointService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(RunInterval);

        await GrantPendingRewardPointsAsync(stoppingToken);
        while (!stoppingToken.IsCancellationRequested
            && await timer.WaitForNextTickAsync(stoppingToken))
        {
            await GrantPendingRewardPointsAsync(stoppingToken);
        }
    }

    private async Task GrantPendingRewardPointsAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var orderRepository = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
            var rewardPointService = scope.ServiceProvider.GetRequiredService<IRewardPointService>();

            var orderIds = await orderRepository.GetCompletedOrderIdsPendingRewardPointsAsync(
                PageSize,
                cancellationToken);
            var addedCount = 0;
            var pointsAdded = 0;

            foreach (var orderId in orderIds)
            {
                var result = await rewardPointService.AddPointsOnOrderCompletedAsync(
                    orderId,
                    cancellationToken);
                if (!result.Added)
                {
                    continue;
                }

                addedCount++;
                pointsAdded += result.PointsAdded;
            }

            if (addedCount > 0)
            {
                _logger.LogInformation(
                    "Granted {Points} reward points for {Count} completed orders.",
                    pointsAdded,
                    addedCount);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not grant reward points for completed orders.");
        }
    }
}
