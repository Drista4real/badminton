using backend_caulong.Models;
using backend_caulong.Repositories;
using backend_caulong.Security;
using backend_caulong.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend_caulong.Controllers;

[ApiController]
[Route("api/bookings")]
public sealed class BookingController : ControllerBase
{
    private readonly IBookingTransactionService _bookingTransactionService;
    private readonly IBookingRepository _bookingRepository;
    private readonly IBookingNotificationService _bookingNotificationService;
    private readonly ILogger<BookingController> _logger;

    public BookingController(
        IBookingTransactionService bookingTransactionService,
        IBookingRepository bookingRepository,
        IBookingNotificationService bookingNotificationService,
        ILogger<BookingController> logger)
    {
        _bookingTransactionService = bookingTransactionService;
        _bookingRepository = bookingRepository;
        _bookingNotificationService = bookingNotificationService;
        _logger = logger;
    }

    [HttpGet("active")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> GetActive(CancellationToken cancellationToken)
    {
        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var bookings = await _bookingRepository.GetActiveBookingsAsync(cancellationToken);
            return Ok(new
            {
                items = bookings.Select(ToPublicBooking),
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load active bookings.");
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not load active bookings." });
        }
    }

    [HttpPost("create")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> Create(
        [FromBody] BookingRequest request,
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

            var result = await _bookingTransactionService.CreateBookingAsync(
                userId,
                request,
                cancellationToken);

            return Ok(new
            {
                orderId = result.OrderId,
                bookingIds = result.BookingIds,
                totalPrice = result.TotalPrice,
            });
        }
        catch (BookingConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (BookingSuspendedWriteException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Tài khoản đã bị tạm khóa đặt sân do hủy sân quá nhiều lần trong ngày.",
                disabledUntilUtc = ex.DisabledUntilUtc,
            });
        }
        catch (ProtectedCourtWriteException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Sân đang được bảo vệ. Bạn cần có ít nhất một đơn đã thanh toán thành công để đặt sân này.",
                courtId = ex.CourtId,
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Could not create booking for court {CourtId} on {Date}.",
                request.CourtId,
                request.Date);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not create booking." });
        }
    }

