using System.Globalization;
using System.Net.Http.Headers;
using System.Text.Json;

namespace backend_caulong.Services;

public interface ISePayTransactionLookupService
{
    Task<SePayPaymentLookupResult> FindIncomingPaymentAsync(
        string paymentContent,
        double requiredAmount,
        CancellationToken cancellationToken = default);
}

public sealed class SePayTransactionLookupService : ISePayTransactionLookupService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<SePayTransactionLookupService> _logger;

    public SePayTransactionLookupService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<SePayTransactionLookupService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<SePayPaymentLookupResult> FindIncomingPaymentAsync(
        string paymentContent,
        double requiredAmount,
        CancellationToken cancellationToken = default)
    {
        var apiToken = _configuration["SePay:ApiToken"];
        if (string.IsNullOrWhiteSpace(apiToken))
        {
            return SePayPaymentLookupResult.NotConfigured("SePay:ApiToken is not configured.");
        }

        var normalizedPaymentContent = PaymentReference.ResolvePaymentContent(_configuration, paymentContent)
            ?? paymentContent.Trim().ToUpperInvariant();
        var endpoint = _configuration["SePay:TransactionsEndpoint"]
            ?? "https://userapi.sepay.vn/v2/transactions";

        var requiredAmountVnd = Math.Round(requiredAmount, 0, MidpointRounding.AwayFromZero);
        var requestUri = BuildUri(endpoint, new Dictionary<string, string>
        {
            ["q"] = normalizedPaymentContent,
            ["amount_in_min"] = requiredAmountVnd.ToString(CultureInfo.InvariantCulture),
            ["transfer_type"] = "in",
            ["transaction_date_sort"] = "desc",
            ["per_page"] = "20",
            ["timestamp_format"] = "iso8601",
        });

        using var request = new HttpRequestMessage(HttpMethod.Get, requestUri);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken.Trim());

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var rawResponse = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "SePay transaction lookup failed. StatusCode={StatusCode}, Body={Body}",
                (int)response.StatusCode,
                rawResponse);

            throw new InvalidOperationException("SePay transaction lookup failed.");
        }

        var transactions = ReadTransactions(rawResponse);
        var expectedAccountNumber = _configuration["SePay:AccountNumber"]?.Trim();

        foreach (var transaction in transactions)
        {
            if (!string.Equals(transaction.TransferType, "in", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (transaction.AmountIn < requiredAmountVnd)
            {
                continue;
            }

            if (!string.IsNullOrWhiteSpace(expectedAccountNumber) &&
                !string.Equals(transaction.AccountNumber?.Trim(), expectedAccountNumber, StringComparison.Ordinal))
            {
                continue;
            }

            var resolvedPaymentContent = PaymentReference.ResolvePaymentContent(
                _configuration,
                transaction.Code,
                transaction.TransactionContent,
                transaction.ReferenceNumber);

            if (!string.Equals(resolvedPaymentContent, normalizedPaymentContent, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            return SePayPaymentLookupResult.Found(
                new SePayIncomingPayment(
                    transaction.Id,
                    transaction.AmountIn,
                    transaction.TransactionContent,
                    transaction.ReferenceNumber));
        }

        return SePayPaymentLookupResult.NotFound();
    }

    private static string BuildUri(string endpoint, IReadOnlyDictionary<string, string> parameters)
    {
        var separator = endpoint.Contains('?', StringComparison.Ordinal) ? '&' : '?';
        var query = string.Join(
            "&",
            parameters.Select(parameter =>
                $"{Uri.EscapeDataString(parameter.Key)}={Uri.EscapeDataString(parameter.Value)}"));

        return $"{endpoint}{separator}{query}";
    }

    private static IReadOnlyList<SePayTransaction> ReadTransactions(string rawResponse)
    {
        using var document = JsonDocument.Parse(rawResponse);
        if (!document.RootElement.TryGetProperty("data", out var data) ||
            data.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<SePayTransaction>();
        }

        var transactions = new List<SePayTransaction>();
        foreach (var item in data.EnumerateArray())
        {
            transactions.Add(new SePayTransaction(
                GetString(item, "id") ?? string.Empty,
                GetString(item, "account_number"),
                GetString(item, "transfer_type"),
                GetDouble(item, "amount_in"),
                GetString(item, "transaction_content"),
                GetString(item, "reference_number"),
                GetString(item, "code")));
        }

        return transactions;
    }

    private static string? GetString(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property) ||
            property.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            return null;
        }

        return property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : property.ToString();
    }

    private static double GetDouble(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return 0;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetDouble(out var number))
        {
            return number;
        }

        return property.ValueKind == JsonValueKind.String &&
               double.TryParse(property.GetString(), NumberStyles.Number, CultureInfo.InvariantCulture, out var value)
            ? value
            : 0;
    }

    private sealed record SePayTransaction(
        string Id,
        string? AccountNumber,
        string? TransferType,
        double AmountIn,
        string? TransactionContent,
        string? ReferenceNumber,
        string? Code);
}

public sealed record SePayPaymentLookupResult(
    bool IsConfigured,
    bool IsFound,
    string? Message,
    SePayIncomingPayment? Payment)
{
    public static SePayPaymentLookupResult NotConfigured(string message) =>
        new(false, false, message, null);

    public static SePayPaymentLookupResult NotFound() =>
        new(true, false, "No matching SePay transaction was found.", null);

    public static SePayPaymentLookupResult Found(SePayIncomingPayment payment) =>
        new(true, true, "Matching SePay transaction was found.", payment);
}

public sealed record SePayIncomingPayment(
    string TransactionId,
    double Amount,
    string? Content,
    string? ReferenceNumber);
