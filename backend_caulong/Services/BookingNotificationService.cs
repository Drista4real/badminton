using System.Globalization;
using backend_caulong.Models;
using Google.Cloud.Firestore;

namespace backend_caulong.Services;

public interface IBookingNotificationService
{
    Task NotifyFixedBookingConfirmedAsync(
        string orderId,
        CancellationToken cancellationToken = default);

    Task DeletePendingFixedBookingNotificationAsync(
        string orderId,
        CancellationToken cancellationToken = default);
}

public sealed class BookingNotificationService : IBookingNotificationService
{
    private static readonly CultureInfo VietnameseCulture = CultureInfo.GetCultureInfo("vi-VN");

    private readonly FirestoreDb _firestoreDb;

    public BookingNotificationService(FirestoreDb firestoreDb)
    {
        _firestoreDb = firestoreDb;
    }

    public async Task NotifyFixedBookingConfirmedAsync(
        string orderId,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        if (string.IsNullOrWhiteSpace(trimmedOrderId))
        {
            return;
        }

        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);
        var orderSnapshot = await orderRef.GetSnapshotAsync(cancellationToken);
        if (!orderSnapshot.Exists || !IsPaidOrder(orderSnapshot))
        {
            return;
        }

        var userId = GetString(orderSnapshot, "userId");
        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        var fixedBookings = await GetFixedBookingsAsync(
            orderSnapshot,
            trimmedOrderId,
            cancellationToken);
        if (fixedBookings.Count == 0)
        {
            return;
        }

        var template = fixedBookings[0];
        var fixedStartDate = ToDateOnly(template.FixedStartDate) ?? ToDateOnly(template.Date);
        var fixedEndDate = ToDateOnly(template.FixedEndDate) ?? fixedBookings
            .Select(booking => ToDateOnly(booking.Date))
            .OfType<DateOnly>()
            .OrderBy(date => date)
            .LastOrDefault();
        if (fixedStartDate is null || fixedStartDate == default || fixedEndDate == default)
        {
            return;
        }

        var normalizedFixedStartDate = fixedStartDate.Value;
        var normalizedFixedEndDate = fixedEndDate;
        var notificationRef = _firestoreDb
            .Collection("notifications")
            .Document($"fixed_booking_confirmed_{SanitizeDocumentId(trimmedOrderId)}");
        var notificationSnapshot = await notificationRef.GetSnapshotAsync(cancellationToken);
        if (notificationSnapshot.Exists)
        {
            await DeletePendingFixedBookingNotificationAsync(trimmedOrderId, cancellationToken);
            return;
        }

        var courtLabel = await GetCourtLabelAsync(template.CourtId, cancellationToken);
        var totalPrice = ResolveOrderTotal(orderSnapshot);
        var weekdays = template.FixedWeekdays.Count > 0
            ? template.FixedWeekdays
            : fixedBookings
                .Select(booking => ToApiDayOfWeek(ToDateOnly(booking.Date)?.DayOfWeek))
                .Where(day => day is not null)
                .Select(day => day!.Value)
                .Distinct()
                .OrderBy(day => day)
                .ToArray();

        var now = Timestamp.FromDateTime(DateTime.UtcNow);
        await notificationRef.SetAsync(new Dictionary<string, object?>
        {
            ["userId"] = userId,
            ["type"] = "booking",
            ["title"] = "Lịch cố định đã xác nhận",
            ["message"] = BuildFixedBookingConfirmedMessage(
                courtLabel,
                normalizedFixedStartDate,
                normalizedFixedEndDate,
                weekdays,
                template.StartTime,
                template.EndTime,
                fixedBookings.Count,
                totalPrice),
            ["isRead"] = false,
            ["orderId"] = trimmedOrderId,
            ["bookingId"] = fixedBookings[0].Id,
            ["courtId"] = template.CourtId,
            ["fixedStartDate"] = ToUtcDateTimestamp(normalizedFixedStartDate),
            ["fixedEndDate"] = ToUtcDateTimestamp(normalizedFixedEndDate),
            ["fixedWeekdays"] = weekdays,
            ["startTime"] = template.StartTime,
            ["endTime"] = template.EndTime,
            ["bookingCount"] = fixedBookings.Count,
            ["totalPrice"] = totalPrice,
            ["createdAt"] = now,
            ["updatedAt"] = now,
        }, cancellationToken: cancellationToken);

