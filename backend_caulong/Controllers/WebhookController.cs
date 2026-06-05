using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using backend_caulong.Models;
using backend_caulong.Repositories;
using backend_caulong.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend_caulong.Controllers;

[ApiController]
[Route("api/webhook")]
public sealed class WebhookController : ControllerBase
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IOrderRepository _orderRepository;
    private readonly IWalletService _walletService;
    private readonly IFinancialNotificationService _financialNotificationService;
    private readonly IBookingNotificationService _bookingNotificationService;
    private readonly IConfiguration _configuration;
    private readonly ILogger<WebhookController> _logger;

    public WebhookController(
        IOrderRepository orderRepository,
        IWalletService walletService,
        IFinancialNotificationService financialNotificationService,
        IBookingNotificationService bookingNotificationService,
        IConfiguration configuration,
        ILogger<WebhookController> logger)
    {
        _orderRepository = orderRepository;
        _walletService = walletService;
        _financialNotificationService = financialNotificationService;
        _bookingNotificationService = bookingNotificationService;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost("payment")]
    [HttpPost("/api/webhooks/payment-received")]
    public async Task<IActionResult> ReceivePaymentWebhook(CancellationToken cancellationToken)
    {
        Request.EnableBuffering();

        string rawBody;
        using (var reader = new StreamReader(
                   Request.Body,
                   Encoding.UTF8,
                   detectEncodingFromByteOrderMarks: false,
                   bufferSize: 1024,
                   leaveOpen: true))
        {
            rawBody = await reader.ReadToEndAsync(cancellationToken);
            Request.Body.Position = 0;
        }

        if (!IsValidSignature(rawBody))
        {
            _logger.LogWarning("Rejected payment webhook because signature verification failed.");
            return Unauthorized(new { message = "Invalid webhook signature." });
        }

        PaymentWebhookPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<PaymentWebhookPayload>(rawBody, JsonOptions);
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Rejected payment webhook because payload is invalid JSON.");
            return BadRequest(new { message = "Invalid JSON payload." });
        }

        if (payload is null || string.IsNullOrWhiteSpace(payload.OrderId))
        {
            return BadRequest(new { message = "orderId is required." });
        }

        if (!IsPaidPayload(payload))
        {
            return Ok(new { message = "Webhook received but no paid status update was required." });
        }

        OrderPaymentWriteResult result;
        try
        {
            result = await _orderRepository.ProcessPaidWebhookAsync(
                new OrderPaymentWriteRequest(
                    payload.OrderId,
                    payload.Amount,
                    payload.Provider,
                    payload.TransactionId,
                    payload.BookingIds),
                cancellationToken);
        }
        catch (OrderNotFoundException ex)
        {
            _logger.LogWarning(ex, "Payment webhook referenced an unknown order.");
            return NotFound(new { message = ex.Message });
        }
        catch (InsufficientPaymentException)
        {
            return BadRequest("Thiếu tiền");
        }

        if (result.Action == OrderPaymentWriteAction.RefundToWallet)
        {
            await RefundLatePaymentAndNotifyAsync(
                result.UserId,
                payload.OrderId,
                result.RefundAmount,
                payload.TransactionId,
                payload.Provider,
                cancellationToken);
        }
        else if (result.Action is OrderPaymentWriteAction.Confirmed or OrderPaymentWriteAction.AlreadyProcessed)
        {
            await NotifyFixedBookingConfirmedAsync(payload.OrderId, cancellationToken);
        }

        return Ok(new
        {
            message = result.Message,
            orderId = payload.OrderId,
            action = result.Action.ToString(),
        });
    }

    [HttpPost("sepay")]
    [HttpPost("sepay/payment")]
    public async Task<IActionResult> ReceiveSePayWebhook(CancellationToken cancellationToken)
    {
        Request.EnableBuffering();

        string rawBody;
        using (var reader = new StreamReader(
                   Request.Body,
                   Encoding.UTF8,
                   detectEncodingFromByteOrderMarks: false,
                   bufferSize: 1024,
                   leaveOpen: true))
        {
            rawBody = await reader.ReadToEndAsync(cancellationToken);
            Request.Body.Position = 0;
        }

        _logger.LogInformation(
            "Received SePay webhook request. HasHmacSignature={HasHmacSignature}, HasAuthorization={HasAuthorization}, BodyLength={BodyLength}",
            Request.Headers.ContainsKey("X-SePay-Signature"),
            Request.Headers.ContainsKey("Authorization"),
            rawBody.Length);

        if (!IsValidSePayRequest(rawBody))
        {
            _logger.LogWarning("Rejected SePay webhook because authentication verification failed.");
            return Unauthorized(new { success = false, message = "Invalid webhook authentication." });
        }

        SePayWebhookPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<SePayWebhookPayload>(rawBody, JsonOptions);
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Rejected SePay webhook because payload is invalid JSON.");
            return BadRequest(new { success = false, message = "Invalid JSON payload." });
        }

        if (payload is null)
        {
            return BadRequest(new { success = false, message = "Request body is required." });
        }

        if (!string.Equals(payload.TransferType, "in", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation(
                "Ignored SePay webhook {SePayTransactionId} because transferType is {TransferType}.",
                payload.Id,
                payload.TransferType);
            return SePaySuccess();
        }

        _logger.LogInformation(
            "Received SePay incoming payment webhook {SePayTransactionId}. Account={AccountNumber}, Amount={Amount}, Code={Code}, Content={Content}",
            payload.Id,
            payload.AccountNumber,
            payload.TransferAmount,
            payload.Code,
            payload.Content);

        if (!IsExpectedSePayAccount(payload))
        {
            _logger.LogWarning(
                "Ignored SePay webhook {SePayTransactionId} for unexpected account {AccountNumber}.",
                payload.Id,
                payload.AccountNumber);

            return SePaySuccess();
        }

        var paymentContent = PaymentReference.ResolvePaymentContent(
            _configuration,
            payload.Code,
            payload.Content,
            payload.Description);

        if (string.IsNullOrWhiteSpace(paymentContent))
        {
            _logger.LogWarning(
                "Ignored SePay webhook {SePayTransactionId} because no payment content was found in content '{Content}'.",
                payload.Id,
                payload.Content);

            return SePaySuccess();
        }

        try
        {
            var order = await _orderRepository.GetOrderByPaymentContentAsync(paymentContent, cancellationToken);
            var orderId = order.Id;
            var result = await _orderRepository.ProcessPaidWebhookAsync(
                new OrderPaymentWriteRequest(
                    orderId,
                    payload.TransferAmount,
                    "sepay",
                    BuildSePayTransactionId(payload),
                    null),
                cancellationToken);

            if (result.Action == OrderPaymentWriteAction.RefundToWallet)
            {
                await RefundLatePaymentAndNotifyAsync(
                    result.UserId,
                    orderId,
                    result.RefundAmount,
                    BuildSePayTransactionId(payload),
                    "sepay",
                    cancellationToken);
            }
            else if (result.Action is OrderPaymentWriteAction.Confirmed or OrderPaymentWriteAction.AlreadyProcessed)
            {
                await NotifyFixedBookingConfirmedAsync(orderId, cancellationToken);
            }

            _logger.LogInformation(
                "Processed SePay webhook {SePayTransactionId} for order {OrderId}. Action={Action}",
                payload.Id,
                orderId,
                result.Action);

            return SePaySuccess();
        }
        catch (OrderNotFoundException ex)
        {
            _logger.LogWarning(
                ex,
                "SePay webhook referenced an unknown payment content {PaymentContent}.",
                paymentContent);
            return SePaySuccess();
        }
        catch (InsufficientPaymentException ex)
        {
            _logger.LogWarning(
                ex,
                "SePay webhook payment was insufficient for payment content {PaymentContent}.",
                paymentContent);
            return SePaySuccess();
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error while processing SePay webhook {SePayTransactionId}.",
                payload.Id);

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { success = false, message = "Could not process SePay webhook." });
        }
    }

    private bool IsValidSignature(string rawBody)
    {
        var secret = _configuration["Webhook:Secret"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            _logger.LogError("Webhook:Secret is not configured.");
            return false;
        }

        var signatureHeader = _configuration["Webhook:SignatureHeader"] ?? "X-Webhook-Signature";
        var timestampHeader = _configuration["Webhook:TimestampHeader"] ?? "X-Webhook-Timestamp";
        var providedSignature = Request.Headers[signatureHeader].FirstOrDefault();

        if (string.IsNullOrWhiteSpace(providedSignature))
        {
            return false;
        }

        var timestamp = Request.Headers[timestampHeader].FirstOrDefault();
        if (!IsTimestampAllowed(timestamp))
        {
            return false;
        }

        var signedPayload = string.IsNullOrWhiteSpace(timestamp)
            ? rawBody
            : $"{timestamp}.{rawBody}";

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var computedHash = hmac.ComputeHash(Encoding.UTF8.GetBytes(signedPayload));

        return FixedTimeEquals(providedSignature, Convert.ToHexString(computedHash), caseInsensitive: true)
            || FixedTimeEquals(providedSignature, Convert.ToBase64String(computedHash), caseInsensitive: false);
    }

    private async Task RefundLatePaymentAndNotifyAsync(
        string userId,
        string orderId,
        double refundAmount,
        string? providerTransactionId,
        string? provider,
        CancellationToken cancellationToken)
    {
        var refundResult = await _walletService.RefundToWalletAsync(
            userId,
            refundAmount,
            new WalletRefundMetadata(
                SourceOrderId: orderId,
                ProviderTransactionId: providerTransactionId,
                Provider: provider,
                Description: "Hoàn tiền do hủy sân",
                IdempotencyKey: BuildLatePaymentRefundIdempotencyKey(orderId)),
            cancellationToken);

        if (!refundResult.Applied)
        {
            _logger.LogInformation(
                "Skipped duplicate late payment refund for order {OrderId}. WalletTransactionId={TransactionId}",
                orderId,
                refundResult.TransactionId);
            return;
        }

        try
        {
            await _financialNotificationService.NotifyExpiredOrderRefundedAsync(
                userId,
                orderId,
                refundAmount,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Refunded late payment for order {OrderId}, but could not send refund notification.",
                orderId);
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

    private bool IsValidSePayRequest(string rawBody)
    {
        if (Request.Headers.ContainsKey("X-SePay-Signature"))
        {
            return IsValidSePaySignature(rawBody);
        }

        if (IsValidSePayApiKey())
        {
            return true;
        }

        if (_configuration.GetValue("SePay:AllowUnsignedWebhooks", false))
        {
            _logger.LogWarning(
                "Accepted unsigned SePay webhook because SePay:AllowUnsignedWebhooks is enabled. Use this only for local testing.");
            return true;
        }

        return false;
    }

    private bool IsValidSePaySignature(string rawBody)
    {
        var secret = _configuration["SePay:WebhookSecret"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            secret = _configuration["Webhook:Secret"];
        }

        if (string.IsNullOrWhiteSpace(secret))
        {
            _logger.LogError("SePay:WebhookSecret is not configured.");
            return false;
        }

        var signature = Request.Headers["X-SePay-Signature"].FirstOrDefault();
        var timestamp = Request.Headers["X-SePay-Timestamp"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(signature) || !IsTimestampAllowed(timestamp))
        {
            return false;
        }

        var signedPayload = $"{timestamp}.{rawBody}";
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var computedHash = hmac.ComputeHash(Encoding.UTF8.GetBytes(signedPayload));

        return FixedTimeEquals(signature, $"sha256={Convert.ToHexString(computedHash)}", caseInsensitive: true)
            || FixedTimeEquals(signature, Convert.ToHexString(computedHash), caseInsensitive: true);
    }

    private bool IsValidSePayApiKey()
    {
        var expectedApiKey = _configuration["SePay:WebhookApiKey"];
        if (string.IsNullOrWhiteSpace(expectedApiKey))
        {
            expectedApiKey = _configuration["SePay:ApiKey"];
        }

        if (string.IsNullOrWhiteSpace(expectedApiKey))
        {
            return false;
        }

        var authorization = Request.Headers.Authorization.FirstOrDefault();
        if (string.IsNullOrWhiteSpace(authorization))
        {
            return false;
        }

        const string apiKeyPrefix = "Apikey ";
        if (!authorization.StartsWith(apiKeyPrefix, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var providedApiKey = authorization[apiKeyPrefix.Length..].Trim();
        return FixedTimeEquals(providedApiKey, expectedApiKey, caseInsensitive: false);
    }

    private bool IsExpectedSePayAccount(SePayWebhookPayload payload)
    {
        var expectedAccountNumber = _configuration["SePay:AccountNumber"];
        return string.IsNullOrWhiteSpace(expectedAccountNumber)
            || string.Equals(
                payload.AccountNumber?.Trim(),
                expectedAccountNumber.Trim(),
                StringComparison.Ordinal);
    }

    private static string BuildSePayTransactionId(SePayWebhookPayload payload)
    {
        if (payload.Id > 0)
        {
            return $"sepay-{payload.Id}";
        }

        if (!string.IsNullOrWhiteSpace(payload.ReferenceCode))
        {
            return $"sepay-{payload.ReferenceCode.Trim()}";
        }

        return $"sepay-{Guid.NewGuid():N}";
    }

    private static string BuildLatePaymentRefundIdempotencyKey(string orderId)
    {
        return $"late-payment-refund:{orderId.Trim()}";
    }

    private static IActionResult SePaySuccess()
    {
        return new OkObjectResult(new { success = true });
    }

    private bool IsTimestampAllowed(string? timestamp)
    {
        if (string.IsNullOrWhiteSpace(timestamp))
        {
            return true;
        }

        if (!long.TryParse(timestamp, out var unixSeconds))
        {
            return false;
        }

        var toleranceSeconds = _configuration.GetValue("Webhook:ToleranceSeconds", 300);
        var eventTime = DateTimeOffset.FromUnixTimeSeconds(unixSeconds);
        var age = DateTimeOffset.UtcNow - eventTime;

        return Math.Abs(age.TotalSeconds) <= toleranceSeconds;
    }

    private static bool FixedTimeEquals(
        string providedSignature,
        string expectedSignature,
        bool caseInsensitive)
    {
        var normalizedProvided = NormalizeSignature(providedSignature);
        var normalizedExpected = NormalizeSignature(expectedSignature);

        if (caseInsensitive)
        {
            normalizedProvided = normalizedProvided.ToUpperInvariant();
            normalizedExpected = normalizedExpected.ToUpperInvariant();
        }

        var providedBytes = Encoding.UTF8.GetBytes(normalizedProvided);
        var expectedBytes = Encoding.UTF8.GetBytes(normalizedExpected);

        return providedBytes.Length == expectedBytes.Length
            && CryptographicOperations.FixedTimeEquals(providedBytes, expectedBytes);
    }

    private static string NormalizeSignature(string signature)
    {
        return signature
            .Trim()
            .Replace("sha256=", string.Empty, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsPaidPayload(PaymentWebhookPayload payload)
    {
        return string.Equals(payload.Status, "paid", StringComparison.OrdinalIgnoreCase)
            || string.Equals(payload.Status, "success", StringComparison.OrdinalIgnoreCase)
            || payload.Paid;
    }

    private sealed record PaymentWebhookPayload(
        string OrderId,
        double Amount,
        string? Status,
        bool Paid,
        string? TransactionId,
        string? Provider,
        IReadOnlyList<string>? BookingIds);

    private sealed record SePayWebhookPayload(
        long Id,
        string? Gateway,
        string? TransactionDate,
        string? AccountNumber,
        string? SubAccount,
        string? Code,
        string Content,
        string TransferType,
        string? Description,
        double TransferAmount,
        double Accumulated,
        string? ReferenceCode);
}
