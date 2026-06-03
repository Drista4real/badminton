using backend_caulong.Repositories;
using backend_caulong.Security;
using Microsoft.AspNetCore.Mvc;

namespace backend_caulong.Controllers;

[ApiController]
[Route("api/courts")]
public sealed class CourtController : ControllerBase
{
    private readonly ICourtRepository _courtRepository;

    public CourtController(ICourtRepository courtRepository)
    {
        _courtRepository = courtRepository;
    }

    [HttpGet]
    public async Task<IActionResult> Search(
        [FromQuery] string? q,
        [FromQuery] int limit,
        CancellationToken cancellationToken)
    {
        var courts = await _courtRepository.SearchCourtsAsync(
            new CourtSearchRequest(
                User.GetFirebaseUserId(),
                q,
                limit),
            cancellationToken);

        return Ok(new
        {
            items = courts.Select(court => court.Data),
        });
    }

    [HttpGet("{courtId}")]
    public async Task<IActionResult> Detail(
        string courtId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(courtId))
        {
            return BadRequest(new { message = "courtId is required." });
        }

        try
        {
            var detail = await _courtRepository.GetCourtDetailAsync(
                courtId,
                cancellationToken);

            return Ok(new
            {
                court = detail.Court,
            });
        }
        catch (CourtNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
