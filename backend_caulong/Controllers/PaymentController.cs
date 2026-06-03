using backend_caulong.Models;
using backend_caulong.Repositories;
using backend_caulong.Security;
using backend_caulong.Services;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend_caulong.Controllers;

[ApiController]
[Route("api/payment")]
public sealed class PaymentController : ControllerBase
{
    private readonly IVietQrService _vietQrService;
    private readonly ISePayTransactionLookupService _sePayTransactionLookupService;
    private readonly IOrderRepository _orderRepository;
    private readonly IBookingNotificationService _bookingNotificationService;
    private readonly ICancellationPolicyService _cancellationPolicyService;
    private readonly FirestoreDb _firestoreDb;
    private readonly IWebHostEnvironment _environment;
    private readonly IConfiguration _configuration;
    private readonly ILogger<PaymentController> _logger;

    public PaymentController(
        IVietQrService vietQrService,
        ISePayTransactionLookupService sePayTransactionLookupService,
        IOrderRepository orderRepository,
        IBookingNotificationService bookingNotificationService,
        ICancellationPolicyService cancellationPolicyService,
        FirestoreDb firestoreDb,
        IWebHostEnvironment environment,
        IConfiguration configuration,
        ILogger<PaymentController> logger)
    {
        _vietQrService = vietQrService;
        _sePayTransactionLookupService = sePayTransactionLookupService;
        _orderRepository = orderRepository;
        _bookingNotificationService = bookingNotificationService;
        _cancellationPolicyService = cancellationPolicyService;
        _firestoreDb = firestoreDb;
        _environment = environment;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost("apply-benefits")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> ApplyBenefits(
        [FromBody] ApplyPaymentBenefitsRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            return BadRequest(new { message = "orderId is required." });
        }

        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var result = await ApplyPaymentBenefitsAsync(
                userId,
                request,
                cancellationToken);

            if (result.IsFullyPaid)
            {
                await NotifyFixedBookingConfirmedAsync(
                    request.OrderId.Trim(),
                    cancellationToken);
            }

            return Ok(result);
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not apply payment benefits for order {OrderId}.", request.OrderId);
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not apply payment benefits." });
        }
    }

    [HttpPost("generate-qr")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> GenerateQr(
        [FromBody] GenerateQrRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            return BadRequest(new { message = "orderId is required." });
        }

        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var order = await _orderRepository.GetOrderForUserAsync(
                request.OrderId.Trim(),
                userId,
                cancellationToken);

            var amount = NormalizeMoney(order.TotalPrice);
            if (amount <= 0)
            {
                return BadRequest(new { message = "Order totalPrice must be greater than zero." });
            }

            var paymentContent = string.IsNullOrWhiteSpace(order.PaymentContent)
                ? PaymentReference.BuildPaymentContent(_configuration, order.Id)
                : order.PaymentContent.Trim().ToUpperInvariant();

            await _orderRepository.SetPaymentContentIfMissingAsync(
                order.Id,
                paymentContent,
                cancellationToken);

            var result = await _vietQrService.GeneratePaymentQrAsync(
                request.OrderId.Trim(),
                amount,
                paymentContent,
                cancellationToken);

            _logger.LogInformation(
                "Generated payment QR for order {OrderId}. Amount={Amount}, PaymentContent={PaymentContent}",
                order.Id,
                amount,
                paymentContent);

            return Ok(new
            {
                orderId = result.OrderId,
                amount = result.Amount,
                paymentContent = result.PaymentContent,
                qrUrl = result.QrImageUrl,
                qrCode = result.QrCode,
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
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Could not generate payment QR for order {OrderId}.", request.OrderId);
            return StatusCode(StatusCodes.Status502BadGateway, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while generating payment QR for order {OrderId}.", request.OrderId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Could not generate payment QR." });
        }
    }

    [HttpPost("cancel-pending")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> CancelPendingPayment(
        [FromBody] CancelPendingPaymentRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            return BadRequest(new { message = "orderId is required." });
        }

        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var result = await CancelPendingPaymentAsync(
                userId,
                request,
                cancellationToken);

            await DeletePendingFixedBookingNotificationAsync(
                request.OrderId.Trim(),
                cancellationToken);

            return Ok(new
            {
                orderId = result.OrderId,
                bookingIds = result.BookingIds,
                cancelled = result.Cancelled,
                status = result.Status,
                refundedWalletAmount = result.RefundedWalletAmount,
                refundedPoints = result.RefundedPoints,
            });
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not cancel pending payment for order {OrderId}.", request.OrderId);
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Could not cancel pending payment." });
        }
    }

    [HttpPost("reconcile")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> ReconcilePayment(
        [FromBody] ReconcilePaymentRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            return BadRequest(new { message = "orderId is required." });
        }

        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var order = await _orderRepository.GetOrderForUserAsync(
                request.OrderId.Trim(),
                userId,
                cancellationToken);

            if (string.Equals(order.Status, OrderStatuses.Confirmed, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(order.Status, OrderStatuses.Completed, StringComparison.OrdinalIgnoreCase))
            {
                return Ok(new
                {
                    orderId = order.Id,
                    isPaid = true,
                    status = order.Status,
                    message = "Order is already processed.",
                });
            }

            if (!string.Equals(order.Status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                return Ok(new
                {
                    orderId = order.Id,
                    isPaid = false,
                    status = order.Status,
                    message = $"Order cannot be reconciled because its current status is '{order.Status}'.",
                });
            }

            var requiredAmount = NormalizeMoney(order.TotalPrice);
            if (requiredAmount <= 0)
            {
                return BadRequest(new { message = "Order totalPrice must be greater than zero." });
            }

            var paymentContent = string.IsNullOrWhiteSpace(order.PaymentContent)
                ? PaymentReference.BuildPaymentContent(_configuration, order.Id)
                : order.PaymentContent.Trim().ToUpperInvariant();

            await _orderRepository.SetPaymentContentIfMissingAsync(
                order.Id,
                paymentContent,
                cancellationToken);

            var lookupResult = await _sePayTransactionLookupService.FindIncomingPaymentAsync(
                paymentContent,
                decimal.ToDouble(requiredAmount),
                cancellationToken);

            if (!lookupResult.IsConfigured)
            {
                return Ok(new
                {
                    orderId = order.Id,
                    isPaid = false,
                    pollingConfigured = false,
                    paymentContent,
                    message = lookupResult.Message,
                });
            }

            if (!lookupResult.IsFound || lookupResult.Payment is null)
            {
                return Ok(new
                {
                    orderId = order.Id,
                    isPaid = false,
                    pollingConfigured = true,
                    paymentContent,
                    message = lookupResult.Message,
                });
            }

            var result = await _orderRepository.ProcessPaidWebhookAsync(
                new OrderPaymentWriteRequest(
                    order.Id,
                    lookupResult.Payment.Amount,
                    "sepay-api",
                    lookupResult.Payment.TransactionId,
                    null),
                cancellationToken);

            _logger.LogInformation(
                "Reconciled SePay transaction {TransactionId} for order {OrderId}. Action={Action}",
                lookupResult.Payment.TransactionId,
                order.Id,
                result.Action);

            if (result.Action is OrderPaymentWriteAction.Confirmed or OrderPaymentWriteAction.AlreadyProcessed)
            {
                await NotifyFixedBookingConfirmedAsync(order.Id, cancellationToken);
            }

            return Ok(new
            {
                orderId = order.Id,
                isPaid = result.Action is OrderPaymentWriteAction.Confirmed or OrderPaymentWriteAction.AlreadyProcessed,
                pollingConfigured = true,
                action = result.Action.ToString(),
                transactionId = lookupResult.Payment.TransactionId,
                message = result.Message,
            });
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InsufficientPaymentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Could not reconcile SePay payment for order {OrderId}.", request.OrderId);
            return StatusCode(StatusCodes.Status502BadGateway, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while reconciling SePay payment for order {OrderId}.", request.OrderId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Could not reconcile payment." });
        }
    }

    [HttpPost("confirm-local")]
    [Authorize(AuthenticationSchemes = FirebaseAuthenticationHandler.SchemeName)]
    public async Task<IActionResult> ConfirmLocalPayment(
        [FromBody] ConfirmLocalPaymentRequest request,
        CancellationToken cancellationToken)
    {
        if (!_environment.IsDevelopment())
        {
            return NotFound();
        }

        if (request is null)
        {
            return BadRequest(new { message = "Request body is required." });
        }

        if (string.IsNullOrWhiteSpace(request.OrderId))
        {
            return BadRequest(new { message = "orderId is required." });
        }

        try
        {
            var userId = User.GetFirebaseUserId();
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized(new { message = "Authenticated Firebase user id is required." });
            }

            var order = await _orderRepository.GetOrderForUserAsync(
                request.OrderId.Trim(),
                userId,
                cancellationToken);

            if (string.Equals(order.Status, OrderStatuses.Confirmed, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(order.Status, OrderStatuses.Completed, StringComparison.OrdinalIgnoreCase))
            {
                return Ok(new
                {
                    orderId = request.OrderId.Trim(),
                    status = order.Status,
                    message = "Order is already processed.",
                });
            }

            if (!string.Equals(order.Status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new
                {
                    message = $"Order cannot be confirmed because its current status is '{order.Status}'.",
                });
            }

            var amount = NormalizeMoney(order.TotalPrice);
            if (amount <= 0)
            {
                return BadRequest(new { message = "Order totalPrice must be greater than zero." });
            }

            var result = await _orderRepository.ProcessPaidWebhookAsync(
                new OrderPaymentWriteRequest(
                    request.OrderId.Trim(),
                    decimal.ToDouble(amount),
                    "local-dev-confirmation",
                    string.IsNullOrWhiteSpace(request.TransactionId)
                        ? $"local-{Guid.NewGuid():N}"
                        : request.TransactionId.Trim(),
                    null),
                cancellationToken);

            if (result.Action is OrderPaymentWriteAction.Confirmed or OrderPaymentWriteAction.AlreadyProcessed)
            {
                await NotifyFixedBookingConfirmedAsync(
                    request.OrderId.Trim(),
                    cancellationToken);
            }

            return Ok(new
            {
                orderId = request.OrderId.Trim(),
                action = result.Action.ToString(),
                message = result.Message,
            });
        }
        catch (OrderNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (OrderForbiddenException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InsufficientPaymentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not confirm local payment for order {OrderId}.", request.OrderId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Could not confirm local payment." });
        }
    }

    private static decimal NormalizeMoney(double value)
    {
        return decimal.Round(Convert.ToDecimal(value), 0, MidpointRounding.AwayFromZero);
    }

    private async Task<ApplyPaymentBenefitsResult> ApplyPaymentBenefitsAsync(
        string userId,
        ApplyPaymentBenefitsRequest request,
        CancellationToken cancellationToken)
    {
        var trimmedUserId = userId.Trim();
        var trimmedOrderId = request.OrderId.Trim();
        var userRef = _firestoreDb.Collection("users").Document(trimmedUserId);
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);
        ApplyPaymentBenefitsResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var userSnapshot = await transaction.GetSnapshotAsync(userRef, cancellationToken);
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(trimmedOrderId);
            }

            if (!string.Equals(GetString(orderSnapshot, "userId"), trimmedUserId, StringComparison.Ordinal))
            {
                throw new OrderForbiddenException(trimmedOrderId);
            }

            if (!userSnapshot.Exists)
            {
                throw new InvalidOperationException("User wallet was not found.");
            }

            var status = GetString(orderSnapshot, "status");
            var originalTotal = NormalizeMoneyToDouble(
                GetDouble(orderSnapshot, "originalTotalPrice") > 0
                    ? GetDouble(orderSnapshot, "originalTotalPrice")
                    : GetDouble(orderSnapshot, "totalPrice"));
            if (originalTotal <= 0)
            {
                originalTotal = NormalizeMoneyToDouble(request.OriginalAmount);
            }

            if (!string.Equals(status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                var currentRemaining = NormalizeMoneyToDouble(GetDouble(orderSnapshot, "totalPrice"));
                result = new ApplyPaymentBenefitsResult(
                    originalTotal,
                    currentRemaining,
                    NormalizeMoneyToDouble(GetDouble(orderSnapshot, "appWalletDiscount")),
                    NormalizeMoneyToDouble(GetDouble(orderSnapshot, "appPointDiscount")),
                    GetInt(orderSnapshot, "appPointsSpent"),
                    IsPaidStatus(status, GetString(orderSnapshot, "paymentStatus")) || currentRemaining <= 0);
                return;
            }

            if (GetBool(orderSnapshot, "appBenefitsApplied"))
            {
                var currentRemaining = NormalizeMoneyToDouble(GetDouble(orderSnapshot, "totalPrice"));
                result = new ApplyPaymentBenefitsResult(
                    originalTotal,
                    currentRemaining,
                    NormalizeMoneyToDouble(GetDouble(orderSnapshot, "appWalletDiscount")),
                    NormalizeMoneyToDouble(GetDouble(orderSnapshot, "appPointDiscount")),
                    GetInt(orderSnapshot, "appPointsSpent"),
                    currentRemaining <= 0);
                return;
            }

            if (!request.UseWallet && !request.UsePoints)
            {
                var remainingWithoutBenefits = NormalizeMoneyToDouble(GetDouble(orderSnapshot, "totalPrice"));
                result = new ApplyPaymentBenefitsResult(
                    originalTotal,
                    remainingWithoutBenefits,
                    0,
                    0,
                    0,
                    false);
                return;
            }

            var walletBalance = NormalizeMoneyToDouble(GetDouble(userSnapshot, "walletBalance"));
            var pendingWithdrawal = Math.Max(0d, NormalizeMoneyToDouble(GetDouble(userSnapshot, "pendingWithdrawal")));
            var availableWallet = userSnapshot.ContainsField("availableBalance")
                ? NormalizeMoneyToDouble(GetDouble(userSnapshot, "availableBalance"))
                : walletBalance - pendingWithdrawal;
            availableWallet = Math.Max(0d, availableWallet);
            var availablePoints = GetInt(userSnapshot, "points");
            if (availablePoints <= 0)
            {
                availablePoints = GetInt(userSnapshot, "loyaltyPoints");
            }

            if (request.UsePoints && availablePoints < 100)
            {
                throw new InvalidOperationException("Ví điểm cần tối thiểu 100 điểm để sử dụng.");
            }

            var remaining = NormalizeMoneyToDouble(GetDouble(orderSnapshot, "totalPrice"));
            if (remaining <= 0)
            {
                remaining = originalTotal;
            }

            var walletDiscount = 0d;
            var pointDiscount = 0d;
            var pointsSpent = 0;

            if (request.UseWallet && remaining > 0)
            {
                walletDiscount = Math.Min(availableWallet, remaining);
                remaining -= walletDiscount;
            }

            if (request.UsePoints && remaining > 0)
            {
                var maxPointValue = availablePoints * 200d;
                pointDiscount = Math.Min(maxPointValue, remaining);
                pointsSpent = (int)Math.Ceiling(pointDiscount / 200d);
                pointDiscount = Math.Min(pointsSpent * 200d, remaining);
                remaining -= pointDiscount;
            }

            remaining = NormalizeMoneyToDouble(remaining);
            walletDiscount = NormalizeMoneyToDouble(walletDiscount);
            pointDiscount = NormalizeMoneyToDouble(pointDiscount);

            IReadOnlyList<DocumentSnapshot> bookingSnapshots = Array.Empty<DocumentSnapshot>();
            if (remaining <= 0)
            {
                bookingSnapshots = await GetOrderBookingSnapshotsAsync(
                    transaction,
                    orderSnapshot,
                    request.BookingIds,
                    cancellationToken);
            }

            var now = Timestamp.FromDateTime(DateTime.UtcNow);
            var orderUpdates = new Dictionary<string, object>
            {
                ["originalTotalPrice"] = originalTotal,
                ["totalPrice"] = remaining,
                ["totalAmount"] = remaining,
                ["appBenefitsApplied"] = true,
                ["appWalletDiscount"] = walletDiscount,
                ["appPointDiscount"] = pointDiscount,
                ["appPointsSpent"] = pointsSpent,
                ["appPaymentAppliedAt"] = now,
                ["updatedAt"] = now,
            };

            if (remaining <= 0)
            {
                orderUpdates["status"] = OrderStatuses.Confirmed;
                orderUpdates["orderStatus"] = OrderStatuses.Confirmed;
                orderUpdates["paymentStatus"] = "success";
                orderUpdates["paymentProvider"] = "app_wallet_points";
                orderUpdates["paidAmount"] = originalTotal;
                orderUpdates["paidAt"] = now;
                orderUpdates["confirmedAt"] = now;
            }

            transaction.Set(orderRef, orderUpdates, SetOptions.MergeAll);

            if (walletDiscount > 0)
            {
                var newWalletBalance = NormalizeMoneyToDouble(walletBalance - walletDiscount);
                var newAvailableBalance = NormalizeMoneyToDouble(availableWallet - walletDiscount);
                transaction.Set(userRef, new Dictionary<string, object>
                {
                    ["walletBalance"] = newWalletBalance,
                    ["availableBalance"] = newAvailableBalance,
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);

                var walletTransactionRef = _firestoreDb
                    .Collection("walletTransactions")
                    .Document($"payment_{SanitizeDocumentId(trimmedOrderId)}_wallet");
                transaction.Set(walletTransactionRef, new WalletTransactionDocument
                {
                    UserId = trimmedUserId,
                    Amount = -walletDiscount,
                    Type = "payment",
                    Status = WalletTransactionStatuses.Completed,
                    Description = "Thanh toán đơn đặt sân bằng ví",
                    SourceOrderId = trimmedOrderId,
                    Provider = "app_wallet",
                    CreatedAt = now,
                }, SetOptions.MergeAll);
            }

            if (pointsSpent > 0)
            {
                var nextPoints = Math.Max(0, availablePoints - pointsSpent);
                transaction.Set(userRef, new Dictionary<string, object>
                {
                    ["points"] = nextPoints,
                    ["loyaltyPoints"] = nextPoints,
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            if (remaining <= 0)
            {
                foreach (var bookingSnapshot in bookingSnapshots.Where(snapshot => snapshot.Exists))
                {
                    transaction.Set(bookingSnapshot.Reference, new Dictionary<string, object>
                    {
                        ["status"] = BookingStatuses.Confirmed,
                        ["orderStatus"] = OrderStatuses.Confirmed,
                        ["paymentStatus"] = "success",
                        ["paidAt"] = now,
                        ["confirmedAt"] = now,
                        ["updatedAt"] = now,
                    }, SetOptions.MergeAll);
                }

                SetBookingSlotLockStatus(transaction, bookingSnapshots, BookingStatuses.Confirmed, now);
            }

            result = new ApplyPaymentBenefitsResult(
                originalTotal,
                remaining,
                walletDiscount,
                pointDiscount,
                pointsSpent,
                remaining <= 0);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not apply payment benefits.");
    }

    private async Task<CancelPendingPaymentResult> CancelPendingPaymentAsync(
        string userId,
        CancelPendingPaymentRequest request,
        CancellationToken cancellationToken)
    {
        var trimmedUserId = userId.Trim();
        var trimmedOrderId = request.OrderId.Trim();
        var userRef = _firestoreDb.Collection("users").Document(trimmedUserId);
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);
        CancelPendingPaymentResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(trimmedOrderId);
            }

            if (!string.Equals(GetString(orderSnapshot, "userId"), trimmedUserId, StringComparison.Ordinal))
            {
                throw new OrderForbiddenException(trimmedOrderId);
            }

            var bookingSnapshots = await GetOrderBookingSnapshotsAsync(
                transaction,
                orderSnapshot,
                request.BookingIds,
                cancellationToken);
            var bookingIds = bookingSnapshots
                .Where(snapshot => snapshot.Exists)
                .Select(snapshot => snapshot.Reference.Id)
                .ToArray();

            var status = GetString(orderSnapshot, "status");
            if (string.Equals(status, OrderStatuses.Cancelled, StringComparison.OrdinalIgnoreCase))
            {
                var now = Timestamp.FromDateTime(DateTime.UtcNow);
                MarkBookingsCancelled(transaction, bookingSnapshots, "cancelled", now);
                DeleteBookingSlotLocks(transaction, bookingSnapshots);
                result = new CancelPendingPaymentResult(
                    trimmedOrderId,
                    bookingIds,
                    false,
                    OrderStatuses.Cancelled,
                    0,
                    0);
                return;
            }

            if (!string.Equals(status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase))
            {
                result = new CancelPendingPaymentResult(
                    trimmedOrderId,
                    bookingIds,
                    false,
                    status,
                    0,
                    0);
                return;
            }

            var walletDiscount = NormalizeMoneyToDouble(GetDouble(orderSnapshot, "appWalletDiscount"));
            var pointsSpent = GetInt(orderSnapshot, "appPointsSpent");
            var shouldRefundBenefits =
                (walletDiscount > 0 || pointsSpent > 0)
                && !GetBool(orderSnapshot, "appBenefitsRefunded");
            var userSnapshot = shouldRefundBenefits
                ? await transaction.GetSnapshotAsync(userRef, cancellationToken)
                : null;
            var canRefundBenefits = shouldRefundBenefits && userSnapshot?.Exists == true;
            var nowUtc = DateTime.UtcNow;
            var cancelledAt = Timestamp.FromDateTime(nowUtc);

            await _cancellationPolicyService.ApplyCancellationAsync(
                transaction,
                new CancellationPolicyRequest(
                    trimmedUserId,
                    bookingSnapshots,
                    nowUtc,
                    cancelledAt),
                cancellationToken);

            transaction.Set(orderRef, new Dictionary<string, object>
            {
                ["status"] = OrderStatuses.Cancelled,
                ["orderStatus"] = OrderStatuses.Cancelled,
                ["paymentStatus"] = "cancelled",
                ["cancelledReason"] = "user_cancelled",
                ["cancelledAt"] = cancelledAt,
                ["updatedAt"] = cancelledAt,
                ["appBenefitsRefunded"] = canRefundBenefits,
            }, SetOptions.MergeAll);

            MarkBookingsCancelled(transaction, bookingSnapshots, "cancelled", cancelledAt);
            DeleteBookingSlotLocks(transaction, bookingSnapshots);

            var refundedWalletAmount = 0d;
            var refundedPoints = 0;
            if (canRefundBenefits)
            {
                var refundUserSnapshot = userSnapshot!;
                if (walletDiscount > 0)
                {
                    var walletBalance = NormalizeMoneyToDouble(GetDouble(refundUserSnapshot, "walletBalance"));
                    var pendingWithdrawal = Math.Max(0d, NormalizeMoneyToDouble(GetDouble(refundUserSnapshot, "pendingWithdrawal")));
                    var newWalletBalance = NormalizeMoneyToDouble(walletBalance + walletDiscount);
                    transaction.Set(userRef, new Dictionary<string, object>
                    {
                        ["walletBalance"] = newWalletBalance,
                        ["availableBalance"] = NormalizeMoneyToDouble(newWalletBalance - pendingWithdrawal),
                        ["updatedAt"] = cancelledAt,
                    }, SetOptions.MergeAll);

                    var walletTransactionRef = _firestoreDb
                        .Collection("walletTransactions")
                        .Document($"refund_{SanitizeDocumentId(trimmedOrderId)}_app_benefits");
                    transaction.Set(walletTransactionRef, new WalletTransactionDocument
                    {
                        UserId = trimmedUserId,
                        Amount = walletDiscount,
                        Type = "refund",
                        Status = WalletTransactionStatuses.Completed,
                        Description = "Hoàn ví do hủy đơn chưa thanh toán",
                        SourceOrderId = trimmedOrderId,
                        Provider = "app_wallet",
                        CreatedAt = cancelledAt,
                    }, SetOptions.MergeAll);

                    refundedWalletAmount = walletDiscount;
                }

                if (pointsSpent > 0)
                {
                    var currentPoints = GetInt(refundUserSnapshot, "points");
                    if (currentPoints <= 0)
                    {
                        currentPoints = GetInt(refundUserSnapshot, "loyaltyPoints");
                    }

                    var nextPoints = currentPoints + pointsSpent;
                    transaction.Set(userRef, new Dictionary<string, object>
                    {
                        ["points"] = nextPoints,
                        ["loyaltyPoints"] = nextPoints,
                        ["updatedAt"] = cancelledAt,
                    }, SetOptions.MergeAll);

                    refundedPoints = pointsSpent;
                }
            }

            result = new CancelPendingPaymentResult(
                trimmedOrderId,
                bookingIds,
                true,
                OrderStatuses.Cancelled,
                refundedWalletAmount,
                refundedPoints);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not cancel pending payment.");
    }

    private async Task<IReadOnlyList<DocumentSnapshot>> GetOrderBookingSnapshotsAsync(
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
                snapshots.Add(await transaction.GetSnapshotAsync(
                    _firestoreDb.Collection("bookings").Document(bookingId),
                    cancellationToken));
            }

            return snapshots;
        }

        var querySnapshot = await transaction.GetSnapshotAsync(
            _firestoreDb.Collection("bookings").WhereEqualTo("orderId", orderSnapshot.Reference.Id),
            cancellationToken);
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

    private async Task NotifyFixedBookingConfirmedAsync(
        string orderId,
        CancellationToken cancellationToken)
    {
        try
        {
            await _bookingNotificationService.NotifyFixedBookingConfirmedAsync(
                orderId,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Confirmed payment for order {OrderId}, but could not write fixed booking notification.",
                orderId);
        }
    }

    private async Task DeletePendingFixedBookingNotificationAsync(
        string orderId,
        CancellationToken cancellationToken)
    {
        try
        {
            await _bookingNotificationService.DeletePendingFixedBookingNotificationAsync(
                orderId,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Could not delete pending fixed booking notification for order {OrderId}.",
                orderId);
        }
    }

    private static void MarkBookingsCancelled(
        Transaction transaction,
        IEnumerable<DocumentSnapshot> bookingSnapshots,
        string paymentStatus,
        Timestamp now)
    {
        foreach (var bookingSnapshot in bookingSnapshots.Where(snapshot => snapshot.Exists))
        {
            transaction.Set(bookingSnapshot.Reference, new Dictionary<string, object>
            {
                ["status"] = BookingStatuses.Cancelled,
                ["orderStatus"] = OrderStatuses.Cancelled,
                ["paymentStatus"] = paymentStatus,
                ["cancelledReason"] = "user_cancelled",
                ["cancelledAt"] = now,
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
                    .Document(BuildSlotLockId(booking.CourtId, DateOnly.FromDateTime(booking.Date.ToDateTime()), slotStart))))
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

    private static bool IsPaidStatus(string status, string paymentStatus)
    {
        return string.Equals(status, OrderStatuses.Confirmed, StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, OrderStatuses.Completed, StringComparison.OrdinalIgnoreCase)
            || string.Equals(paymentStatus, "success", StringComparison.OrdinalIgnoreCase)
            || string.Equals(paymentStatus, "paid", StringComparison.OrdinalIgnoreCase);
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

    private static double NormalizeMoneyToDouble(double value)
    {
        return Math.Round(value, 0, MidpointRounding.AwayFromZero);
    }

    public sealed record GenerateQrRequest(string OrderId);

    public sealed record ApplyPaymentBenefitsRequest(
        string OrderId,
        double OriginalAmount,
        bool UseWallet,
        bool UsePoints,
        IReadOnlyList<string>? BookingIds);

    public sealed record ApplyPaymentBenefitsResult(
        double OriginalAmount,
        double PayableAmount,
        double WalletDiscount,
        double PointDiscount,
        int PointsSpent,
        bool IsFullyPaid);

    public sealed record CancelPendingPaymentRequest(
        string OrderId,
        IReadOnlyList<string>? BookingIds);

    private sealed record CancelPendingPaymentResult(
        string OrderId,
        IReadOnlyList<string> BookingIds,
        bool Cancelled,
        string Status,
        double RefundedWalletAmount,
        int RefundedPoints);

    public sealed record ReconcilePaymentRequest(string OrderId);

    public sealed record ConfirmLocalPaymentRequest(
        string OrderId,
        string? TransactionId);
}
