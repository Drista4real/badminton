using backend_caulong.Models;
using backend_caulong.Repositories;

namespace backend_caulong.Services;

public interface IBookingTransactionService
{
    Task<CreateBookingResult> CreateBookingAsync(
        string userId,
        BookingRequest request,
        CancellationToken cancellationToken = default);

    Task<CreateBookingResult> CreateFixedBookingAsync(
        string userId,
        FixedBookingRequest request,
        CancellationToken cancellationToken = default);

    Task<RenewFixedBookingResult> RenewFixedBookingAsync(
        string userId,
        RenewFixedBookingRequest request,
        CancellationToken cancellationToken = default);

    Task<CancelBookingResult> CancelBookingAsync(
        string userId,
        CancelBookingRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFixedAbsenceResult> ReportFixedAbsenceAsync(
        string userId,
        ReportFixedAbsenceRequest request,
        CancellationToken cancellationToken = default);

    Task<CancelOrderWithRefundResult> CancelOrderWithRefundAsync(
        string userId,
        CancelOrderWithRefundRequest request,
        CancellationToken cancellationToken = default);
}

public sealed class BookingTransactionService : IBookingTransactionService
{
    private static readonly string[] BlockingStatuses =
    [
        BookingStatuses.Pending,
        BookingStatuses.Confirmed,
        BookingStatuses.Completed,
    ];

    private readonly IBookingRepository _bookingRepository;

    public BookingTransactionService(IBookingRepository bookingRepository)
    {
        _bookingRepository = bookingRepository;
    }

    public async Task<CreateBookingResult> CreateBookingAsync(
        string userId,
        BookingRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        ValidateRequest(request);

        try
        {
            var result = await _bookingRepository.CreateBookingAsync(
                new CreateBookingWriteRequest(
                    userId.Trim(),
                    request.CourtId.Trim(),
                    DateOnly.FromDateTime(request.Date),
                    request.StartTime,
                    request.EndTime,
                    BlockingStatuses),
                cancellationToken);

            return new CreateBookingResult(result.OrderId, result.BookingIds, result.TotalPrice);
        }
        catch (BookingWriteConflictException ex)
        {
            throw new BookingConflictException(ex.Message, ex);
        }
    }

    public async Task<CreateBookingResult> CreateFixedBookingAsync(
        string userId,
        FixedBookingRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        ValidateFixedRequest(request);

        var courtId = request.CourtId.Trim();
        var bookingDates = BuildFixedBookingDates(
            request.StartDate,
            request.Months,
            request.DaysOfWeek).ToArray();

        if (bookingDates.Length == 0)
        {
            throw new ArgumentException("No booking dates were generated from startDate, months and daysOfWeek.", nameof(request));
        }

        try
        {
            var result = await _bookingRepository.CreateFixedBookingAsync(
                new CreateFixedBookingWriteRequest(
                    userId,
                    courtId,
                    bookingDates.Select(bookingDate => bookingDate.Date).ToArray(),
                    request.DaysOfWeek.Distinct().OrderBy(day => day).ToArray(),
                    request.Months,
                    request.StartDate,
                    request.StartDate.AddMonths(request.Months).AddDays(-1),
                    request.StartTime,
                    request.EndTime,
                    BlockingStatuses),
                cancellationToken);

            return new CreateBookingResult(result.OrderId, result.BookingIds, result.TotalPrice);
        }
        catch (BookingWriteConflictException ex)
        {
            throw new BookingConflictException(ex.Message, ex);
        }
    }

    public async Task<RenewFixedBookingResult> RenewFixedBookingAsync(
        string userId,
        RenewFixedBookingRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        if (string.IsNullOrWhiteSpace(request.OldOrderId))
        {
            throw new ArgumentException("oldOrderId is required.", nameof(request));
        }

        if (request.DurationMonths is not null and not (1 or 3 or 6))
        {
            throw new ArgumentException("durationMonths must be one of: 1, 3, 6.", nameof(request));
        }

        try
        {
            var result = await _bookingRepository.RenewFixedBookingAsync(
                new RenewFixedBookingWriteRequest(
                    userId.Trim(),
                    request.OldOrderId.Trim(),
                    request.DurationMonths,
                    BlockingStatuses),
                cancellationToken);

            return new RenewFixedBookingResult(
                result.NewOrderId,
                result.BookingIds,
                result.TotalPrice,
                result.FixedStartDate,
                result.FixedEndDate,
                result.DurationMonths);
        }
        catch (BookingWriteConflictException ex)
        {
            throw new BookingConflictException(ex.Message, ex);
        }
    }

