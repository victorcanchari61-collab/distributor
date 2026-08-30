using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Models.Enums;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;

namespace Backend.Service.Implementacion;

public class UsuarioService : IUsuarioService
{
    private readonly IUsuarioRepository _repository;
    private readonly IConfiguration _configuration;
    private readonly IPasswordHasher<Usuario> _passwordHasher;
    private readonly IValidator<LoginRequest> _loginValidator;
    private readonly IValidator<CreateUsuarioRequest> _createValidator;

    public UsuarioService(IUsuarioRepository repository,
        IConfiguration configuration,
        IPasswordHasher<Usuario> passwordHasher,
        IValidator<LoginRequest> loginValidator,
        IValidator<CreateUsuarioRequest> createValidator)
    {
        _repository = repository;
        _configuration = configuration;
        _passwordHasher = passwordHasher;
        _loginValidator = loginValidator;
        _createValidator = createValidator;
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        await _loginValidator.ValidateAndThrowAsync(request);

        var usuario = await _repository.GetByEmailAsync(request.Email);
        if (usuario is null ||
            _passwordHasher.VerifyHashedPassword(usuario, usuario.PasswordHash, request.Password) ==
            PasswordVerificationResult.Failed)
        {
            throw new UnauthorizedException("Credenciales inválidas");
        }

        if (!usuario.Activo)
        {
            throw new UnauthorizedException("El usuario está desactivado");
        }

        return new LoginResponse
        {
            Token = GenerateToken(usuario),
            Usuario = MapToResponse(usuario)
        };
    }

    public async Task<UsuarioResponse> RegisterAsync(CreateUsuarioRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.GetByEmailAsync(request.Email) is not null)
        {
            throw new ConflictException("Ya existe un usuario con ese email");
        }

        var usuario = new Usuario
        {
            Nombre = request.Nombre,
            Email = request.Email,
            Role = request.Role
        };
        usuario.PasswordHash = _passwordHasher.HashPassword(usuario, request.Password);

        await _repository.AddAsync(usuario);
        return MapToResponse(usuario);
    }

    private string GenerateToken(Usuario usuario)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]!));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, usuario.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, usuario.Email),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.Name, usuario.Nombre),
            new Claim(ClaimTypes.Role, usuario.Role.ToString())
        };

        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_configuration.GetValue("Jwt:ExpireMinutes", 120)),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static UsuarioResponse MapToResponse(Usuario usuario)
    {
        return new UsuarioResponse
        {
            Id = usuario.Id,
            Nombre = usuario.Nombre,
            Email = usuario.Email,
            Role = usuario.Role,
            Activo = usuario.Activo,
            FechaCreacion = usuario.FechaCreacion
        };
    }
}
