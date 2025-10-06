using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace CrowdCue_Backend.ApiService.Services;
public enum UserTypes
{
    PartyUser,
    PartyHost
}
public static class JwtService
{
    private const string JwtSecret = "super_secret_key_123alkjsdhfklashdfkahsdfkahsdfkjahsdfasdf!"; // TODO replace with secret key later if deployed
    
    public static string GenerateToken(string userId, UserTypes userType)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(JwtSecret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var claims = new[]
        {
                    new Claim(ClaimTypes.NameIdentifier, userId),
                    new Claim(ClaimTypes.Role, userType.ToString() )
                };
        var token = new JwtSecurityToken(
            claims: claims,
            expires: DateTime.UtcNow.AddHours(24),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public readonly record struct TokenValidationResult(string UserId, UserTypes UserType);
    public static TokenValidationResult? ValidateToken(string token)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(JwtSecret);
        try
        {
            var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ClockSkew = TimeSpan.FromMinutes(2)
            }, out _);
            var userId = principal.Claims.FirstOrDefault(x => x.Type == ClaimTypes.NameIdentifier)?.Value;
            var role = principal.Claims.FirstOrDefault(x => x.Type == ClaimTypes.Role)?.Value;
            if (role is not null && userId is not null && Enum.TryParse(role, out UserTypes userType))
                return new(userId, userType);
            return null;
        }
        catch
        {
            return null;
        }
    }
}

