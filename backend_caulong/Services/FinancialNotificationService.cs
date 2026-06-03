using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Cloud.Firestore;

namespace backend_caulong.Services;

public interface IFinancialNotificationService
{
    Task NotifyExpiredOrderRefundedAsync(
        string userId,
        string orderId,
        double refundAmount,
        CancellationToken cancellationToken = default);
}

public sealed class FinancialNotificationService : IFinancialNotificationService
{
    private const string ExpiredOrderRefundTitle = "Hoàn tiền vào Ví Tiền";
    private const string ExpiredOrderRefundMessage =
        "Đơn hàng đã bị hủy do quá hạn, tiền của bạn đã được hoàn vào Ví Tiền";

    private readonly FirestoreDb _firestoreDb;
    private readonly FirebaseMessaging _messaging;
    private readonly ILogger<FinancialNotificationService> _logger;

    public FinancialNotificationService(
        FirestoreDb firestoreDb,
        FirebaseApp firebaseApp,
        ILogger<FinancialNotificationService> logger)
    {
        _firestoreDb = firestoreDb;
        _messaging = FirebaseMessaging.GetMessaging(firebaseApp);
        _logger = logger;
    }

    public async Task NotifyExpiredOrderRefundedAsync(
        string userId,
        string orderId,
        double refundAmount,
        CancellationToken cancellationToken = default)
    {
        var trimmedUserId = userId.Trim();
        var trimmedOrderId = orderId.Trim();
        if (string.IsNullOrWhiteSpace(trimmedUserId) || string.IsNullOrWhiteSpace(trimmedOrderId))
        {
            return;
        }

        await WriteNotificationDocumentAsync(
            trimmedUserId,
            trimmedOrderId,
            refundAmount,
            cancellationToken);

        var tokens = await GetUserFcmTokensAsync(trimmedUserId, cancellationToken);
        if (tokens.Count == 0)
        {
            _logger.LogInformation(
                "Skipped FCM push for refunded expired order {OrderId} because user {UserId} has no token.",
                trimmedOrderId,
                trimmedUserId);
            return;
        }

        var message = new MulticastMessage
        {
            Tokens = tokens,
            Notification = new Notification
            {
                Title = ExpiredOrderRefundTitle,
                Body = ExpiredOrderRefundMessage,
            },
            Data = new Dictionary<string, string>
            {
                ["type"] = "payment",
                ["orderId"] = trimmedOrderId,
                ["refundAmount"] = refundAmount.ToString("0.##"),
            },
        };

        try
        {
            var response = await _messaging.SendEachForMulticastAsync(message, cancellationToken);
            if (response.FailureCount > 0)
            {
                _logger.LogWarning(
                    "FCM push for refunded expired order {OrderId} had {FailureCount}/{TokenCount} failures.",
                    trimmedOrderId,
                    response.FailureCount,
                    tokens.Count);
            }
        }
        catch (FirebaseMessagingException ex)
        {
            _logger.LogWarning(
                ex,
                "Could not send FCM push for refunded expired order {OrderId}.",
                trimmedOrderId);
        }
    }

    private async Task WriteNotificationDocumentAsync(
        string userId,
        string orderId,
        double refundAmount,
        CancellationToken cancellationToken)
    {
        var notificationRef = _firestoreDb
            .Collection("notifications")
            .Document($"expired_refund_{SanitizeDocumentId(orderId)}");

        var snapshot = await notificationRef.GetSnapshotAsync(cancellationToken);
        if (snapshot.Exists)
        {
            return;
        }

        await notificationRef.SetAsync(new Dictionary<string, object>
        {
            ["userId"] = userId,
            ["type"] = "payment",
            ["title"] = ExpiredOrderRefundTitle,
            ["message"] = ExpiredOrderRefundMessage,
            ["isRead"] = false,
            ["orderId"] = orderId,
            ["refundAmount"] = refundAmount,
            ["createdAt"] = Timestamp.FromDateTime(DateTime.UtcNow),
            ["updatedAt"] = Timestamp.FromDateTime(DateTime.UtcNow),
        }, cancellationToken: cancellationToken);
    }

    private static string SanitizeDocumentId(string value)
    {
        var chars = value
            .Select(ch => char.IsLetterOrDigit(ch) || ch is '-' or '_' ? ch : '_')
            .ToArray();

        return new string(chars);
    }

    private async Task<IReadOnlyList<string>> GetUserFcmTokensAsync(
        string userId,
        CancellationToken cancellationToken)
    {
        var snapshot = await _firestoreDb
            .Collection("users")
            .Document(userId)
            .GetSnapshotAsync(cancellationToken);

        if (!snapshot.Exists)
        {
            return Array.Empty<string>();
        }

        var tokens = new HashSet<string>(StringComparer.Ordinal);
        AddStringField(snapshot, "fcmToken", tokens);
        AddStringField(snapshot, "deviceToken", tokens);
        AddArrayField(snapshot, "fcmTokens", tokens);
        AddArrayField(snapshot, "deviceTokens", tokens);

        return tokens.ToArray();
    }

    private static void AddStringField(
        DocumentSnapshot snapshot,
        string fieldName,
        ISet<string> tokens)
    {
        if (!snapshot.ContainsField(fieldName))
        {
            return;
        }

        var token = snapshot.GetValue<string>(fieldName).Trim();
        if (!string.IsNullOrWhiteSpace(token))
        {
            tokens.Add(token);
        }
    }

    private static void AddArrayField(
        DocumentSnapshot snapshot,
        string fieldName,
        ISet<string> tokens)
    {
        if (!snapshot.ContainsField(fieldName))
        {
            return;
        }

        foreach (var token in snapshot.GetValue<IReadOnlyList<string>>(fieldName))
        {
            var normalized = token.Trim();
            if (!string.IsNullOrWhiteSpace(normalized))
            {
                tokens.Add(normalized);
            }
        }
    }
}