    [HttpPost("create-fixed")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> CreateFixed(
        [FromBody] FixedBookingRequest request,
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

            var result = await _bookingTransactionService.CreateFixedBookingAsync(
                userId,
                request,
                cancellationToken);

            return Ok(new
            {
                orderId = result.OrderId,
                bookingIds = result.BookingIds,
                bookingCount = result.BookingIds.Count,
                totalPrice = result.TotalPrice,
            });
        }
        catch (BookingConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (BookingSuspendedWriteException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Tài khoản đã bị tạm khóa đặt sân do hủy sân quá nhiều lần trong ngày.",
                disabledUntilUtc = ex.DisabledUntilUtc,
            });
        }
        catch (ProtectedCourtWriteException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Sân đang được bảo vệ. Bạn cần có ít nhất một đơn đã thanh toán thành công để đặt sân này.",
                courtId = ex.CourtId,
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Could not create fixed booking for court {CourtId} from {StartDate}.",
                request.CourtId,
                request.StartDate);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not create fixed booking." });
        }
    }

    [HttpPost("renew-fixed")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> RenewFixed(
        [FromBody] RenewFixedBookingRequest request,
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

            var result = await _bookingTransactionService.RenewFixedBookingAsync(
                userId,
                request,
                cancellationToken);

            return Ok(new
            {
                newOrderId = result.NewOrderId,
                orderId = result.NewOrderId,
                bookingIds = result.BookingIds,
                bookingCount = result.BookingIds.Count,
                totalPrice = result.TotalPrice,
                fixedStartDate = result.FixedStartDate,
                fixedEndDate = result.FixedEndDate,
                durationMonths = result.DurationMonths,
            });
        }
        catch (BookingConflictException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (BookingSuspendedWriteException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Tài khoản đã bị tạm khóa đặt sân do hủy sân quá nhiều lần trong ngày.",
                disabledUntilUtc = ex.DisabledUntilUtc,
            });
        }
        catch (ProtectedCourtWriteException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Sân đang được bảo vệ. Bạn cần có ít nhất một đơn đã thanh toán thành công để đặt sân này.",
                courtId = ex.CourtId,
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Could not renew fixed booking for old order {OldOrderId}.",
                request.OldOrderId);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not renew fixed booking." });
        }
    }

    [HttpPost("cancel")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> Cancel(
        [FromBody] CancelBookingRequest request,
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

            var result = await _bookingTransactionService.CancelBookingAsync(
                userId,
                request,
                cancellationToken);

            await NotifyOrderCancelledAsync(result.OrderId, cancellationToken);

            return Ok(new
            {
                orderId = result.OrderId,
                bookingIds = result.BookingIds,
                status = OrderStatuses.Cancelled,
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (CancelBookingWriteNotAllowedException ex)
        {
            return BadRequest(new
            {
                message = ex.Message,
                orderId = ex.OrderId,
                status = ex.Status,
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not cancel order {OrderId}.", request.OrderId);
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not cancel booking order." });
        }
    }

    private async Task NotifyOrderCancelledAsync(
        string orderId,
        CancellationToken cancellationToken)
    {
        try
        {
            await _bookingNotificationService.NotifyOrderCancelledAsync(
                orderId,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Cancelled order {OrderId}, but could not write cancellation notification.",
                orderId);
        }
    }

    [HttpPost("report-absence")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> ReportAbsence(
        [FromBody] ReportFixedAbsenceRequest request,
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

            var result = await _bookingTransactionService.ReportFixedAbsenceAsync(
                userId,
                request,
                cancellationToken);

            return Ok(new
            {
                bookingId = result.BookingId,
                orderId = result.OrderId,
                status = BookingStatuses.CancelledByUserFixed,
                refundedAmount = result.RefundedAmount,
                absenceCountThisMonth = result.AbsenceCountThisMonth,
                refunded = result.Refunded,
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (MonthlyFixedAbsenceLimitExceededException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (FixedAbsenceWriteNotAllowedException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not report fixed absence for booking {BookingId}.", request.BookingId);
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not report fixed absence." });
        }
    }

    [HttpPost("cancel-with-refund")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> CancelWithRefund(
        [FromBody] CancelOrderWithRefundRequest request,
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

            var result = await _bookingTransactionService.CancelOrderWithRefundAsync(
                userId,
                request,
                cancellationToken);

            await NotifyOrderCancelledAsync(result.OrderId, cancellationToken);

            return Ok(new
            {
                orderId = result.OrderId,
                bookingIds = result.BookingIds,
                status = result.Status,
                refundMethod = result.RefundMethod,
                refundAmount = result.RefundAmount,
                refundRate = result.RefundRate,
                refundedToWallet = result.RefundedToWallet,
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (CancelBookingWriteNotAllowedException ex)
        {
            return BadRequest(new
            {
                message = ex.Message,
                orderId = ex.OrderId,
                status = ex.Status,
            });
        }
        catch (FixedAbsenceWriteNotAllowedException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not cancel order {OrderId} with refund.", request.OrderId);
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not cancel booking order with refund." });
        }
    }

    private static object ToPublicBooking(BookingDocument booking)
    {
        return new
        {
            id = booking.Id,
            courtId = booking.CourtId,
            bookingType = booking.BookingType,
            status = booking.Status,
            date = booking.Date.ToDateTime(),
            startTime = booking.StartTime,
            endTime = booking.EndTime,
            fixedWeekdays = booking.FixedWeekdays,
            fixedDurationMonths = booking.FixedDurationMonths,
            fixedStartDate = booking.FixedStartDate?.ToDateTime(),
            fixedEndDate = booking.FixedEndDate?.ToDateTime(),
            createdAt = booking.CreatedAt.ToDateTime(),
            updatedAt = booking.UpdatedAt.ToDateTime(),
        };
    }
}
