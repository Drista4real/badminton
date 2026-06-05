using backend_caulong.Models;
using Google.Cloud.Firestore;

namespace backend_caulong.Repositories;

public sealed class CourtRepository : ICourtRepository
{
    private const int DefaultSearchLimit = 50;
    private const int MaxSearchLimit = 100;

    private readonly FirestoreDb _firestoreDb;

    public CourtRepository(FirestoreDb firestoreDb)
    {
        _firestoreDb = firestoreDb;
    }

    public async Task<IReadOnlyList<CourtListItem>> SearchCourtsAsync(
        CourtSearchRequest request,
        CancellationToken cancellationToken = default)
    {
        var limit = NormalizeLimit(request.Limit, DefaultSearchLimit, MaxSearchLimit);
        var canSeeProtectedCourts = await UserHasAnyPaidOrderAsync(
            request.UserId,
            cancellationToken);
        var normalizedSearchText = NormalizeSearchText(request.SearchText);
        var snapshot = await _firestoreDb
            .Collection("courts")
            .GetSnapshotAsync(cancellationToken);

        return snapshot.Documents
            .Where(document => document.Exists)
            .Where(IsSearchVisibleCourt)
            .Where(document => canSeeProtectedCourts || !GetBool(document, "isProtected"))
            .Where(document => MatchesSearchText(document, normalizedSearchText))
            .OrderBy(document => GetString(document, "code"))
            .ThenBy(document => GetString(document, "name"))
            .Take(limit)
            .Select(document => new CourtListItem(document.Reference.Id, ToApiDictionary(document)))
            .ToArray();
    }

    public async Task<CourtDetailResult> GetCourtDetailAsync(
        string courtId,
        CancellationToken cancellationToken = default)
    {
        var trimmedCourtId = courtId.Trim();
        var courtSnapshot = await _firestoreDb
            .Collection("courts")
            .Document(trimmedCourtId)
            .GetSnapshotAsync(cancellationToken);
        if (!courtSnapshot.Exists)
        {
            throw new CourtNotFoundException(trimmedCourtId);
        }

        return new CourtDetailResult(ToApiDictionary(courtSnapshot));
    }

    private async Task<bool> UserHasAnyPaidOrderAsync(
        string? userId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return false;
        }

        var trimmedUserId = userId.Trim();
        return await UserHasAnyOrderWithStatusAsync(
                trimmedUserId,
                OrderStatuses.Confirmed,
                cancellationToken)
            || await UserHasAnyOrderWithStatusAsync(
                trimmedUserId,
                OrderStatuses.Completed,
                cancellationToken);
    }

    private async Task<bool> UserHasAnyOrderWithStatusAsync(
        string userId,
        string status,
        CancellationToken cancellationToken)
    {
        var snapshot = await _firestoreDb
            .Collection("orders")
            .WhereEqualTo("userId", userId)
            .WhereEqualTo("status", status)
            .Limit(1)
            .GetSnapshotAsync(cancellationToken);

        return snapshot.Documents.Any(document => document.Exists);
    }

    private static bool IsSearchVisibleCourt(DocumentSnapshot document)
    {
        return GetBool(document, "isActive", defaultValue: true)
            && !GetBool(document, "isMaintenance")
            && IsVisibleCourtStatus(GetString(document, "status"));
    }

    private static bool IsVisibleCourtStatus(string status)
    {
        return string.IsNullOrWhiteSpace(status)
            || string.Equals(status, CourtStatuses.Active, StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "available", StringComparison.OrdinalIgnoreCase);
    }

    private static bool MatchesSearchText(DocumentSnapshot document, string? normalizedSearchText)
    {
        if (string.IsNullOrWhiteSpace(normalizedSearchText))
        {
            return true;
        }

        return ContainsNormalized(GetString(document, "name"), normalizedSearchText)
            || ContainsNormalized(GetString(document, "code"), normalizedSearchText)
            || ContainsNormalized(GetString(document, "address"), normalizedSearchText)
            || ContainsNormalized(GetString(document, "surfaceType"), normalizedSearchText);
    }

    private static bool ContainsNormalized(string value, string normalizedSearchText)
    {
        return NormalizeSearchText(value)?.Contains(normalizedSearchText, StringComparison.OrdinalIgnoreCase) == true;
    }

    private static string? NormalizeSearchText(string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();
    }

    private static IReadOnlyDictionary<string, object?> ToApiDictionary(DocumentSnapshot document)
    {
        var data = document.ToDictionary()
            .ToDictionary(
                pair => pair.Key,
                pair => ToApiValue(pair.Value),
                StringComparer.Ordinal);
        data["id"] = document.Reference.Id;
        return data;
    }

    private static object? ToApiValue(object? value)
    {
        return value switch
        {
            null => null,
            Timestamp timestamp => timestamp.ToDateTime(),
            IReadOnlyDictionary<string, object> dictionary => dictionary.ToDictionary(
                pair => pair.Key,
                pair => ToApiValue(pair.Value),
                StringComparer.Ordinal),
            IDictionary<string, object> dictionary => dictionary.ToDictionary(
                pair => pair.Key,
                pair => ToApiValue(pair.Value),
                StringComparer.Ordinal),
            IEnumerable<object> values when value is not string => values.Select(ToApiValue).ToArray(),
            _ => value,
        };
    }

    private static int NormalizeLimit(int requestedLimit, int defaultLimit, int maxLimit)
    {
        if (requestedLimit <= 0)
        {
            return defaultLimit;
        }

        return Math.Min(requestedLimit, maxLimit);
    }

    private static string SanitizeDocumentId(string value)
    {
        var trimmed = value.Trim();
        return string.IsNullOrWhiteSpace(trimmed)
            ? "unknown"
            : trimmed.Replace("/", "_", StringComparison.Ordinal);
    }

    private static string GetString(DocumentSnapshot snapshot, string field)
    {
        return snapshot.Exists && snapshot.ContainsField(field)
            ? snapshot.GetValue<string>(field)
            : string.Empty;
    }

    private static bool GetBool(DocumentSnapshot snapshot, string field, bool defaultValue = false)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return defaultValue;
        }

        return snapshot.GetValue<object>(field) switch
        {
            bool boolValue => boolValue,
            _ => defaultValue,
        };
    }

}
