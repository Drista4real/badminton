using System.Security.Claims;

namespace backend_caulong.Security;

public static class AuthenticatedUserExtensions
{
    public static string? GetFirebaseUserId(this ClaimsPrincipal user)
    {
        return user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? user.FindFirstValue("user_id")
            ?? user.FindFirstValue("uid");
    }
}
