using backend_caulong.Models;
using backend_caulong.Services;
using Google.Cloud.Firestore;

namespace backend_caulong.Repositories;

public sealed class OrderRepository : IOrderRepository
{
    private readonly FirestoreDb _firestoreDb;
    private readonly ICancellationPolicyService _cancellationPolicyService;

    public OrderRepository(
        FirestoreDb firestoreDb,
        ICancellationPolicyService cancellationPolicyService)
    {
        _firestoreDb = firestoreDb;
        _cancellationPolicyService = cancellationPolicyService;
    }

    public async Task<OrderDocument> GetOrderAsync(
        string orderId,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        var orderSnapshot = await _firestoreDb
            .Collection("orders")
            .Document(trimmedOrderId)
            .GetSnapshotAsync(cancellationToken);

        if (!orderSnapshot.Exists)
        {
            throw new OrderNotFoundException(trimmedOrderId);
        }

        return orderSnapshot.ConvertTo<OrderDocument>();
    }

    public async Task<OrderDocument> GetOrderForUserAsync(
        string orderId,
        string userId,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        var trimmedUserId = userId.Trim();
        var order = await GetOrderAsync(trimmedOrderId, cancellationToken);

        if (!string.Equals(order.UserId, trimmedUserId, StringComparison.Ordinal))
        {
            throw new OrderForbiddenException(trimmedOrderId);
        }

        return order;
    }

    public async Task<OrderDocument> GetOrderByPaymentContentAsync(
        string paymentContent,
        CancellationToken cancellationToken = default)
    {
        var trimmedPaymentContent = paymentContent.Trim().ToUpperInvariant();
        var orderSnapshot = await _firestoreDb
            .Collection("orders")
            .WhereEqualTo("paymentContent", trimmedPaymentContent)
            .Limit(1)
            .GetSnapshotAsync(cancellationToken);

        var document = orderSnapshot.Documents.FirstOrDefault(document => document.Exists);
        if (document is null)
        {
            throw new OrderNotFoundException(trimmedPaymentContent);
        }

        return document.ConvertTo<OrderDocument>();
    }

    public async Task SetPaymentContentIfMissingAsync(
        string orderId,
        string paymentContent,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        var trimmedPaymentContent = paymentContent.Trim().ToUpperInvariant();
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(trimmedOrderId);
            }

            var existingPaymentContent = GetString(orderSnapshot, "paymentContent");
            if (!string.IsNullOrWhiteSpace(existingPaymentContent))
            {
                return;
            }

