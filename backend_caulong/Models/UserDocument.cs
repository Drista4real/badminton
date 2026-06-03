using Google.Cloud.Firestore;

namespace backend_caulong.Models;

[FirestoreData]
public sealed class UserDocument
{
    [FirestoreDocumentId]
    public string Id { get; set; } = string.Empty;

    [FirestoreProperty("fullName")]
    public string FullName { get; set; } = string.Empty;

    [FirestoreProperty("email")]
    public string Email { get; set; } = string.Empty;

    [FirestoreProperty("phoneNumber")]
    public string PhoneNumber { get; set; } = string.Empty;

    [FirestoreProperty("role")]
    public string Role { get; set; } = UserRoles.Customer;

    [FirestoreProperty("walletBalance")]
    public double WalletBalance { get; set; }

    [FirestoreProperty("availableBalance")]
    public double AvailableBalance { get; set; }

    [FirestoreProperty("pendingWithdrawal")]
    public double PendingWithdrawal { get; set; }

    [FirestoreProperty("rewardPoints")]
    public int RewardPoints { get; set; }

    [FirestoreProperty("createdAt")]
    public Timestamp CreatedAt { get; set; }

    [FirestoreProperty("updatedAt")]
    public Timestamp UpdatedAt { get; set; }
}

public static class UserRoles
{
    public const string Customer = "customer";
    public const string Admin = "admin";
    public const string Owner = "owner";
}
