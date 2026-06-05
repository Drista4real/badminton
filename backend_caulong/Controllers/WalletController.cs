using backend_caulong.Repositories;
using backend_caulong.Security;
using backend_caulong.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend_caulong.Controllers;

[ApiController]
[Route("api/wallet")]
public sealed class WalletController : ControllerBase
{
    private readonly IWalletService _walletService;
    private readonly ILogger<WalletController> _logger;

    public WalletController(
        IWalletService walletService,
        ILogger<WalletController> logger)
    {
        _walletService = walletService;
        _logger = logger;
    }

    [HttpGet("transactions")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> GetTransactions(CancellationToken cancellationToken)
    {
        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var transactions = await _walletService.GetTransactionsAsync(userId, cancellationToken);
            return Ok(new
            {
                items = transactions.Select(transaction => new
                {
                    id = transaction.Id,
                    userId = transaction.UserId,
                    amount = transaction.Amount,
                    type = transaction.Type,
                    status = transaction.Status,
                    description = transaction.Description,
                    sourceOrderId = transaction.SourceOrderId,
                    providerTransactionId = transaction.ProviderTransactionId,
                    createdAt = transaction.CreatedAt,
                }),
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load wallet transactions for authenticated user.");
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not load wallet transactions." });
        }
    }

    [HttpPost("withdraw")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> Withdraw(
        [FromBody] WalletWithdrawRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var result = await _walletService.WithdrawAsync(userId, request, cancellationToken);
            return Ok(new
            {
                transactionId = result.TransactionId,
                newBalance = result.NewBalance,
                availableBalance = result.AvailableBalance,
                pendingWithdrawal = result.PendingWithdrawal,
            });
        }
        catch (InsufficientWalletBalanceException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not create withdrawal for authenticated user.");
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not create withdrawal request." });
        }
    }

    [HttpPost("settle-withdraw")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> SettleWithdraw(
        [FromBody] WalletWithdrawSettlementRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        try
        {
            var adminUserId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(adminUserId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var result = await _walletService.SettleWithdrawAsync(
                adminUserId,
                request,
                cancellationToken);

            return Ok(new
            {
                transactionId = result.TransactionId,
                userId = result.UserId,
                status = result.Status,
                walletBalance = result.WalletBalance,
                availableBalance = result.AvailableBalance,
                pendingWithdrawal = result.PendingWithdrawal,
            });
        }
        catch (WalletAdminForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not settle withdrawal transaction {TransactionId}.", request.TransactionId);
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not settle withdrawal request." });
        }
    }
}