            transaction.Update(orderRef, new Dictionary<string, object>
            {
                ["paymentContent"] = trimmedPaymentContent,
                ["updatedAt"] = Timestamp.FromDateTime(DateTime.UtcNow),
            });
        }, cancellationToken: cancellationToken);
    }

    public async Task EnsureOrderBelongsToUserAsync(
        string orderId,
        string userId,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        var trimmedUserId = userId.Trim();
        var orderSnapshot = await _firestoreDb
            .Collection("orders")
            .Document(trimmedOrderId)
            .GetSnapshotAsync(cancellationToken);

        if (!orderSnapshot.Exists)
        {
            throw new OrderNotFoundException(trimmedOrderId);
        }

        var orderUserId = GetString(orderSnapshot, "userId");
        if (!string.Equals(orderUserId, trimmedUserId, StringComparison.Ordinal))
        {
            throw new OrderForbiddenException(trimmedOrderId);
        }
    }

    public async Task<OrderRewardPointWriteResult> AddPointsOnCompletedOrderAsync(
        string orderId,
        double vndPerPoint,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = orderId.Trim();
        var result = new OrderRewardPointWriteResult(trimmedOrderId, 0, false);
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new InvalidOperationException($"Order '{orderId}' was not found.");
            }

            var status = GetString(orderSnapshot, "status");
            if (!string.Equals(status, OrderStatuses.Completed, StringComparison.OrdinalIgnoreCase))
            {
                result = new OrderRewardPointWriteResult(trimmedOrderId, 0, false);
                return;
            }

            if (!IsRewardEligibleCompletedOrder(orderSnapshot))
            {
                result = new OrderRewardPointWriteResult(trimmedOrderId, 0, false);
                return;
            }

            if (GetBool(orderSnapshot, "rewardPointsGranted"))
            {
                result = new OrderRewardPointWriteResult(
                    trimmedOrderId,
                    GetInt(orderSnapshot, "rewardPoints"),
                    false);
                return;
            }

            var userId = GetString(orderSnapshot, "userId");
            if (string.IsNullOrWhiteSpace(userId))
            {
                throw new InvalidOperationException($"Order '{orderId}' does not contain userId.");
            }

            var userRef = _firestoreDb.Collection("users").Document(userId);
            var userSnapshot = await transaction.GetSnapshotAsync(userRef, cancellationToken);
            var now = Timestamp.FromDateTime(DateTime.UtcNow);
            if (!userSnapshot.Exists || string.IsNullOrWhiteSpace(GetString(userSnapshot, "email")))
            {
                transaction.Update(orderRef, new Dictionary<string, object>
                {
                    ["rewardPoints"] = 0,
                    ["rewardPointsGranted"] = true,
                    ["rewardPointsSkippedReason"] = "missing_email",
                    ["rewardPointsGrantedAt"] = now,
                    ["updatedAt"] = now,
                });

                result = new OrderRewardPointWriteResult(trimmedOrderId, 0, false);
                return;
            }

            var normalizedVndPerPoint = NormalizeMoney(vndPerPoint);
            if (normalizedVndPerPoint <= 0)
            {
                throw new InvalidOperationException("vndPerPoint must be greater than zero.");
            }

            var actualPaidAmount = CalculateRewardEligiblePaidAmount(orderSnapshot);
            var points = (int)Math.Floor(actualPaidAmount / normalizedVndPerPoint);

            if (points > 0)
            {
                transaction.Set(userRef, new Dictionary<string, object>
                {
                    ["points"] = FieldValue.Increment(points),
                    ["loyaltyPoints"] = FieldValue.Increment(points),
                    ["rewardPoints"] = FieldValue.Increment(points),
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            transaction.Update(orderRef, new Dictionary<string, object>
            {
                ["rewardPoints"] = points,
                ["rewardPointsGranted"] = true,
                ["rewardPointsGrantedAt"] = now,
                ["updatedAt"] = now,
            });

            result = new OrderRewardPointWriteResult(trimmedOrderId, points, points > 0);
        }, cancellationToken: cancellationToken);

        return result;
    }

    private static double CalculateRewardEligiblePaidAmount(DocumentSnapshot orderSnapshot)
    {
        var paidAmount = NormalizeMoney(GetDouble(orderSnapshot, "paidAmount"));
        if (paidAmount <= 0)
        {
            paidAmount = NormalizeMoney(GetDouble(orderSnapshot, "totalPrice"));
        }

        var walletDiscount = NormalizeMoney(GetDouble(orderSnapshot, "appWalletDiscount"));
        var pointDiscount = NormalizeMoney(GetDouble(orderSnapshot, "appPointDiscount"));
        var originalTotal = NormalizeMoney(GetDouble(orderSnapshot, "originalTotalPrice"));
        var paidByCashOrWallet = Math.Max(0d, NormalizeMoney(paidAmount + walletDiscount));

        if (originalTotal <= 0)
        {
            return paidByCashOrWallet;
        }

        var maximumRewardableAmount = Math.Max(0d, NormalizeMoney(originalTotal - pointDiscount));
        return Math.Min(paidByCashOrWallet, maximumRewardableAmount);
    }

    private static bool IsRewardEligibleCompletedOrder(DocumentSnapshot orderSnapshot)
    {
        var paymentStatus = GetString(orderSnapshot, "paymentStatus");
        var hasSuccessfulPaymentStatus =
            string.Equals(paymentStatus, "success", StringComparison.OrdinalIgnoreCase)
            || string.Equals(paymentStatus, "paid", StringComparison.OrdinalIgnoreCase);
        if (!hasSuccessfulPaymentStatus)
        {
            return false;
        }

        if (GetTimestamp(orderSnapshot, "paidAt") is null &&
            GetTimestamp(orderSnapshot, "confirmedAt") is null)
        {
            return false;
        }

        return CalculateRewardEligiblePaidAmount(orderSnapshot) > 0;
    }

    public async Task<OrderPaymentWriteResult> ProcessPaidWebhookAsync(
        OrderPaymentWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = request.OrderId.Trim();
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);

        return await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(request.OrderId);
            }

            var status = GetString(orderSnapshot, "status");
            var now = Timestamp.FromDateTime(DateTime.UtcNow);

            if (string.Equals(status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                var totalPrice = NormalizeMoney(GetDouble(orderSnapshot, "totalPrice"));
                var paidAmount = NormalizeMoney(request.Amount);
                if (paidAmount < totalPrice)
                {
                    throw new InsufficientPaymentException(trimmedOrderId, paidAmount, totalPrice);
                }

                var bookingSnapshots = await GetRelatedBookingSnapshotsAsync(
                    transaction,
                    orderSnapshot,
                    request.BookingIds,
                    cancellationToken);

                transaction.Update(orderRef, new Dictionary<string, object>
                {
                    ["status"] = OrderStatuses.Confirmed,
                    ["orderStatus"] = OrderStatuses.Confirmed,
                    ["paymentStatus"] = "success",
                    ["paidAt"] = now,
                    ["confirmedAt"] = now,
                    ["updatedAt"] = now,
                    ["paymentProvider"] = request.Provider ?? "webhook",
                    ["paymentTransactionId"] = request.TransactionId ?? string.Empty,
                    ["paidAmount"] = paidAmount,
                });

                foreach (var bookingSnapshot in bookingSnapshots.Where(snapshot => snapshot.Exists))
                {
                    transaction.Update(bookingSnapshot.Reference, new Dictionary<string, object>
                    {
                        ["status"] = BookingStatuses.Confirmed,
                        ["orderStatus"] = OrderStatuses.Confirmed,
                        ["paymentStatus"] = "success",
                        ["paidAt"] = now,
                        ["confirmedAt"] = now,
                        ["updatedAt"] = now,
                    });
                }

                SetBookingSlotLockStatus(transaction, bookingSnapshots, BookingStatuses.Confirmed, now);

                return new OrderPaymentWriteResult(
                    OrderPaymentWriteAction.Confirmed,
                    "Payment confirmed.",
                    string.Empty,
                    0);
            }

            if (string.Equals(status, OrderStatuses.Cancelled, StringComparison.OrdinalIgnoreCase))
            {
                var userId = await ResolveUserIdAsync(
                    transaction,
                    orderSnapshot,
                    request.BookingIds,
                    cancellationToken);

                if (string.IsNullOrWhiteSpace(userId))
                {
                    throw new InvalidOperationException(
                        $"Order '{request.OrderId}' is cancelled but does not contain userId.");
                }

                var refundAmount = request.Amount > 0
                    ? NormalizeMoney(request.Amount)
                    : NormalizeMoney(GetDouble(orderSnapshot, "totalPrice"));

                return new OrderPaymentWriteResult(
                    OrderPaymentWriteAction.RefundToWallet,
                    "Payment arrived after cancellation. Refunded to wallet.",
                    userId,
                    refundAmount);
            }

            return new OrderPaymentWriteResult(
                OrderPaymentWriteAction.AlreadyProcessed,
                "Order is already processed.",
                string.Empty,
                0);
        }, cancellationToken: cancellationToken);
    }

    public async Task<IReadOnlyList<string>> GetExpiredPendingOrderIdsAsync(
        DateTime cutoffUtc,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var cutoff = Timestamp.FromDateTime(cutoffUtc);
        var expiredOrders = await _firestoreDb
            .Collection("orders")
            .WhereEqualTo("status", OrderStatuses.Pending)
            .WhereLessThanOrEqualTo("createdAt", cutoff)
            .Limit(pageSize)
            .GetSnapshotAsync(cancellationToken);

        return expiredOrders.Documents
            .Where(document => document.Exists)
            .Select(document => document.Reference.Id)
            .ToArray();
    }

    public async Task CancelPendingOrderIfExpiredAsync(
        string orderId,
        DateTime cutoffUtc,
        CancellationToken cancellationToken = default)
    {
        var cutoff = Timestamp.FromDateTime(cutoffUtc);
        var orderRef = _firestoreDb.Collection("orders").Document(orderId.Trim());

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                return;
            }

            var status = GetString(orderSnapshot, "status");
            if (!string.Equals(status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            var createdAt = GetTimestamp(orderSnapshot, "createdAt");
            if (createdAt is null || createdAt.Value > cutoff)
            {
                return;
            }

            var bookingSnapshots = await GetRelatedBookingSnapshotsAsync(
                transaction,
                orderSnapshot,
                requestBookingIds: null,
                cancellationToken);

            var nowUtc = DateTime.UtcNow;
            var now = Timestamp.FromDateTime(nowUtc);
            await _cancellationPolicyService.ApplyCancellationAsync(
                transaction,
                new CancellationPolicyRequest(
                    GetString(orderSnapshot, "userId"),
                    bookingSnapshots,
                    nowUtc,
                    now),
                cancellationToken);

            transaction.Update(orderRef, new Dictionary<string, object>
            {
                ["status"] = OrderStatuses.Cancelled,
                ["orderStatus"] = OrderStatuses.Cancelled,
                ["paymentStatus"] = "expired",
                ["cancelledReason"] = "payment_timeout",
                ["cancelledAt"] = now,
                ["updatedAt"] = now,
            });

            foreach (var bookingSnapshot in bookingSnapshots.Where(snapshot => snapshot.Exists))
            {
                transaction.Update(bookingSnapshot.Reference, new Dictionary<string, object>
                {
                    ["status"] = BookingStatuses.Cancelled,
                    ["orderStatus"] = OrderStatuses.Cancelled,
                    ["paymentStatus"] = "expired",
                    ["cancelledReason"] = "payment_timeout",
                    ["cancelledAt"] = now,
                    ["updatedAt"] = now,
                });
            }

            DeleteBookingSlotLocks(transaction, bookingSnapshots);
        }, cancellationToken: cancellationToken);
    }

    private async Task<string> ResolveUserIdAsync(
        Transaction transaction,
        DocumentSnapshot orderSnapshot,
        IReadOnlyList<string>? requestBookingIds,
        CancellationToken cancellationToken)
    {
        var userId = GetString(orderSnapshot, "userId");
        if (!string.IsNullOrWhiteSpace(userId))
        {
            return userId;
        }

        var bookingSnapshots = await GetRelatedBookingSnapshotsAsync(
            transaction,
            orderSnapshot,
            requestBookingIds,
            cancellationToken);

        return bookingSnapshots
            .Where(snapshot => snapshot.Exists)
            .Select(snapshot => GetString(snapshot, "userId"))
            .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value)) ?? string.Empty;
    }

    private async Task<IReadOnlyList<DocumentSnapshot>> GetRelatedBookingSnapshotsAsync(
        Transaction transaction,
        DocumentSnapshot orderSnapshot,
        IReadOnlyList<string>? requestBookingIds,
        CancellationToken cancellationToken)
    {
        var bookingIds = GetBookingIds(orderSnapshot, requestBookingIds);
        if (bookingIds.Count > 0)
        {
            var snapshots = new List<DocumentSnapshot>(bookingIds.Count);
            foreach (var bookingId in bookingIds)
            {
                var bookingRef = _firestoreDb.Collection("bookings").Document(bookingId);
                snapshots.Add(await transaction.GetSnapshotAsync(bookingRef, cancellationToken));
            }

            return snapshots;
        }

        var bookingsQuery = _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("orderId", orderSnapshot.Reference.Id);

        var querySnapshot = await transaction.GetSnapshotAsync(bookingsQuery, cancellationToken);
        return querySnapshot.Documents;
    }

    private static IReadOnlyCollection<string> GetBookingIds(
        DocumentSnapshot orderSnapshot,
        IReadOnlyList<string>? requestBookingIds)
    {
        if (requestBookingIds is { Count: > 0 })
        {
            return requestBookingIds
                .Where(id => !string.IsNullOrWhiteSpace(id))
                .Distinct(StringComparer.Ordinal)
                .ToArray();
        }

        if (orderSnapshot.ContainsField("bookingIds"))
        {
            return orderSnapshot.GetValue<IReadOnlyList<string>>("bookingIds")
                .Where(id => !string.IsNullOrWhiteSpace(id))
                .Distinct(StringComparer.Ordinal)
                .ToArray();
        }

        if (orderSnapshot.ContainsField("bookingId"))
        {
            var bookingId = orderSnapshot.GetValue<string>("bookingId");
            if (!string.IsNullOrWhiteSpace(bookingId))
            {
                return new[] { bookingId };
            }
        }

        return Array.Empty<string>();
    }

    private void SetBookingSlotLockStatus(
        Transaction transaction,
        IEnumerable<DocumentSnapshot> bookingSnapshots,
        string status,
        Timestamp now)
    {
        foreach (var slotLockRef in BuildSlotLockRefs(bookingSnapshots))
        {
            transaction.Set(slotLockRef, new Dictionary<string, object>
            {
                ["status"] = status,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);
        }
    }

    private void DeleteBookingSlotLocks(
        Transaction transaction,
        IEnumerable<DocumentSnapshot> bookingSnapshots)
    {
        foreach (var slotLockRef in BuildSlotLockRefs(bookingSnapshots))
        {
            transaction.Delete(slotLockRef);
        }
    }

    private IReadOnlyList<DocumentReference> BuildSlotLockRefs(IEnumerable<DocumentSnapshot> bookingSnapshots)
    {
        return bookingSnapshots
            .Where(snapshot => snapshot.Exists)
            .Select(snapshot => snapshot.ConvertTo<BookingDocument>())
            .SelectMany(booking => EnumerateSlotStarts(booking.StartTime, booking.EndTime)
                .Select(slotStart => _firestoreDb
                    .Collection("bookingSlotLocks")
                    .Document(BuildSlotLockId(booking.CourtId, ToUtcDateOnly(booking.Date), slotStart))))
            .DistinctBy(reference => reference.Path)
            .ToArray();
    }

    private static IEnumerable<int> EnumerateSlotStarts(int startTime, int endTime)
    {
        for (var slotStart = startTime; slotStart < endTime; slotStart += 30)
        {
            yield return slotStart;
        }
    }

    private static string BuildSlotLockId(string courtId, DateOnly date, int slotStart)
    {
        return $"{SanitizeDocumentId(courtId)}_{date:yyyyMMdd}_{slotStart:0000}";
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
        return snapshot.Exists && snapshot.ContainsField(field)
            ? snapshot.GetValue<string>(field)
            : string.Empty;
    }

    private static bool GetBool(DocumentSnapshot snapshot, string field)
    {
        return snapshot.Exists && snapshot.ContainsField(field) && snapshot.GetValue<bool>(field);
    }

    private static int GetInt(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return 0;
        }

        try
        {
            return snapshot.GetValue<int>(field);
        }
        catch (InvalidCastException)
        {
            return (int)snapshot.GetValue<long>(field);
        }
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

    private static Timestamp? GetTimestamp(DocumentSnapshot snapshot, string field)
    {
        return snapshot.Exists && snapshot.ContainsField(field)
            ? snapshot.GetValue<Timestamp>(field)
            : null;
    }

    private static DateOnly ToUtcDateOnly(Timestamp timestamp)
    {
        return DateOnly.FromDateTime(timestamp.ToDateTime());
    }

}