    public async Task<CancelBookingResult> CancelBookingAsync(
        string userId,
        CancelBookingRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            throw new ArgumentException("orderId is required.", nameof(request));
        }

        var result = await _bookingRepository.CancelOrderAsync(
            new CancelBookingWriteRequest(
                userId.Trim(),
                request.OrderId.Trim()),
            cancellationToken);

        return new CancelBookingResult(result.OrderId, result.BookingIds);
    }

    public async Task<ReportFixedAbsenceResult> ReportFixedAbsenceAsync(
        string userId,
        ReportFixedAbsenceRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        if (string.IsNullOrWhiteSpace(request.BookingId))
        {
            throw new ArgumentException("bookingId is required.", nameof(request));
        }

        var result = await _bookingRepository.ReportFixedAbsenceAsync(
            new ReportFixedAbsenceWriteRequest(
                userId.Trim(),
                request.BookingId.Trim()),
            cancellationToken);

        return new ReportFixedAbsenceResult(
            result.BookingId,
            result.OrderId,
            result.RefundedAmount,
            result.AbsenceCountThisMonth,
            result.Refunded);
    }

    public async Task<CancelOrderWithRefundResult> CancelOrderWithRefundAsync(
        string userId,
        CancelOrderWithRefundRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("userId is required.", nameof(userId));
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            throw new ArgumentException("orderId is required.", nameof(request));
        }

        if (string.IsNullOrWhiteSpace(request.RefundMethod))
        {
            throw new ArgumentException("refundMethod is required.", nameof(request));
        }

        var result = await _bookingRepository.CancelOrderWithRefundAsync(
            new CancelOrderWithRefundWriteRequest(
                userId.Trim(),
                request.OrderId.Trim(),
                request.RefundMethod.Trim(),
                request.BankName,
                request.BankAccountNumber,
                request.BankAccountName),
            cancellationToken);

        return new CancelOrderWithRefundResult(
            result.OrderId,
            result.BookingIds,
            result.Status,
            result.RefundMethod,
            result.RefundAmount,
            result.RefundRate,
            result.RefundedToWallet);
    }

    private static void ValidateRequest(BookingRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CourtId))
        {
            throw new ArgumentException("courtId is required.", nameof(request));
        }

        if (request.StartTime < 0 || request.StartTime >= 24 * 60)
        {
            throw new ArgumentException("startTime must be between 0 and 1439 minutes.", nameof(request));
        }

        if (request.EndTime <= 0 || request.EndTime > 24 * 60)
        {
            throw new ArgumentException("endTime must be between 1 and 1440 minutes.", nameof(request));
        }

        if (request.StartTime >= request.EndTime)
        {
            throw new ArgumentException("startTime must be earlier than endTime.", nameof(request));
        }

        if (request.StartTime % 30 != 0 || request.EndTime % 30 != 0)
        {
            throw new ArgumentException("startTime and endTime must be aligned to 30-minute increments.", nameof(request));
        }

    }

    private static void ValidateFixedRequest(FixedBookingRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CourtId))
        {
            throw new ArgumentException("courtId is required.", nameof(request));
        }

        if (request.StartDate == default)
        {
            throw new ArgumentException("startDate is required.", nameof(request));
        }

        if (request.Months is not (1 or 3 or 6))
        {
            throw new ArgumentException("months must be one of: 1, 3, 6.", nameof(request));
        }

        if (request.DaysOfWeek is null || request.DaysOfWeek.Count == 0)
        {
            throw new ArgumentException("daysOfWeek is required.", nameof(request));
        }

        foreach (var dayOfWeek in request.DaysOfWeek.Distinct())
        {
            _ = ToDayOfWeek(dayOfWeek);
        }

        if (request.StartTime < 0 || request.StartTime >= 24 * 60)
        {
            throw new ArgumentException("startTime must be between 0 and 1439 minutes.", nameof(request));
        }

        if (request.EndTime <= 0 || request.EndTime > 24 * 60)
        {
            throw new ArgumentException("endTime must be between 1 and 1440 minutes.", nameof(request));
        }

        if (request.StartTime >= request.EndTime)
        {
            throw new ArgumentException("startTime must be earlier than endTime.", nameof(request));
        }

        if (request.StartTime % 30 != 0 || request.EndTime % 30 != 0)
        {
            throw new ArgumentException("startTime and endTime must be aligned to 30-minute increments.", nameof(request));
        }

    }

    private static IEnumerable<FixedBookingDate> BuildFixedBookingDates(
        DateOnly startDate,
        int months,
        IReadOnlyList<int> requestedDaysOfWeek)
    {
        var daysOfWeek = requestedDaysOfWeek
            .Select(ToDayOfWeek)
            .ToHashSet();
        var exclusiveEndDate = startDate.AddMonths(months);

        for (var date = startDate; date.DayNumber < exclusiveEndDate.DayNumber; date = date.AddDays(1))
        {
            if (!daysOfWeek.Contains(date.DayOfWeek))
            {
                continue;
            }

            yield return new FixedBookingDate(date);
        }
    }

    private static DayOfWeek ToDayOfWeek(int dayOfWeek)
    {
        return dayOfWeek switch
        {
            1 => DayOfWeek.Sunday,
            2 => DayOfWeek.Monday,
            3 => DayOfWeek.Tuesday,
            4 => DayOfWeek.Wednesday,
            5 => DayOfWeek.Thursday,
            6 => DayOfWeek.Friday,
            7 => DayOfWeek.Saturday,
            _ => throw new ArgumentException("daysOfWeek values must be from 1 to 7, where 2 is Monday and 7 is Saturday."),
        };
    }

    private sealed record FixedBookingDate(DateOnly Date);
}

