using backend_caulong.Models;

namespace backend_caulong.Repositories;

public interface IBookingRepository
{
    Task<IReadOnlyList<BookingDocument>> GetActiveBookingsAsync(
        CancellationToken cancellationToken = default);

    Task<BookingWriteResult> CreateBookingAsync(
        CreateBookingWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<BookingWriteResult> CreateFixedBookingAsync(
        CreateFixedBookingWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<RenewFixedBookingWriteResult> RenewFixedBookingAsync(
        RenewFixedBookingWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<CancelBookingWriteResult> CancelOrderAsync(
        CancelBookingWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFixedAbsenceWriteResult> ReportFixedAbsenceAsync(
        ReportFixedAbsenceWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<CancelOrderWithRefundWriteResult> CancelOrderWithRefundAsync(
        CancelOrderWithRefundWriteRequest request,
        CancellationToken cancellationToken = default);

    Task<int> CompleteDueFixedBookingsAsync(
        DateTime nowUtc,
        int pageSize,
        CancellationToken cancellationToken = default);
}

public sealed record CreateBookingWriteRequest(
    string UserId,
    string CourtId,
    DateOnly Date,
    int StartTime,
    int EndTime,
    IReadOnlyCollection<string> BlockingStatuses);

public sealed record CreateFixedBookingWriteRequest(
    string UserId,
    string CourtId,
    IReadOnlyList<DateOnly> BookingDates,
    IReadOnlyList<int> FixedWeekdays,
    int FixedDurationMonths,
    DateOnly FixedStartDate,
    DateOnly FixedEndDate,
    int StartTime,
    int EndTime,
    IReadOnlyCollection<string> BlockingStatuses);

public sealed record BookingWriteResult(
    string OrderId,
    IReadOnlyList<string> BookingIds,
    double TotalPrice);

public sealed record RenewFixedBookingWriteRequest(
    string UserId,
    string OldOrderId,
    int? DurationMonths,
    IReadOnlyCollection<string> BlockingStatuses);

public sealed record RenewFixedBookingWriteResult(
    string NewOrderId,
    IReadOnlyList<string> BookingIds,
    double TotalPrice,
    DateOnly FixedStartDate,
    DateOnly FixedEndDate,
    int DurationMonths);

public sealed record CancelBookingWriteRequest(
    string UserId,
    string OrderId);

public sealed record CancelBookingWriteResult(
    string OrderId,
    IReadOnlyList<string> BookingIds);

public sealed record ReportFixedAbsenceWriteRequest(
    string UserId,
    string BookingId);

public sealed record ReportFixedAbsenceWriteResult(
    string BookingId,
    string OrderId,
    double RefundedAmount,
    int AbsenceCountThisMonth,
    bool Refunded);

public sealed record CancelOrderWithRefundWriteRequest(
    string UserId,
    string OrderId,
    string RefundMethod,
    string? BankName,
    string? BankAccountNumber,
    string? BankAccountName);

public sealed record CancelOrderWithRefundWriteResult(
    string OrderId,
    IReadOnlyList<string> BookingIds,
    string Status,
    string RefundMethod,
    double RefundAmount,
    double RefundRate,
    bool RefundedToWallet);

public sealed class BookingSuspendedWriteException : Exception
{
    public BookingSuspendedWriteException(
        string userId,
        DateTime disabledUntilUtc)
        : base($"User '{userId}' cannot create bookings until {disabledUntilUtc:O}.")
    {
        UserId = userId;
        DisabledUntilUtc = disabledUntilUtc;
    }

    public string UserId { get; }

    public DateTime DisabledUntilUtc { get; }
}

public sealed class ProtectedCourtWriteException : Exception
{
    public ProtectedCourtWriteException(string courtId)
        : base($"Court '{courtId}' is protected and requires at least one paid order.")
    {
        CourtId = courtId;
    }

    public string CourtId { get; }
}

public sealed class CancelBookingWriteNotAllowedException : Exception
{
    public CancelBookingWriteNotAllowedException(string orderId, string status)
        : base($"Order '{orderId}' cannot be cancelled because its current status is '{status}'.")
    {
        OrderId = orderId;
        Status = status;
    }

    public string OrderId { get; }

    public string Status { get; }
}

public sealed class FixedAbsenceWriteNotAllowedException : Exception
{
    public FixedAbsenceWriteNotAllowedException(string message)
        : base(message)
    {
    }
}

public sealed class MonthlyFixedAbsenceLimitExceededException : Exception
{
    public MonthlyFixedAbsenceLimitExceededException()
        : base("Khách cố định chỉ được báo nghỉ tối đa 02 buổi trong một tháng.")
    {
    }
}

public sealed class BookingWriteConflictException : Exception
{
    public BookingWriteConflictException(
        string courtId,
        DateOnly date,
        int startTime,
        int endTime)
        : base($"Court '{courtId}' is already booked on {date:yyyy-MM-dd} from {FormatMinutes(startTime)} to {FormatMinutes(endTime)}.")
    {
    }

    private static string FormatMinutes(int minutes)
    {
        return $"{minutes / 60:00}:{minutes % 60:00}";
    }
}
