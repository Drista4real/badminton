using Google.Cloud.Firestore;

namespace backend_caulong.Services;

public interface ICancellationPolicyService
{
    Task ApplyCancellationAsync(
        Transaction transaction,
        CancellationPolicyRequest request,
        CancellationToken cancellationToken = default);
}

public sealed record CancellationPolicyRequest(
    string? UserId,
    IReadOnlyList<DocumentSnapshot> BookingSnapshots,
    DateTime CancelledAtUtc,
    Timestamp CancelledAt);

public sealed class CancellationPolicyService : ICancellationPolicyService
{
    private const int DailyCancellationThreshold = 3;
    private const int BookingSuspensionHours = 24;
    private static readonly TimeZoneInfo BusinessTimeZone = ResolveBusinessTimeZone();

    private readonly FirestoreDb _firestoreDb;

    public CancellationPolicyService(FirestoreDb firestoreDb)
    {
        _firestoreDb = firestoreDb;
    }

    public async Task ApplyCancellationAsync(
        Transaction transaction,
        CancellationPolicyRequest request,
        CancellationToken cancellationToken = default)
    {
        var businessDate = ToBusinessDate(request.CancelledAtUtc);
        var userId = ResolveUserId(request.UserId, request.BookingSnapshots);
        DailyCounterRead? userCounterRead = null;
        if (!string.IsNullOrWhiteSpace(userId))
        {
            var userCounterRef = _firestoreDb
                .Collection("userCancellationCounters")
                .Document(BuildDailyCounterId(userId, businessDate));
            userCounterRead = new DailyCounterRead(
                userId,
                userCounterRef,
                await transaction.GetSnapshotAsync(userCounterRef, cancellationToken));
        }

        var courtIds = request.BookingSnapshots
            .Where(snapshot => snapshot.Exists)
            .Select(snapshot => GetString(snapshot, "courtId"))
            .Where(courtId => !string.IsNullOrWhiteSpace(courtId))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        var courtCounterReads = new List<DailyCounterRead>(courtIds.Length);
        var courtSnapshotReads = new List<DocumentSnapshot>(courtIds.Length);
        foreach (var courtId in courtIds)
        {
            var counterRef = _firestoreDb
                .Collection("courtCancellationCounters")
                .Document(BuildDailyCounterId(courtId, businessDate));
            var courtRef = _firestoreDb.Collection("courts").Document(courtId);

            courtCounterReads.Add(new DailyCounterRead(
                courtId,
                counterRef,
                await transaction.GetSnapshotAsync(counterRef, cancellationToken)));
            courtSnapshotReads.Add(await transaction.GetSnapshotAsync(courtRef, cancellationToken));
        }

        if (userCounterRead is not null)
        {
            var userCancellationCount = WriteDailyCounter(
                transaction,
                userCounterRead.Reference,
                userCounterRead.Snapshot,
                userCounterRead.OwnerId,
                "userId",
                businessDate,
                request.CancelledAt);
            if (userCancellationCount == DailyCancellationThreshold)
            {
                transaction.Set(_firestoreDb.Collection("users").Document(userCounterRead.OwnerId), new Dictionary<string, object>
                {
                    ["bookingDisabledUntil"] = Timestamp.FromDateTime(request.CancelledAtUtc.AddHours(BookingSuspensionHours)),
                    ["bookingDisabledReason"] = "daily_cancellation_threshold",
                    ["bookingDisabledAt"] = request.CancelledAt,
                    ["updatedAt"] = request.CancelledAt,
                }, SetOptions.MergeAll);
            }
        }

        foreach (var counterRead in courtCounterReads)
        {
            var courtCancellationCount = WriteDailyCounter(
                transaction,
                counterRead.Reference,
                counterRead.Snapshot,
                counterRead.OwnerId,
                "courtId",
                businessDate,
                request.CancelledAt);
            if (courtCancellationCount < DailyCancellationThreshold)
            {
                continue;
            }

            var courtSnapshot = courtSnapshotReads.FirstOrDefault(
                snapshot => string.Equals(snapshot.Reference.Id, counterRead.OwnerId, StringComparison.Ordinal));
            if (courtSnapshot?.Exists != true)
            {
                continue;
            }

            transaction.Set(courtSnapshot.Reference, new Dictionary<string, object>
            {
                ["isProtected"] = true,
                ["protectedAt"] = request.CancelledAt,
                ["protectedReason"] = "daily_cancellation_threshold",
                ["updatedAt"] = request.CancelledAt,
            }, SetOptions.MergeAll);
        }
    }

    private static string ResolveUserId(
        string? userId,
        IReadOnlyList<DocumentSnapshot> bookingSnapshots)
    {
        if (!string.IsNullOrWhiteSpace(userId))
        {
            return userId.Trim();
        }

        return bookingSnapshots
            .Where(snapshot => snapshot.Exists)
            .Select(snapshot => GetString(snapshot, "userId"))
            .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value)) ?? string.Empty;
    }

    private static int WriteDailyCounter(
        Transaction transaction,
        DocumentReference counterRef,
        DocumentSnapshot counterSnapshot,
        string ownerId,
        string ownerField,
        DateOnly businessDate,
        Timestamp now)
    {
        var nextCount = GetInt(counterSnapshot, "count") + 1;
        if (counterSnapshot.Exists)
        {
            transaction.Update(counterRef, new Dictionary<string, object>
            {
                ["count"] = nextCount,
                ["updatedAt"] = now,
            });

            return nextCount;
        }

        transaction.Set(counterRef, new Dictionary<string, object>
        {
            [ownerField] = ownerId,
            ["date"] = businessDate.ToString("yyyy-MM-dd"),
            ["count"] = nextCount,
            ["createdAt"] = now,
            ["updatedAt"] = now,
        });

        return nextCount;
    }

    private static string BuildDailyCounterId(string ownerId, DateOnly businessDate)
    {
        return $"{SanitizeDocumentId(ownerId)}_{businessDate:yyyyMMdd}";
    }

    private static string SanitizeDocumentId(string value)
    {
        var trimmed = value.Trim();
        return string.IsNullOrWhiteSpace(trimmed)
            ? "unknown"
            : trimmed.Replace("/", "_", StringComparison.Ordinal);
    }

    private static DateOnly ToBusinessDate(DateTime utcDateTime)
    {
        var normalizedUtc = utcDateTime.Kind == DateTimeKind.Utc
            ? utcDateTime
            : DateTime.SpecifyKind(utcDateTime, DateTimeKind.Utc);
        var localDateTime = TimeZoneInfo.ConvertTimeFromUtc(normalizedUtc, BusinessTimeZone);
        return DateOnly.FromDateTime(localDateTime);
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

    private static string GetString(DocumentSnapshot snapshot, string field)
    {
        return snapshot.Exists && snapshot.ContainsField(field)
            ? snapshot.GetValue<string>(field)
            : string.Empty;
    }

    private static int GetInt(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return 0;
        }

        return snapshot.GetValue<object>(field) switch
        {
            int intValue => intValue,
            long longValue => (int)longValue,
            double doubleValue => (int)doubleValue,
            _ => 0,
        };
    }

    private sealed record DailyCounterRead(
        string OwnerId,
        DocumentReference Reference,
        DocumentSnapshot Snapshot);
}