public sealed record BookingRequest(
    string CourtId,
    DateTime Date,
    int StartTime,
    int EndTime);

public sealed record FixedBookingRequest(
    string CourtId,
    DateOnly StartDate,
    int Months,
    IReadOnlyList<int> DaysOfWeek,
    int StartTime,
    int EndTime);

public sealed record RenewFixedBookingRequest(
    string OldOrderId,
    int? DurationMonths);

public sealed record CancelBookingRequest(string OrderId);

public sealed record ReportFixedAbsenceRequest(string BookingId);

public sealed record CancelOrderWithRefundRequest(
    string OrderId,
    string RefundMethod,
    string? BankName,
    string? BankAccountNumber,
    string? BankAccountName);

public sealed record CreateBookingResult(
    string OrderId,
    IReadOnlyList<string> BookingIds,
    double TotalPrice);

public sealed record RenewFixedBookingResult(
    string NewOrderId,
    IReadOnlyList<string> BookingIds,
    double TotalPrice,
    DateOnly FixedStartDate,
    DateOnly FixedEndDate,
    int DurationMonths);

public sealed record CancelBookingResult(
    string OrderId,
    IReadOnlyList<string> BookingIds);

public sealed record ReportFixedAbsenceResult(
    string BookingId,
    string OrderId,
    double RefundedAmount,
    int AbsenceCountThisMonth,
    bool Refunded);

public sealed record CancelOrderWithRefundResult(
    string OrderId,
    IReadOnlyList<string> BookingIds,
    string Status,
    string RefundMethod,
    double RefundAmount,
    double RefundRate,
    bool RefundedToWallet);

public sealed class BookingConflictException : Exception
{
    public BookingConflictException(
        string message,
        Exception innerException)
        : base(message, innerException)
    {
    }

    public BookingConflictException(
        string courtId,
        DateTime date,
        int startTime,
        int endTime)
        : this(courtId, DateOnly.FromDateTime(date), startTime, endTime)
    {
    }

    public BookingConflictException(
        string courtId,
        DateOnly date,
        int startTime,
        int endTime)
        : base($"Court '{courtId}' is already booked on {date:yyyy-MM-dd} from {FormatMinutes(startTime)} to {FormatMinutes(endTime)}.")
    {
    }

    public BookingConflictException(
        string courtId,
        DateTime date,
        int startTime,
        int endTime,
        Exception innerException)
        : this(courtId, DateOnly.FromDateTime(date), startTime, endTime, innerException)
    {
    }

    public BookingConflictException(
        string courtId,
        DateOnly date,
        int startTime,
        int endTime,
        Exception innerException)
        : base($"Court '{courtId}' is already booked on {date:yyyy-MM-dd} from {FormatMinutes(startTime)} to {FormatMinutes(endTime)}.", innerException)
    {
    }

    private static string FormatMinutes(int minutes)
    {
        return $"{minutes / 60:00}:{minutes % 60:00}";
    }
}
