using System.Globalization;
using backend_caulong.Models;
using Google.Cloud.Firestore;

namespace backend_caulong.Services;

public interface IBookingNotificationService
{
    Task NotifyFixedBookingConfirmedAsync(
        string orderId,
        CancellationToken cancellationToken = default);

    Task NotifyOrderCancelledAsync(
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

        var bookings = await GetOrderBookingsAsync(
            orderSnapshot,
            trimmedOrderId,
            cancellationToken);
        if (bookings.Count == 0)
        {
            return;
        }

        var fixedBookings = bookings.Where(IsFixedBooking).ToArray();
        if (fixedBookings.Length == 0)
        {
            await WriteOneTimeBookingConfirmedNotificationAsync(
                trimmedOrderId,
                userId,
                orderSnapshot,
                bookings[0],
                cancellationToken);
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
                fixedBookings.Length,
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
            ["bookingCount"] = fixedBookings.Length,
            ["totalPrice"] = totalPrice,
            ["createdAt"] = now,
            ["updatedAt"] = now,
        }, cancellationToken: cancellationToken);

        await DeletePendingFixedBookingNotificationAsync(trimmedOrderId, cancellationToken);
    }

    public async Task NotifyOrderCancelledAsync(
        string orderId,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        if (string.IsNullOrWhiteSpace(trimmedOrderId))
        {
            return;
        }

        var orderSnapshot = await _firestoreDb
            .Collection("orders")
            .Document(trimmedOrderId)
            .GetSnapshotAsync(cancellationToken);
        if (!orderSnapshot.Exists)
        {
            return;
        }

        var status = GetString(orderSnapshot, "status");
        if (!string.Equals(status, OrderStatuses.Cancelled, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var userId = GetString(orderSnapshot, "userId");
        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        var bookings = await GetOrderBookingsAsync(orderSnapshot, trimmedOrderId, cancellationToken);
        if (bookings.Count == 0)
        {
            return;
        }

        var notificationRef = _firestoreDb
            .Collection("notifications")
            .Document($"booking_cancelled_{SanitizeDocumentId(trimmedOrderId)}");
        var snapshot = await notificationRef.GetSnapshotAsync(cancellationToken);
        if (snapshot.Exists)
        {
            return;
        }

        var template = bookings[0];
        var fixedBookings = bookings.Where(IsFixedBooking).ToArray();
        var isFixed = fixedBookings.Length > 0;
        var courtLabel = await GetCourtLabelAsync(template.CourtId, cancellationToken);
        var reason = GetString(orderSnapshot, "cancelledReason");
        var title = string.Equals(reason, "payment_timeout", StringComparison.OrdinalIgnoreCase)
            ? "Đơn đặt sân đã hết hạn"
            : "Đơn đặt sân đã hủy";
        var restrictionSuffix = await GetBookingDisabledSuffixAsync(userId, cancellationToken);
        var message = (isFixed
            ? BuildFixedBookingCancelledMessage(courtLabel, fixedBookings, reason)
            : BuildOneTimeBookingCancelledMessage(courtLabel, template, reason)) + restrictionSuffix;
        var now = Timestamp.FromDateTime(DateTime.UtcNow);

        await notificationRef.SetAsync(new Dictionary<string, object?>
        {
            ["userId"] = userId,
            ["type"] = "booking",
            ["title"] = title,
            ["message"] = message,
            ["isRead"] = false,
            ["orderId"] = trimmedOrderId,
            ["bookingId"] = template.Id,
            ["courtId"] = template.CourtId,
            ["cancelledReason"] = reason,
            ["bookingCount"] = bookings.Count,
            ["createdAt"] = now,
            ["updatedAt"] = now,
        }, cancellationToken: cancellationToken);
    }

    private async Task WriteOneTimeBookingConfirmedNotificationAsync(
        string orderId,
        string userId,
        DocumentSnapshot orderSnapshot,
        BookingDocument booking,
        CancellationToken cancellationToken)
    {
        var notificationRef = _firestoreDb
            .Collection("notifications")
            .Document($"booking_confirmed_{SanitizeDocumentId(orderId)}");
        var notificationSnapshot = await notificationRef.GetSnapshotAsync(cancellationToken);
        if (notificationSnapshot.Exists)
        {
            return;
        }

        var courtLabel = await GetCourtLabelAsync(booking.CourtId, cancellationToken);
        var totalPrice = ResolveOrderTotal(orderSnapshot);
        var now = Timestamp.FromDateTime(DateTime.UtcNow);

        await notificationRef.SetAsync(new Dictionary<string, object?>
        {
            ["userId"] = userId,
            ["type"] = "booking",
            ["title"] = "Đặt sân đã thanh toán",
            ["message"] = BuildOneTimeBookingConfirmedMessage(
                courtLabel,
                booking,
                totalPrice),
            ["isRead"] = false,
            ["orderId"] = orderId,
            ["bookingId"] = booking.Id,
            ["courtId"] = booking.CourtId,
            ["bookingDate"] = booking.Date,
            ["startTime"] = booking.StartTime,
            ["endTime"] = booking.EndTime,
            ["totalPrice"] = totalPrice,
            ["createdAt"] = now,
            ["updatedAt"] = now,
        }, cancellationToken: cancellationToken);
    }

    private async Task<IReadOnlyList<BookingDocument>> GetOrderBookingsAsync(
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
            if (booking is not null)
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

    private static string BuildOneTimeBookingConfirmedMessage(
        string courtLabel,
        BookingDocument booking,
        double totalPrice)
    {
        var bookingDate = ToDateOnly(booking.Date);
        var date = bookingDate is null ? "ngày đã chọn" : FormatDate(bookingDate.Value);
        var time = $"{FormatMinutes(booking.StartTime)} - {FormatMinutes(booking.EndTime)}";
        var amount = totalPrice.ToString("N0", VietnameseCulture);

        return
            $"Bạn đã thanh toán thành công {courtLabel} ngày {date}, giờ chơi {time}. " +
            $"Số tiền {amount} đ.";
    }

    private static string BuildOneTimeBookingCancelledMessage(
        string courtLabel,
        BookingDocument booking,
        string reason)
    {
        var bookingDate = ToDateOnly(booking.Date);
        var date = bookingDate is null ? "ngày đã chọn" : FormatDate(bookingDate.Value);
        var time = $"{FormatMinutes(booking.StartTime)} - {FormatMinutes(booking.EndTime)}";
        var suffix = string.Equals(reason, "payment_timeout", StringComparison.OrdinalIgnoreCase)
            ? "Đơn đã tự hủy vì quá thời gian thanh toán. Vui lòng đặt lại nếu bạn vẫn muốn giữ khung giờ này."
            : "Đơn đã được hủy theo yêu cầu của bạn.";

        return $"{courtLabel} ngày {date}, giờ chơi {time}. {suffix}";
    }

    private static string BuildFixedBookingCancelledMessage(
        string courtLabel,
        IReadOnlyList<BookingDocument> fixedBookings,
        string reason)
    {
        var template = fixedBookings[0];
        var fixedStartDate = ToDateOnly(template.FixedStartDate) ?? ToDateOnly(template.Date);
        var fixedEndDate = ToDateOnly(template.FixedEndDate) ?? fixedBookings
            .Select(booking => ToDateOnly(booking.Date))
            .OfType<DateOnly>()
            .OrderBy(date => date)
            .LastOrDefault();
        var startDate = fixedStartDate is null ? "ngày bắt đầu đã chọn" : FormatDate(fixedStartDate.Value);
        var endDate = fixedEndDate == default ? "ngày kết thúc đã chọn" : FormatDate(fixedEndDate);
        var weekdays = template.FixedWeekdays.Count > 0
            ? FormatWeekdays(template.FixedWeekdays)
            : FormatWeekdays(
                fixedBookings
                    .Select(booking => ToApiDayOfWeek(ToDateOnly(booking.Date)?.DayOfWeek))
                    .Where(day => day is not null)
                    .Select(day => day!.Value));
        var time = $"{FormatMinutes(template.StartTime)} - {FormatMinutes(template.EndTime)}";
        var suffix = string.Equals(reason, "payment_timeout", StringComparison.OrdinalIgnoreCase)
            ? "Lịch đã tự hủy vì quá thời gian thanh toán. Vui lòng đặt lại nếu còn nhu cầu."
            : "Lịch đã được hủy theo yêu cầu của bạn.";

        return
            $"Lịch cố định {courtLabel} từ {startDate} đến {endDate}, vào {weekdays}, " +
            $"giờ chơi {time}. {suffix}";
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

    private async Task<string> GetBookingDisabledSuffixAsync(
        string userId,
        CancellationToken cancellationToken)
    {
        var snapshot = await _firestoreDb
            .Collection("users")
            .Document(userId.Trim())
            .GetSnapshotAsync(cancellationToken);
        if (!snapshot.Exists || !snapshot.ContainsField("bookingDisabledUntil"))
        {
            return string.Empty;
        }

        var disabledUntil = snapshot.GetValue<Timestamp>("bookingDisabledUntil").ToDateTime();
        if (disabledUntil <= DateTime.UtcNow)
        {
            return string.Empty;
        }

        return $" Tài khoản của bạn tạm khóa đặt sân đến {FormatDateTime(disabledUntil)} do hủy sân nhiều lần trong ngày.";
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

    private static string FormatDateTime(DateTime utcDateTime)
    {
        var localDateTime = TimeZoneInfo.ConvertTimeFromUtc(
            DateTime.SpecifyKind(utcDateTime, DateTimeKind.Utc),
            ResolveBusinessTimeZone());
        return localDateTime.ToString("HH:mm dd/MM/yyyy", VietnameseCulture);
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
