using System.Text.RegularExpressions;

namespace backend_caulong.Services;

public static class PaymentReference
{
    private const string DefaultReferencePrefix = "BDM";
    private const string DefaultTransferContentPrefix = "SEVQR";

    public static string BuildPaymentContent(
        IConfiguration configuration,
        string orderId)
    {
        var normalizedOrderId = NormalizeSuffix(orderId);
        var prefix = GetReferencePrefix(configuration);

        return string.IsNullOrWhiteSpace(prefix)
            ? normalizedOrderId
            : $"{prefix}{normalizedOrderId}";
    }

    public static string BuildTransferContent(
        IConfiguration configuration,
        string paymentContent)
    {
        var normalizedPaymentContent = NormalizePaymentContent(paymentContent);
        var transferContentPrefix = GetTransferContentPrefix(configuration);
        if (string.IsNullOrWhiteSpace(transferContentPrefix) ||
            StartsWithKeyword(normalizedPaymentContent, transferContentPrefix))
        {
            return normalizedPaymentContent;
        }

        return $"{transferContentPrefix} {normalizedPaymentContent}";
    }

    public static string? ResolvePaymentContent(
        IConfiguration configuration,
        params string?[] values)
    {
        var prefix = GetReferencePrefix(configuration);
        if (string.IsNullOrWhiteSpace(prefix))
        {
            return values
                .Select(value => string.IsNullOrWhiteSpace(value) ? null : NormalizePaymentContent(value))
                .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
        }

        foreach (var value in values)
        {
            foreach (var candidate in BuildResolutionCandidates(configuration, value))
            {
                var paymentContent = ResolvePaymentContentFromValue(prefix, candidate);
                if (!string.IsNullOrWhiteSpace(paymentContent))
                {
                    return paymentContent;
                }
            }
        }

        return null;
    }

    public static string? ResolveOrderId(
        IConfiguration configuration,
        params string?[] values)
    {
        var prefix = GetReferencePrefix(configuration);
        if (string.IsNullOrWhiteSpace(prefix))
        {
            return values
                .Select(value => value?.Trim())
                .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
        }

        foreach (var value in values)
        {
            foreach (var candidate in BuildResolutionCandidates(configuration, value))
            {
                var orderId = ResolveOrderIdFromValue(prefix, candidate);
                if (!string.IsNullOrWhiteSpace(orderId))
                {
                    return orderId;
                }
            }
        }

        return null;
    }

    private static string GetReferencePrefix(IConfiguration configuration)
    {
        return (configuration["Payment:ReferencePrefix"] ?? DefaultReferencePrefix)
            .Trim()
            .ToUpperInvariant();
    }

    private static string GetTransferContentPrefix(IConfiguration configuration)
    {
        return (configuration["Payment:TransferContentPrefix"] ?? DefaultTransferContentPrefix)
            .Trim()
            .ToUpperInvariant();
    }

    private static string NormalizeSuffix(string suffix)
    {
        return suffix.Trim().ToUpperInvariant();
    }

    private static string NormalizePaymentContent(string paymentContent)
    {
        return Regex.Replace(paymentContent.Trim().ToUpperInvariant(), @"\s+", " ");
    }

    private static bool StartsWithKeyword(string value, string keyword)
    {
        return value.StartsWith(keyword, StringComparison.OrdinalIgnoreCase);
    }

    private static IEnumerable<string> BuildResolutionCandidates(
        IConfiguration configuration,
        string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            yield break;
        }

        var normalizedValue = NormalizePaymentContent(value);
        yield return normalizedValue;

        var transferContentPrefix = GetTransferContentPrefix(configuration);
        if (string.IsNullOrWhiteSpace(transferContentPrefix) ||
            !StartsWithKeyword(normalizedValue, transferContentPrefix))
        {
            yield break;
        }

        var withoutTransferPrefix = normalizedValue[transferContentPrefix.Length..]
            .TrimStart(' ', '-', '_', '.', ':');

        if (!string.IsNullOrWhiteSpace(withoutTransferPrefix))
        {
            yield return withoutTransferPrefix;
        }
    }

    private static string? ResolvePaymentContentFromValue(string prefix, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim().ToUpperInvariant();
        var match = Regex.Match(
            trimmed,
            $@"\b{Regex.Escape(prefix)}(?<orderId>[A-Z0-9]{{10,40}})\b",
            RegexOptions.IgnoreCase);

        return match.Success
            ? $"{prefix}{match.Groups["orderId"].Value.ToUpperInvariant()}"
            : null;
    }

    private static string? ResolveOrderIdFromValue(string prefix, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        if (trimmed.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            return trimmed[prefix.Length..].Trim();
        }

        var match = Regex.Match(
            trimmed,
            $@"\b{Regex.Escape(prefix)}(?<orderId>[A-Za-z0-9]{{10,40}})\b",
            RegexOptions.IgnoreCase);

        return match.Success
            ? match.Groups["orderId"].Value
            : null;
    }
}
