using Google.Cloud.Firestore;

namespace backend_caulong.Models;

[FirestoreData]
public sealed class CourtDocument
{
    [FirestoreDocumentId]
    public string Id { get; set; } = string.Empty;

    [FirestoreProperty("name")]
    public string Name { get; set; } = string.Empty;

    [FirestoreProperty("address")]
    public string Address { get; set; } = string.Empty;

    [FirestoreProperty("ownerId")]
    public string OwnerId { get; set; } = string.Empty;

    [FirestoreProperty("pricePerHour")]
    public double PricePerHour { get; set; }

    [FirestoreProperty("status")]
    public string Status { get; set; } = CourtStatuses.Active;

    [FirestoreProperty("isActive")]
    public bool IsActive { get; set; } = true;

    [FirestoreProperty("isMaintenance")]
    public bool IsMaintenance { get; set; }

    [FirestoreProperty("isProtected")]
    public bool IsProtected { get; set; }

    [FirestoreProperty("ratingAverage")]
    public double RatingAverage { get; set; }

    [FirestoreProperty("ratingCount")]
    public int RatingCount { get; set; }

    [FirestoreProperty("ratingTotal")]
    public int RatingTotal { get; set; }

    [FirestoreProperty("createdAt")]
    public Timestamp CreatedAt { get; set; }

    [FirestoreProperty("updatedAt")]
    public Timestamp UpdatedAt { get; set; }
}

public static class CourtStatuses
{
    public const string Active = "active";
    public const string Inactive = "inactive";
    public const string Maintenance = "maintenance";
}
