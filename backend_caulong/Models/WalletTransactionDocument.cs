using Google.Cloud.Firestore;

namespace backend_caulong.Models;

[FirestoreData]
public sealed class WalletTransactionDocument
{
    [FirestoreDocumentId]
    public string Id { get; set; } = string.Empty;

    [FirestoreProperty("userId")]
    public string UserId { get; set; } = string.Empty;

    [FirestoreProperty("amount")]
    public double Amount { get; set; }

    [FirestoreProperty("type")]
    public string Type { get; set; } = WalletTransactionTypes.Refund;

    [FirestoreProperty("status")]
    public string Status { get; set; } = WalletTransactionStatuses.Completed;

    [FirestoreProperty("sourceOrderId")]
    public string? SourceOrderId { get; set; }

    [FirestoreProperty("providerTransactionId")]
    public string? ProviderTransactionId { get; set; }

    [FirestoreProperty("provider")]
    public string? Provider { get; set; }

    [FirestoreProperty("bankName")]
    public string? BankName { get; set; }

    [FirestoreProperty("bankAccountNumber")]
    public string? BankAccountNumber { get; set; }

    [FirestoreProperty("bankAccountName")]
    public string? BankAccountName { get; set; }

    [FirestoreProperty("description")]
    public string Description { get; set; } = string.Empty;

    [FirestoreProperty("createdAt")]
    public Timestamp CreatedAt { get; set; }
}

public static class WalletTransactionTypes
{
    public const string Refund = "refund";
    public const string Withdraw = "withdraw";
}

public static class WalletTransactionStatuses
{
    public const string Completed = "completed";
    public const string Pending = "pending";
    public const string Failed = "failed";
}
