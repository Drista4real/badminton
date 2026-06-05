using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace backend_caulong.Services;

public interface IVietQrService
{
    Task<VietQrResult> GeneratePaymentQrAsync(
        string orderId,
        decimal amount,
        string? paymentContent = null,
        CancellationToken cancellationToken = default);
}

public sealed class VietQrService : IVietQrService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<VietQrService> _logger;

    public VietQrService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<VietQrService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<VietQrResult> GeneratePaymentQrAsync(
        string orderId,
        decimal amount,
        string? paymentContent = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order id is required.", nameof(orderId));
        }

        var normalizedAmount = decimal.Round(amount, 0, MidpointRounding.AwayFromZero);
        if (normalizedAmount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be greater than zero.");
        }

        var endpoint = _configuration["VietQr:Endpoint"] ?? "https://api.vietqr.io/v2/generate";
        var clientId = GetRequiredSetting("VietQr:ClientId");
        var apiKey = GetRequiredSetting("VietQr:ApiKey");
        var bankBin = GetRequiredSetting("VietQr:BankBin");
        var accountNo = GetRequiredSetting("VietQr:AccountNo");
        var accountName = NormalizeAccountName(GetRequiredSetting("VietQr:AccountName"));
        var template = _configuration["VietQr:Template"] ?? "compact2";

        var paymentReference = string.IsNullOrWhiteSpace(paymentContent)
            ? PaymentReference.BuildPaymentContent(_configuration, orderId)
            : paymentContent.Trim().ToUpperInvariant();
        var transferContent = PaymentReference.BuildTransferContent(_configuration, paymentReference);
        var requestPayload = new VietQrGenerateRequest(
            AccountNo: accountNo,
            AccountName: accountName,
            AcqId: bankBin,
            Amount: decimal.ToInt64(normalizedAmount),
            AddInfo: transferContent,
            Format: "text",
            Template: template);

        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
        {
            Content = new StringContent(
                JsonSerializer.Serialize(requestPayload, JsonOptions),
                Encoding.UTF8,
                "application/json")
        };

        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.TryAddWithoutValidation("x-client-id", clientId);
        request.Headers.TryAddWithoutValidation("x-api-key", apiKey);

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var rawResponse = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "VietQR provider rejected order {OrderId}. StatusCode={StatusCode}, Body={Body}",
                orderId,
                (int)response.StatusCode,
                rawResponse);

            throw new InvalidOperationException("VietQR provider returned an unsuccessful response.");
        }

        var providerResponse = JsonSerializer.Deserialize<VietQrGenerateResponse>(rawResponse, JsonOptions)
            ?? throw new InvalidOperationException("VietQR provider returned an empty response.");

        if (!string.Equals(providerResponse.Code, "00", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning(
                "VietQR provider failed for order {OrderId}. Code={Code}, Description={Description}",
                orderId,
                providerResponse.Code,
                providerResponse.Desc);

            throw new InvalidOperationException(providerResponse.Desc ?? "VietQR provider failed to generate QR.");
        }

        var qrImageUrl = providerResponse.Data?.QrDataUrl;
        if (string.IsNullOrWhiteSpace(qrImageUrl))
        {
            throw new InvalidOperationException("VietQR provider did not return a QR image URL.");
        }

        return new VietQrResult(
            OrderId: orderId,
            Amount: normalizedAmount,
            PaymentContent: transferContent,
            QrImageUrl: qrImageUrl,
            QrCode: providerResponse.Data?.QrCode);
    }

    private string GetRequiredSetting(string key)
    {
        var value = _configuration[key];
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Missing required configuration: {key}");
        }

        return value.Trim();
    }

    private static string NormalizeAccountName(string accountName) =>
        accountName.Normalize(NormalizationForm.FormC);

    private sealed record VietQrGenerateRequest(
        string AccountNo,
        string AccountName,
        string AcqId,
        long Amount,
        string AddInfo,
        string Format,
        string Template);

    private sealed record VietQrGenerateResponse(
        string? Code,
        string? Desc,
        VietQrGenerateData? Data);

    private sealed record VietQrGenerateData(
        string? QrCode,
        string? QrDataUrl);
}

public sealed record VietQrResult(
    string OrderId,
    decimal Amount,
    string PaymentContent,
    string QrImageUrl,
    string? QrCode);
