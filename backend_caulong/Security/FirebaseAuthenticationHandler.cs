using System.Security.Claims;
using System.Text.Encodings.Web;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace backend_caulong.Security;

public sealed class FirebaseAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Firebase";

    private readonly FirebaseAuth _firebaseAuth;

    public FirebaseAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        FirebaseAuth firebaseAuth)
        : base(options, logger, encoder)
    {
        _firebaseAuth = firebaseAuth;
    }

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var authorizationHeader = Request.Headers.Authorization.FirstOrDefault();
        if (string.IsNullOrWhiteSpace(authorizationHeader))
        {
            return AuthenticateResult.NoResult();
        }

        const string bearerPrefix = "Bearer ";
        if (!authorizationHeader.StartsWith(bearerPrefix, StringComparison.OrdinalIgnoreCase))
        {
            return AuthenticateResult.Fail("Invalid Authorization header scheme.");
        }

        var idToken = authorizationHeader[bearerPrefix.Length..].Trim();
        if (string.IsNullOrWhiteSpace(idToken))
        {
            return AuthenticateResult.Fail("Missing Firebase ID token.");
        }

        try
        {
            var decodedToken = await _firebaseAuth.VerifyIdTokenAsync(idToken, checkRevoked: true);
            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, decodedToken.Uid),
                new("uid", decodedToken.Uid),
                new("user_id", decodedToken.Uid),
            };

            if (decodedToken.Claims.TryGetValue("email", out var email) && email is string emailValue)
            {
                claims.Add(new Claim(ClaimTypes.Email, emailValue));
            }

            var identity = new ClaimsIdentity(claims, SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);

            return AuthenticateResult.Success(ticket);
        }
        catch (FirebaseAuthException ex)
        {
            return AuthenticateResult.Fail(ex);
        }
        catch (ArgumentException ex)
        {
            return AuthenticateResult.Fail(ex);
        }
    }
}
