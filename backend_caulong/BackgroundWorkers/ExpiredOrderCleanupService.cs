using backend_caulong.Repositories;

namespace backend_caulong.BackgroundWorkers;

public sealed class ExpiredOrderCleanupService : BackgroundService
{
    private static readonly TimeSpan PaymentTimeout = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan ScanInterval = TimeSpan.FromMinutes(1);
    private const int PageSize = 100;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ExpiredOrderCleanupService> _logger;

    public ExpiredOrderCleanupService(
        IServiceScopeFactory scopeFactory,
        ILogger<ExpiredOrderCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await CleanupExpiredOrdersAsync(stoppingToken);

            using var timer = new PeriodicTimer(ScanInterval);
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await CleanupExpiredOrdersAsync(stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
        {
            _logger.LogError(ex, "Expired order cleanup service stopped unexpectedly.");
        }
    }

    private async Task CleanupExpiredOrdersAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var orderRepository = scope.ServiceProvider.GetRequiredService<IOrderRepository>();

            var cutoffUtc = DateTime.UtcNow.Subtract(PaymentTimeout);
            var expiredOrderIds = await orderRepository.GetExpiredPendingOrderIdsAsync(
                cutoffUtc,
                PageSize,
                cancellationToken);

            foreach (var orderId in expiredOrderIds)
            {
                await CancelOrderIfStillPendingAsync(
                    orderRepository,
                    orderId,
                    cutoffUtc,
                    cancellationToken);
            }
        }
        catch (Exception ex) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogError(ex, "Could not scan expired pending orders.");
        }
    }

    private async Task CancelOrderIfStillPendingAsync(
        IOrderRepository orderRepository,
        string orderId,
        DateTime cutoffUtc,
        CancellationToken cancellationToken)
    {
        try
        {
            await orderRepository.CancelPendingOrderIfExpiredAsync(
                orderId,
                cutoffUtc,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not cancel expired order {OrderId}.", orderId);
        }
    }
}
