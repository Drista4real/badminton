using Google.Cloud.Firestore;

namespace backend_caulong.Models;

[FirestoreData]
public sealed class BookingDocument
{
    [FirestoreDocumentId]
    public string Id { get; set; } = string.Empty;

    [FirestoreProperty("orderId")]
    public string OrderId { get; set; } = string.Empty;

    [FirestoreProperty("userId")]
    public string UserId { get; set; } = string.Empty;

    [FirestoreProperty("courtId")]
    public string CourtId { get; set; } = string.Empty;

    [FirestoreProperty("bookingType")]
    public string BookingType { get; set; } = BookingTypes.OneTime;

    // UTC midnight for the local booking date. Query equality on this field.
    [FirestoreProperty("date")]
    public Timestamp Date { get; set; }

    // Minutes from 00:00 on Date. Example: 18:30 = 1110.
    [FirestoreProperty("startTime")]
    public int StartTime { get; set; }

    [FirestoreProperty("endTime")]
    public int EndTime { get; set; }

    [FirestoreProperty("status")]
    public string Status { get; set; } = BookingStatuses.Pending;

    [FirestoreProperty("fixedWeekdays")]
    public IReadOnlyList<int> FixedWeekdays { get; set; } = Array.Empty<int>();

    [FirestoreProperty("fixedDurationMonths")]
    public int? FixedDurationMonths { get; set; }

    [FirestoreProperty("fixedStartDate")]
    public Timestamp? FixedStartDate { get; set; }

    [FirestoreProperty("fixedEndDate")]
    public Timestamp? FixedEndDate { get; set; }

    [FirestoreProperty("createdAt")]
    public Timestamp CreatedAt { get; set; }

    [FirestoreProperty("updatedAt")]
    public Timestamp UpdatedAt { get; set; }
}

public static class BookingTypes
{
    public const string OneTime = "one-time";
    public const string Fixed = "fixed";
}

public static class BookingStatuses
{
    public const string Pending = "pending";
    public const string Confirmed = "confirmed";
    public const string Completed = "completed";
    public const string Cancelled = "cancelled";
}
