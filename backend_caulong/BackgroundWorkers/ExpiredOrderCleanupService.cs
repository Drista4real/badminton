using backend_caulong.Repositories;
using backend_caulong.Services;
using Grpc.Core;

namespace backend_caulong.BackgroundWorkers;

public sealed class ExpiredOrderCleanupService : BackgroundService
{
    private static readonly TimeSpan PaymentTimeout = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan DefaultScanInterval = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan DefaultQuotaBackoff = TimeSpan.FromHours(1);
    private const int DefaultPageSize = 25;

    private readonly IConfiguration _configuration;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ExpiredOrderCleanupService> _logger;

    public ExpiredOrderCleanupService(
        IConfiguration configuration,
        IServiceScopeFactory scopeFactory,
        ILogger<ExpiredOrderCleanupService> logger)
    {
        _configuration = configuration;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_configuration.GetValue("ExpiredOrderCleanup:Enabled", true))
        {
            _logger.LogInformation("Expired order cleanup service is disabled.");
            return;
        }

        var scanInterval = GetConfiguredTimeSpan(
            "ExpiredOrderCleanup:ScanIntervalMinutes",
            DefaultScanInterval);
        var quotaBackoff = GetConfiguredTimeSpan(
            "ExpiredOrderCleanup:QuotaBackoffMinutes",
            DefaultQuotaBackoff);

        try
        {
            var shouldBackoff = await CleanupExpiredOrdersAsync(stoppingToken);
            if (shouldBackoff)
            {
                await Task.Delay(quotaBackoff, stoppingToken);
            }

            using var timer = new PeriodicTimer(scanInterval);
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                shouldBackoff = await CleanupExpiredOrdersAsync(stoppingToken);
                if (shouldBackoff)
                {
                    await Task.Delay(quotaBackoff, stoppingToken);
                }
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

    private async Task<bool> CleanupExpiredOrdersAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var orderRepository = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
            var bookingNotificationService =
                scope.ServiceProvider.GetRequiredService<IBookingNotificationService>();

            var cutoffUtc = DateTime.UtcNow.Subtract(PaymentTimeout);
            var expiredOrderIds = await orderRepository.GetExpiredPendingOrderIdsAsync(
                cutoffUtc,
                GetConfiguredPageSize(),
                cancellationToken);

            foreach (var orderId in expiredOrderIds)
            {
                await CancelOrderIfStillPendingAsync(
                    orderRepository,
                    bookingNotificationService,
                    orderId,
                    cutoffUtc,
                    cancellationToken);
            }

            return false;
        }
        catch (RpcException ex) when (
            ex.StatusCode == StatusCode.ResourceExhausted
            && !cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning(
                ex,
                "Firestore quota is exhausted. Expired order cleanup will pause before scanning again.");
            return true;
        }
        catch (Exception ex) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogError(ex, "Could not scan expired pending orders.");
            return false;
        }
    }

    private async Task CancelOrderIfStillPendingAsync(
        IOrderRepository orderRepository,
        IBookingNotificationService bookingNotificationService,
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
            await bookingNotificationService.NotifyOrderCancelledAsync(
                orderId,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not cancel expired order {OrderId}.", orderId);
        }
    }

    private TimeSpan GetConfiguredTimeSpan(string key, TimeSpan fallback)
    {
        var minutes = _configuration.GetValue<double?>(key);
        return minutes is > 0
            ? TimeSpan.FromMinutes(minutes.Value)
            : fallback;
    }

    private int GetConfiguredPageSize()
    {
        var pageSize = _configuration.GetValue<int?>("ExpiredOrderCleanup:PageSize");
        return pageSize is > 0
            ? pageSize.Value
            : DefaultPageSize;
    }
}
