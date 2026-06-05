namespace backend_caulong.Repositories;

public interface ICourtRepository
{
    Task<IReadOnlyList<CourtListItem>> SearchCourtsAsync(
        CourtSearchRequest request,
        CancellationToken cancellationToken = default);

    Task<CourtDetailResult> GetCourtDetailAsync(
        string courtId,
        CancellationToken cancellationToken = default);
}

public sealed record CourtSearchRequest(
    string? UserId,
    string? SearchText,
    int Limit);

public sealed record CourtListItem(
    string Id,
    IReadOnlyDictionary<string, object?> Data);

public sealed record CourtDetailResult(
    IReadOnlyDictionary<string, object?> Court);

public sealed class CourtNotFoundException : Exception
{
    public CourtNotFoundException(string courtId)
        : base($"Court '{courtId}' was not found.")
    {
        CourtId = courtId;
    }

    public string CourtId { get; }
}
