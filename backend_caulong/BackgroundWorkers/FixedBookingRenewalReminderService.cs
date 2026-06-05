using System.Globalization;
using backend_caulong.Models;
using Google.Cloud.Firestore;

namespace backend_caulong.BackgroundWorkers;

public sealed class FixedBookingRenewalReminderService : BackgroundService
{
    private static readonly CultureInfo VietnameseCulture = CultureInfo.GetCultureInfo("vi-VN");
    private static readonly TimeSpan RunInterval = TimeSpan.FromHours(6);
    private static readonly TimeSpan RenewalWindow = TimeSpan.FromDays(7);
    private static readonly TimeZoneInfo BusinessTimeZone = ResolveBusinessTimeZone();
    private const int PageSize = 200;

    private readonly FirestoreDb _firestoreDb;
    private readonly ILogger<FixedBookingRenewalReminderService> _logger;

    public FixedBookingRenewalReminderService(
        FirestoreDb firestoreDb,
        ILogger<FixedBookingRenewalReminderService> logger)
    {
        _firestoreDb = firestoreDb;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(RunInterval);

        await WriteRenewalRemindersAsync(stoppingToken);
        while (!stoppingToken.IsCancellationRequested
            && await timer.WaitForNextTickAsync(stoppingToken))
        {
            await WriteRenewalRemindersAsync(stoppingToken);
        }
    }

    private async Task WriteRenewalRemindersAsync(CancellationToken cancellationToken)
    {
        try
        {
            var nowUtc = DateTime.UtcNow;
            var today = ToBusinessDate(nowUtc);
            var threshold = ToBusinessDate(nowUtc.Add(RenewalWindow));
            var thresholdTimestamp = ToUtcDateTimestamp(threshold);
            var snapshot = await _firestoreDb
                .Collection("bookings")
                .WhereEqualTo("bookingType", BookingTypes.Fixed)
                .WhereEqualTo("status", BookingStatuses.Confirmed)
                .WhereLessThanOrEqualTo("fixedEndDate", thresholdTimestamp)
                .Limit(PageSize)
                .GetSnapshotAsync(cancellationToken);

            var candidates = snapshot.Documents
                .Select(TryConvertToBookingDocument)
                .OfType<BookingDocument>()
                .Where(booking => !string.IsNullOrWhiteSpace(booking.OrderId))
                .Where(booking => ToDateOnly(booking.FixedEndDate) is { } endDate
                    && endDate.DayNumber >= today.DayNumber
                    && endDate.DayNumber <= threshold.DayNumber)
                .GroupBy(booking => booking.OrderId.Trim(), StringComparer.Ordinal)
                .Select(group => group.OrderBy(booking => ToDateOnly(booking.Date)).First())
                .ToArray();

            foreach (var booking in candidates)
            {
                await WriteRenewalReminderAsync(booking, cancellationToken);
            }

            if (candidates.Length > 0)
            {
                _logger.LogInformation(
                    "Checked {Count} fixed booking contracts for renewal reminders.",
                    candidates.Length);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not write fixed booking renewal reminders.");
        }
    }

    private async Task WriteRenewalReminderAsync(
        BookingDocument booking,
        CancellationToken cancellationToken)
    {
        var orderId = booking.OrderId.Trim();
        var notificationRef = _firestoreDb
            .Collection("notifications")
            .Document($"fixed_booking_renewal_{SanitizeDocumentId(orderId)}");
        var notificationSnapshot = await notificationRef.GetSnapshotAsync(cancellationToken);
        if (notificationSnapshot.Exists)
        {
            return;
        }

        var userId = booking.UserId.Trim();
        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        var fixedEndDate = ToDateOnly(booking.FixedEndDate);
        if (fixedEndDate is null)
        {
            return;
        }

        var courtLabel = await GetCourtLabelAsync(booking.CourtId, cancellationToken);
        var now = Timestamp.FromDateTime(DateTime.UtcNow);
        await notificationRef.SetAsync(new Dictionary<string, object?>
        {
            ["userId"] = userId,
            ["type"] = "booking",
            ["title"] = "Nhắc gia hạn lịch cố định",
            ["message"] =
                $"Lịch cố định {courtLabel} sẽ kết thúc vào {FormatDate(fixedEndDate.Value)}. " +
                "Hãy gia hạn trong Lịch sử đặt sân để giữ nguyên khung giờ.",
            ["isRead"] = false,
            ["orderId"] = orderId,
            ["bookingId"] = booking.Id,
            ["courtId"] = booking.CourtId,
            ["fixedEndDate"] = booking.FixedEndDate,
            ["createdAt"] = now,
            ["updatedAt"] = now,
        }, cancellationToken: cancellationToken);
    }

    private async Task<string> GetCourtLabelAsync(
        string courtId,
        CancellationToken cancellationToken)
    {
        var normalizedCourtId = courtId.Trim();
        if (string.IsNullOrWhiteSpace(normalizedCourtId))
        {
            return "sân đã chọn";
        }

        var snapshot = await _firestoreDb
            .Collection("courts")
            .Document(normalizedCourtId)
            .GetSnapshotAsync(cancellationToken);
        if (!snapshot.Exists)
        {
            return $"sân {normalizedCourtId}";
        }

        var name = GetString(snapshot, "name");
        if (!string.IsNullOrWhiteSpace(name))
        {
            return name;
        }

        var code = GetString(snapshot, "code");
        return string.IsNullOrWhiteSpace(code)
            ? $"sân {normalizedCourtId}"
            : $"sân {code}";
    }

    private static BookingDocument? TryConvertToBookingDocument(DocumentSnapshot document)
    {
        if (!document.Exists)
        {
            return null;
        }

        try
        {
            return document.ConvertTo<BookingDocument>();
        }
        catch
        {
            return null;
        }
    }

    private static DateOnly ToBusinessDate(DateTime utcDateTime)
    {
        var normalizedUtc = utcDateTime.Kind == DateTimeKind.Utc
            ? utcDateTime
            : DateTime.SpecifyKind(utcDateTime, DateTimeKind.Utc);
        var localDateTime = TimeZoneInfo.ConvertTimeFromUtc(normalizedUtc, BusinessTimeZone);
        return DateOnly.FromDateTime(localDateTime);
    }

    private static DateOnly? ToDateOnly(Timestamp? timestamp)
    {
        return timestamp is null
            ? null
            : DateOnly.FromDateTime(timestamp.Value.ToDateTime());
    }

    private static Timestamp ToUtcDateTimestamp(DateOnly date)
    {
        var normalized = new DateTime(date.Year, date.Month, date.Day, 0, 0, 0, DateTimeKind.Utc);
        return Timestamp.FromDateTime(normalized);
    }

    private static string FormatDate(DateOnly date)
    {
        return date.ToString("dd/MM/yyyy", VietnameseCulture);
    }

    private static string GetString(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return string.Empty;
        }

        var value = snapshot.GetValue<object>(field);
        return value?.ToString()?.Trim() ?? string.Empty;
    }

    private static TimeZoneInfo ResolveBusinessTimeZone()
    {
        foreach (var timeZoneId in new[] { "SE Asia Standard Time", "Asia/Ho_Chi_Minh" })
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        return TimeZoneInfo.Utc;
    }

    private static string SanitizeDocumentId(string value)
    {
        var chars = value
            .Trim()
            .Select(ch => char.IsLetterOrDigit(ch) || ch is '-' or '_' ? ch : '_')
            .ToArray();

        return new string(chars);
    }
}
