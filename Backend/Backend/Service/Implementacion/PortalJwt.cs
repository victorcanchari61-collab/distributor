using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Backend.Models;
using Microsoft.IdentityModel.Tokens;

namespace Backend.Service.Implementacion;

/// <summary>
/// La sesión de un cliente en el portal.
///
/// Es un JWT firmado con la misma clave que el del personal pero con OTRA audiencia: el esquema por defecto (el del
/// panel) exige la audiencia del panel y lo rechaza, así que con esta sesión no se puede llamar a nada fuera de
/// /api/portal. Tampoco lleva "sub" ni roles: la auditoría y los permisos leen de ahí al usuario del sistema, y un
/// cliente no lo es.
/// </summary>
public static class PortalJwt
{
    /// <summary>El esquema de autenticación de los endpoints del portal.</summary>
    public const string Esquema = "Portal";

    public const string ClaimAcceso = "portal_acceso";
    public const string ClaimCliente = "portal_cliente";
    public const string ClaimVersion = "portal_ver";

    /// <summary>Cuánto dura la sesión: el celular la recuerda y casi nunca vuelve a escribir la contraseña.</summary>
    public static readonly TimeSpan Duracion = TimeSpan.FromDays(90);

    /// <summary>"Jwt:AudiencePortal", o la del panel con "-portal" al final.</summary>
    public static string Audiencia(IConfiguration configuration) =>
        configuration["Jwt:AudiencePortal"] is { Length: > 0 } propia
            ? propia
            : $"{configuration["Jwt:Audience"]}-portal";

    public static TokenValidationParameters Validacion(IConfiguration configuration) => new()
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = configuration["Jwt:Issuer"],
        ValidAudience = Audiencia(configuration),
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configuration["Jwt:Key"]!)),
    };

    public static string Emitir(IConfiguration configuration, AccesoCliente acceso)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configuration["Jwt:Key"]!));
        var claims = new[]
        {
            new Claim(ClaimAcceso, acceso.Id.ToString()),
            new Claim(ClaimCliente, acceso.ClienteId.ToString()),
            new Claim(ClaimVersion, acceso.VersionSesion.ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        var token = new JwtSecurityToken(
            issuer: configuration["Jwt:Issuer"],
            audience: Audiencia(configuration),
            claims: claims,
            expires: DateTime.UtcNow.Add(Duracion),
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
