using Google.Cloud.Firestore;

namespace backend_caulong.Models;

[FirestoreData]
public sealed class OrderDocument
{
    [FirestoreDocumentId]
    public string Id { get; set; } = string.Empty;

    [FirestoreProperty("userId")]
    public string UserId { get; set; } = string.Empty;

    [FirestoreProperty("totalPrice")]
    public double TotalPrice { get; set; }

    [FirestoreProperty("status")]
    public string Status { get; set; } = OrderStatuses.Pending;

    [FirestoreProperty("bookingIds")]
    public IReadOnlyList<string> BookingIds { get; set; } = Array.Empty<string>();

    [FirestoreProperty("paymentContent")]
    public string? PaymentContent { get; set; }

    [FirestoreProperty("renewedFromOrderId")]
    public string? RenewedFromOrderId { get; set; }

    [FirestoreProperty("rewardPoints")]
    public int RewardPoints { get; set; }

    [FirestoreProperty("rewardPointsGranted")]
    public bool RewardPointsGranted { get; set; }

    [FirestoreProperty("createdAt")]
    public Timestamp CreatedAt { get; set; }

    [FirestoreProperty("updatedAt")]
    public Timestamp UpdatedAt { get; set; }
}

public static class OrderStatuses
{
    public const string Pending = "pending";
    public const string Confirmed = "confirmed";
    public const string Cancelled = "cancelled";
    public const string Completed = "completed";
    public const string RefundPending = "refund_pending";
}
