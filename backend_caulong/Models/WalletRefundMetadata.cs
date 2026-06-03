namespace backend_caulong.Models;

public sealed record WalletRefundMetadata(
    string? SourceOrderId = null,
    string? ProviderTransactionId = null,
    string? Provider = null,
    string Description = "Refund for expired booking payment.",
    string? IdempotencyKey = null);
