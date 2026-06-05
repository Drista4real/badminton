using backend_caulong.Repositories;

namespace backend_caulong.BackgroundWorkers;

public sealed class FixedBookingCompletionService : BackgroundService
{
    private static readonly TimeSpan RunInterval = TimeSpan.FromMinutes(10);
    private const int PageSize = 100;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<FixedBookingCompletionService> _logger;

    public FixedBookingCompletionService(
        IServiceScopeFactory scopeFactory,
        ILogger<FixedBookingCompletionService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(RunInterval);

        await CompleteDueBookingsAsync(stoppingToken);
        while (!stoppingToken.IsCancellationRequested
            && await timer.WaitForNextTickAsync(stoppingToken))
        {
            await CompleteDueBookingsAsync(stoppingToken);
        }
    }

    private async Task CompleteDueBookingsAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var bookingRepository = scope.ServiceProvider.GetRequiredService<IBookingRepository>();
            var completed = await bookingRepository.CompleteDueFixedBookingsAsync(
                DateTime.UtcNow,
                PageSize,
                cancellationToken);

            if (completed > 0)
            {
                _logger.LogInformation("Completed {Count} due fixed booking sessions.", completed);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not complete due fixed booking sessions.");
        }
    }
}