        await DeletePendingFixedBookingNotificationAsync(trimmedOrderId, cancellationToken);
    }

    private async Task<IReadOnlyList<BookingDocument>> GetFixedBookingsAsync(
        DocumentSnapshot orderSnapshot,
        string orderId,
        CancellationToken cancellationToken)
    {
        var bookings = new List<BookingDocument>();
        foreach (var bookingId in GetBookingIds(orderSnapshot))
        {
            var bookingSnapshot = await _firestoreDb
                .Collection("bookings")
                .Document(bookingId)
                .GetSnapshotAsync(cancellationToken);
            var booking = TryConvertToBookingDocument(bookingSnapshot);
            if (booking is not null && IsFixedBooking(booking))
            {
                bookings.Add(booking);
            }
        }

        if (bookings.Count > 0)
        {
            return bookings
                .OrderBy(booking => ToDateOnly(booking.Date))
                .ThenBy(booking => booking.StartTime)
                .ToArray();
        }

        var bookingsSnapshot = await _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("orderId", orderId)
            .GetSnapshotAsync(cancellationToken);

        return bookingsSnapshot.Documents
            .Select(TryConvertToBookingDocument)
            .OfType<BookingDocument>()
            .Where(IsFixedBooking)
            .OrderBy(booking => ToDateOnly(booking.Date))
            .ThenBy(booking => booking.StartTime)
            .ToArray();
    }

    private static IReadOnlyList<string> GetBookingIds(DocumentSnapshot orderSnapshot)
    {
        if (!orderSnapshot.Exists || !orderSnapshot.ContainsField("bookingIds"))
        {
            return Array.Empty<string>();
        }

        return orderSnapshot.GetValue<IReadOnlyList<string>>("bookingIds")
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
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

    private static bool IsPaidOrder(DocumentSnapshot orderSnapshot)
    {
        var status = GetString(orderSnapshot, "status");
        return string.Equals(status, OrderStatuses.Confirmed, StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, OrderStatuses.Completed, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsFixedBooking(BookingDocument booking)
    {
        return string.Equals(booking.BookingType, BookingTypes.Fixed, StringComparison.OrdinalIgnoreCase)
            || booking.FixedWeekdays.Count > 0
            || booking.FixedDurationMonths is not null;
    }

    public async Task DeletePendingFixedBookingNotificationAsync(
        string orderId,
        CancellationToken cancellationToken)
    {
        var createdNotificationRef = _firestoreDb
            .Collection("notifications")
            .Document($"fixed_booking_created_{SanitizeDocumentId(orderId)}");
        await createdNotificationRef.DeleteAsync(cancellationToken: cancellationToken);
    }

    private static string BuildFixedBookingConfirmedMessage(
        string courtLabel,
        DateOnly fixedStartDate,
        DateOnly fixedEndDate,
        IEnumerable<int> daysOfWeek,
        int startTime,
        int endTime,
        int bookingCount,
        double totalPrice)
    {
        var startDate = FormatDate(fixedStartDate);
        var endDate = FormatDate(fixedEndDate);
        var weekdays = FormatWeekdays(daysOfWeek);
        var time = $"{FormatMinutes(startTime)} - {FormatMinutes(endTime)}";
        var amount = totalPrice.ToString("N0", VietnameseCulture);

        return
            $"Bạn đã thanh toán thành công lịch cố định {courtLabel} từ {startDate} đến {endDate}, " +
            $"vào {weekdays}, giờ chơi {time}. Tổng {bookingCount} buổi, số tiền {amount} đ.";
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

    private static double ResolveOrderTotal(DocumentSnapshot orderSnapshot)
    {
        var originalTotal = NormalizeMoney(GetDouble(orderSnapshot, "originalTotalPrice"));
        var totalPrice = NormalizeMoney(GetDouble(orderSnapshot, "totalPrice"));
        var paidAmount = NormalizeMoney(GetDouble(orderSnapshot, "paidAmount"));
        return Math.Max(originalTotal, Math.Max(totalPrice, paidAmount));
    }

    private static string FormatDate(DateOnly date)
    {
        return date.ToString("dd/MM/yyyy", VietnameseCulture);
    }

    private static string FormatWeekdays(IEnumerable<int> daysOfWeek)
    {
        var labels = daysOfWeek
            .Distinct()
            .OrderBy(day => day == 1 ? 8 : day)
            .Select(day => day switch
            {
                1 => "CN",
                2 => "T2",
                3 => "T3",
                4 => "T4",
                5 => "T5",
                6 => "T6",
                7 => "T7",
                _ => string.Empty,
            })
            .Where(label => !string.IsNullOrWhiteSpace(label))
            .ToArray();

        return labels.Length == 0 ? "các ngày đã chọn" : string.Join(", ", labels);
    }

    private static string FormatMinutes(int minutes)
    {
        return $"{minutes / 60:00}:{minutes % 60:00}";
    }

    private static DateOnly? ToDateOnly(Timestamp? timestamp)
    {
        return timestamp is null
            ? null
            : DateOnly.FromDateTime(timestamp.Value.ToDateTime());
    }

    private static int? ToApiDayOfWeek(DayOfWeek? dayOfWeek)
    {
        return dayOfWeek switch
        {
            DayOfWeek.Sunday => 1,
            DayOfWeek.Monday => 2,
            DayOfWeek.Tuesday => 3,
            DayOfWeek.Wednesday => 4,
            DayOfWeek.Thursday => 5,
            DayOfWeek.Friday => 6,
            DayOfWeek.Saturday => 7,
            _ => null,
        };
    }

    private static Timestamp ToUtcDateTimestamp(DateOnly date)
    {
        var normalized = new DateTime(date.Year, date.Month, date.Day, 0, 0, 0, DateTimeKind.Utc);
        return Timestamp.FromDateTime(normalized);
    }

    private static string SanitizeDocumentId(string value)
    {
        var chars = value
            .Trim()
            .Select(ch => char.IsLetterOrDigit(ch) || ch is '-' or '_' ? ch : '_')
            .ToArray();

        return new string(chars);
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

    private static double GetDouble(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return 0;
        }

        try
        {
            return snapshot.GetValue<double>(field);
        }
        catch (InvalidCastException)
        {
            return snapshot.GetValue<long>(field);
        }
    }

    private static double NormalizeMoney(double value)
    {
        return Math.Round(value, 0, MidpointRounding.AwayFromZero);
    }
}
