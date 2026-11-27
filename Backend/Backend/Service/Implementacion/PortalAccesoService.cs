using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace Backend.Service.Implementacion;

public partial class PortalAccesoService : IPortalAccesoService
{
    /// <summary>Cuánto vale el enlace de invitación: da tiempo a que el cliente lo vea, sin quedar abierto para siempre.</summary>
    private static readonly TimeSpan VigenciaInvitacion = TimeSpan.FromDays(7);

    /// <summary>El de "olvidé mi contraseña" es corto: lo pidió él mismo, lo va a usar enseguida.</summary>
    private static readonly TimeSpan VigenciaRecuperacion = TimeSpan.FromHours(1);

    /// <summary>Intentos fallidos de entrar antes de hacer esperar, por usuario: frena a quien prueba contraseñas.</summary>
    private const int MaximoIntentos = 8;
    private static readonly TimeSpan VentanaIntentos = TimeSpan.FromMinutes(15);

    /// <summary>Entre dos pedidos de "olvidé mi contraseña" de la misma cuenta: que no se use para llenar su WhatsApp.</summary>
    private static readonly TimeSpan PausaOlvide = TimeSpan.FromMinutes(2);

    private readonly ICotizacionRepository _repository;
    private readonly IClienteRepository _clientes;
    private readonly IEmpresaRepository _empresas;
    private readonly IWhatsAppClient _whatsApp;
    private readonly WhatsAppOpciones _opcionesWhatsApp;
    private readonly IHttpContextAccessor _http;
    private readonly IPasswordHasher<AccesoCliente> _hasher;
    private readonly IConfiguration _configuration;
    private readonly IMemoryCache _cache;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IPermisoService _permisos;
    private readonly ILogger<PortalAccesoService> _logger;

    public PortalAccesoService(
        ICotizacionRepository repository,
        IClienteRepository clientes,
        IEmpresaRepository empresas,
        IWhatsAppClient whatsApp,
        IOptions<WhatsAppOpciones> opcionesWhatsApp,
        IHttpContextAccessor http,
        IPasswordHasher<AccesoCliente> hasher,
        IConfiguration configuration,
        IMemoryCache cache,
        IUsuarioActual usuarioActual,
        IPermisoService permisos,
        ILogger<PortalAccesoService> logger)
    {
        _repository = repository;
        _clientes = clientes;
        _empresas = empresas;
        _whatsApp = whatsApp;
        _opcionesWhatsApp = opcionesWhatsApp.Value;
        _http = http;
        _hasher = hasher;
        _configuration = configuration;
        _cache = cache;
        _usuarioActual = usuarioActual;
        _permisos = permisos;
        _logger = logger;
    }

    // ================================================================ Panel

    public async Task<AccesoPortalResponse> EstadoAsync(int clienteId)
    {
        var cliente = await ClienteOrThrowAsync(clienteId);
        return Estado(await _repository.GetAccesoDeClienteAsync(clienteId), cliente);
    }

    public async Task<InvitacionPortalResponse> InvitarAsync(int clienteId)
    {
        var cliente = await ClienteOrThrowAsync(clienteId);
        await ExigirAlcanceAsync(cliente);
        if (!cliente.Activo) throw new BadRequestException("El cliente está desactivado: actívalo antes de invitarlo.");

        var acceso = await _repository.GetAccesoDeClienteAsync(clienteId);
        var nuevo = acceso is null;
        acceso ??= new AccesoCliente { ClienteId = clienteId };

        var token = NuevoToken();
        acceso.TokenHash = Hash(token);
        acceso.TokenTipo = TipoTokenAcceso.Invitacion;
        acceso.TokenExpira = DateTime.UtcNow.Add(VigenciaInvitacion);
        acceso.FechaInvitacion = DateTime.UtcNow;
        acceso.InvitadoPorId = _usuarioActual.Id;
        acceso.Activo = true;

        if (nuevo) await _repository.AddAccesoAsync(acceso);
        else await _repository.SaveAsync();

        var enlace = Enlace("activar", token);
        var empresa = await NombreEmpresaAsync();
        var mensaje =
            $"Hola, {cliente.Nombre}. {empresa} te invita a mandar tus cotizaciones desde tu celular.\n\n" +
            $"Crea tu usuario y contraseña aquí (el enlace vence en 7 días):\n{enlace}";
        var (enviado, motivo) = await EnviarWhatsAppAsync(cliente.Telefono, mensaje);

        acceso = await _repository.GetAccesoDeClienteAsync(clienteId);
        return new InvitacionPortalResponse
        {
            Enlace = enlace,
            Vence = acceso!.TokenExpira!.Value,
            EnviadoPorWhatsApp = enviado,
            MotivoNoEnviado = motivo,
            Acceso = Estado(acceso, cliente),
        };
    }

    public async Task<AccesoPortalResponse> CambiarActivoAsync(int clienteId, bool activo)
    {
        var cliente = await ClienteOrThrowAsync(clienteId);
        await ExigirAlcanceAsync(cliente);
        var acceso = await _repository.GetAccesoDeClienteAsync(clienteId)
            ?? throw new BadRequestException("Este cliente todavía no tiene acceso al portal: invítalo primero.");

        if (acceso.Activo != activo)
        {
            acceso.Activo = activo;
            // Apagarlo cierra las sesiones abiertas: el token lleva la versión y deja de coincidir.
            if (!activo)
            {
                acceso.VersionSesion++;
                acceso.TokenHash = null;
                acceso.TokenTipo = null;
                acceso.TokenExpira = null;
            }
            await _repository.SaveAsync();
        }

        return Estado(acceso, cliente);
    }

    // ============================================================ Sin sesión

    public async Task<EnlacePortalResponse> VerEnlaceAsync(string token)
    {
        var acceso = await AccesoDeEnlaceAsync(token, null);
        return new EnlacePortalResponse
        {
            Tipo = acceso.TokenTipo!,
            Cliente = acceso.Cliente!.Nombre,
            UsuarioSugerido = acceso.TokenTipo == TipoTokenAcceso.Invitacion ? acceso.Usuario ?? acceso.Cliente.Documento : null,
            Usuario = acceso.TokenTipo == TipoTokenAcceso.Recuperacion ? acceso.Usuario : null,
            Empresa = await NombreEmpresaAsync(),
        };
    }

    public async Task<PortalSesionResponse> ActivarAsync(PortalActivarRequest request)
    {
        var acceso = await AccesoDeEnlaceAsync(request.Token, TipoTokenAcceso.Invitacion);
        var cliente = acceso.Cliente!;

        // El documento confirma que quien abrió el enlace es el cliente y no alguien a quien se lo reenviaron.
        var documento = SoloDigitos(request.Documento);
        if (documento.Length == 0 || (documento != cliente.Documento && documento != cliente.DocumentoAlterno))
        {
            throw new BadRequestException("Ese DNI o RUC no es el de este cliente. Revisa el número.");
        }

        var usuario = LimpiarUsuario(request.Usuario);
        ExigirUsuarioValido(usuario);
        if (await _repository.UsuarioTomadoAsync(usuario, acceso.Id))
        {
            throw new ConflictException("Ese usuario ya lo usa otra persona. Prueba con otro.");
        }
        ExigirPasswordValida(request.Password);

        acceso.Usuario = usuario;
        acceso.PasswordHash = _hasher.HashPassword(acceso, request.Password);
        acceso.FechaActivacion ??= DateTime.UtcNow;
        acceso.Activo = true;
        // Si ya tenía cuenta y lo reinvitaron, los celulares donde estaba dejan de entrar con lo de antes.
        acceso.VersionSesion++;
        return await IniciarSesionAsync(acceso, usarToken: true);
    }

    public async Task<PortalSesionResponse> RestablecerAsync(PortalRestablecerRequest request)
    {
        var acceso = await AccesoDeEnlaceAsync(request.Token, TipoTokenAcceso.Recuperacion);
        ExigirPasswordValida(request.Password);

        acceso.PasswordHash = _hasher.HashPassword(acceso, request.Password);
        // Cambiar la contraseña cierra las otras sesiones: si alguien más la sabía, ya no entra.
        acceso.VersionSesion++;
        return await IniciarSesionAsync(acceso, usarToken: true);
    }

    public async Task<PortalSesionResponse> LoginAsync(PortalLoginRequest request)
    {
        var identificador = LimpiarUsuario(request.Usuario);
        if (identificador.Length == 0 || string.IsNullOrEmpty(request.Password))
        {
            throw new BadRequestException("Escribe tu usuario y tu contraseña.");
        }

        var claveIntentos = $"portal-login:{identificador}";
        if (_cache.TryGetValue(claveIntentos, out int intentos) && intentos >= MaximoIntentos)
        {
            throw new BadRequestException("Demasiados intentos. Espera unos minutos o pide una contraseña nueva.");
        }

        var acceso = await _repository.GetAccesoPorIdentificadorAsync(identificador);
        if (acceso?.PasswordHash is null
            || _hasher.VerifyHashedPassword(acceso, acceso.PasswordHash, request.Password) == PasswordVerificationResult.Failed)
        {
            _cache.Set(claveIntentos, intentos + 1, VentanaIntentos);
            throw new UnauthorizedException("Usuario o contraseña incorrectos.");
        }

        if (!acceso.Activo || acceso.Cliente is not { Activo: true })
        {
            throw new UnauthorizedException("Tu acceso está desactivado. Habla con tu vendedor.");
        }

        _cache.Remove(claveIntentos);
        return await IniciarSesionAsync(acceso, usarToken: false);
    }

    public async Task OlvideAsync(PortalOlvideRequest request)
    {
        var identificador = LimpiarUsuario(request.Usuario);
        if (identificador.Length == 0) throw new BadRequestException("Escribe tu usuario o tu DNI/RUC.");

        var acceso = await _repository.GetAccesoPorIdentificadorAsync(identificador);
        if (acceso is null || !acceso.Activo || acceso.Cliente is not { Activo: true }) return;

        // Una sola vez cada dos minutos por cuenta. En silencio, como cuando no existe.
        var clavePausa = $"portal-olvide:{acceso.Id}";
        if (_cache.TryGetValue(clavePausa, out _)) return;
        _cache.Set(clavePausa, true, PausaOlvide);

        var token = NuevoToken();
        acceso.TokenHash = Hash(token);
        acceso.TokenTipo = TipoTokenAcceso.Recuperacion;
        acceso.TokenExpira = DateTime.UtcNow.Add(VigenciaRecuperacion);
        await _repository.SaveAsync();

        var mensaje =
            $"Hola, {acceso.Cliente.Nombre}. Para crear una contraseña nueva entra aquí (vence en 1 hora):\n" +
            $"{Enlace("restablecer", token)}\n\n" +
            $"Tu usuario es: {acceso.Usuario}\nSi no lo pediste, ignora este mensaje.";
        var (enviado, motivo) = await EnviarWhatsAppAsync(acceso.Cliente.Telefono, mensaje);
        if (!enviado) _logger.LogWarning("Portal: no salió la recuperación del acceso {Acceso}: {Motivo}", acceso.Id, motivo);
    }

    // ============================================================ Con sesión

    public async Task<AccesoCliente> AccesoActualAsync()
    {
        var usuario = _http.HttpContext?.User;
        if (!int.TryParse(usuario?.FindFirst(PortalJwt.ClaimAcceso)?.Value, out var accesoId)
            || !int.TryParse(usuario?.FindFirst(PortalJwt.ClaimVersion)?.Value, out var version))
        {
            throw new UnauthorizedException("Inicia sesión para continuar.");
        }

        var acceso = await _repository.GetAccesoAsync(accesoId);
        if (acceso is null || !acceso.Activo || acceso.VersionSesion != version || acceso.Cliente is not { Activo: true })
        {
            throw new UnauthorizedException("Tu sesión ya no es válida. Vuelve a entrar.");
        }
        return acceso;
    }

    public async Task<PortalClienteResponse> YoAsync() => await ClienteDeAsync(await AccesoActualAsync());

    public async Task<PortalSesionResponse> CambiarUsuarioAsync(PortalCambiarUsuarioRequest request)
    {
        var acceso = await AccesoActualAsync();
        ExigirPasswordActual(acceso, request.PasswordActual);

        var usuario = LimpiarUsuario(request.Usuario);
        ExigirUsuarioValido(usuario);
        if (usuario != acceso.Usuario)
        {
            if (await _repository.UsuarioTomadoAsync(usuario, acceso.Id))
            {
                throw new ConflictException("Ese usuario ya lo usa otra persona. Prueba con otro.");
            }
            acceso.Usuario = usuario;
            await _repository.SaveAsync();
        }

        return new PortalSesionResponse
        {
            Token = PortalJwt.Emitir(_configuration, acceso),
            Cliente = await ClienteDeAsync(acceso),
        };
    }

    public async Task<PortalSesionResponse> CambiarPasswordAsync(PortalCambiarPasswordRequest request)
    {
        var acceso = await AccesoActualAsync();
        ExigirPasswordActual(acceso, request.PasswordActual);
        ExigirPasswordValida(request.PasswordNueva);

        acceso.PasswordHash = _hasher.HashPassword(acceso, request.PasswordNueva);
        // Los demás celulares tienen que volver a entrar; este recibe su sesión nueva aquí mismo.
        acceso.VersionSesion++;
        // Un enlace de recuperación pendiente ya no hace falta.
        if (acceso.TokenTipo == TipoTokenAcceso.Recuperacion)
        {
            acceso.TokenHash = null;
            acceso.TokenTipo = null;
            acceso.TokenExpira = null;
        }
        await _repository.SaveAsync();

        return new PortalSesionResponse
        {
            Token = PortalJwt.Emitir(_configuration, acceso),
            Cliente = await ClienteDeAsync(acceso),
        };
    }

    /// <summary>Para tocar el usuario o la contraseña hay que saber la actual: un celular prestado no basta.</summary>
    private void ExigirPasswordActual(AccesoCliente acceso, string? password)
    {
        if (string.IsNullOrEmpty(password) || acceso.PasswordHash is null
            || _hasher.VerifyHashedPassword(acceso, acceso.PasswordHash, password) == PasswordVerificationResult.Failed)
        {
            // 400 y no 401: un 401 haría que el portal cierre la sesión por una contraseña mal escrita.
            throw new BadRequestException("La contraseña actual no es correcta.");
        }
    }

    // ============================================================== Apoyo

    private async Task<PortalSesionResponse> IniciarSesionAsync(AccesoCliente acceso, bool usarToken)
    {
        // El enlace ya sirvió: no se puede volver a usar.
        if (usarToken)
        {
            acceso.TokenHash = null;
            acceso.TokenTipo = null;
            acceso.TokenExpira = null;
        }
        acceso.UltimoIngreso = DateTime.UtcNow;
        await _repository.SaveAsync();

        return new PortalSesionResponse
        {
            Token = PortalJwt.Emitir(_configuration, acceso),
            Cliente = await ClienteDeAsync(acceso),
        };
    }

    private async Task<PortalClienteResponse> ClienteDeAsync(AccesoCliente acceso)
    {
        var cliente = acceso.Cliente!;
        var empresa = await _empresas.GetActivaAsync();
        var vendedores = cliente.RutaId is int ruta ? await _repository.VendedoresDeRutaAsync(ruta) : [];
        return new PortalClienteResponse
        {
            Nombre = cliente.Nombre,
            Documento = cliente.Documento,
            Usuario = acceso.Usuario ?? string.Empty,
            Vendedor = vendedores.Count == 0 ? null : string.Join(", ", vendedores.Select(v => v.Nombre)),
            TelefonoVendedor = vendedores.Select(v => v.Telefono?.Trim()).FirstOrDefault(t => !string.IsNullOrEmpty(t)),
            Empresa = NombreDe(empresa),
            TelefonoEmpresa = string.IsNullOrWhiteSpace(empresa?.Telefono) ? null : empresa!.Telefono!.Trim(),
            Telefono = string.IsNullOrWhiteSpace(cliente.Telefono) ? null : cliente.Telefono.Trim(),
            Direccion = string.IsNullOrWhiteSpace(cliente.Direccion) ? null : cliente.Direccion.Trim(),
            UltimoIngreso = acceso.UltimoIngreso,
        };
    }

    private async Task<AccesoCliente> AccesoDeEnlaceAsync(string token, string? tipo)
    {
        var acceso = string.IsNullOrWhiteSpace(token) ? null : await _repository.GetAccesoPorTokenAsync(Hash(token.Trim()));
        if (acceso is null || (tipo is not null && acceso.TokenTipo != tipo))
        {
            throw new NotFoundException("Este enlace ya no sirve: se usó o se pidió otro más nuevo.");
        }
        if (acceso.TokenExpira is not DateTime vence || vence < DateTime.UtcNow)
        {
            throw new BadRequestException(acceso.TokenTipo == TipoTokenAcceso.Invitacion
                ? "Esta invitación venció. Pídele a tu vendedor que te mande otra."
                : "Este enlace venció. Pide otro desde «Olvidé mi contraseña».");
        }
        if (!acceso.Activo || acceso.Cliente is not { Activo: true })
        {
            throw new BadRequestException("Tu acceso está desactivado. Habla con tu vendedor.");
        }
        return acceso;
    }

    private static AccesoPortalResponse Estado(AccesoCliente? acceso, Cliente cliente)
    {
        var telefono = TelefonoWhatsApp(cliente.Telefono);
        if (acceso is null) return new AccesoPortalResponse { Estado = "SIN_INVITAR", Telefono = telefono };

        var invitacionPendiente = acceso.TokenTipo == TipoTokenAcceso.Invitacion && acceso.TokenExpira > DateTime.UtcNow;
        return new AccesoPortalResponse
        {
            Estado = !acceso.Activo ? "DESACTIVADO" : acceso.PasswordHash is null ? "INVITADO" : "ACTIVO",
            Usuario = acceso.Usuario,
            FechaInvitacion = acceso.FechaInvitacion,
            InvitadoPor = acceso.InvitadoPor?.Nombre,
            InvitacionVence = invitacionPendiente ? acceso.TokenExpira : null,
            FechaActivacion = acceso.FechaActivacion,
            UltimoIngreso = acceso.UltimoIngreso,
            Telefono = telefono,
        };
    }

    private async Task<Cliente> ClienteOrThrowAsync(int clienteId) =>
        await _clientes.GetByIdAsync(clienteId) ?? throw new NotFoundException($"No existe el cliente {clienteId}");

    /// <summary>Como al editar el cliente: solo los de tus rutas, si tu alcance en Clientes es ese.</summary>
    private async Task ExigirAlcanceAsync(Cliente cliente)
    {
        if (_usuarioActual.Id is not int id) return;
        var alcance = await _permisos.AlcanceFiltroAsync(id, "maestros.clientes");
        if (alcance.SinRestriccion) return;
        if (!alcance.EsDeMisRutas(cliente.RutaId))
        {
            throw new ForbiddenException("Solo puedes dar acceso a los clientes de tus rutas");
        }
    }

    private async Task<(bool Enviado, string? Motivo)> EnviarWhatsAppAsync(string? telefono, string mensaje)
    {
        var numero = TelefonoWhatsApp(telefono);
        if (numero is null) return (false, "El cliente no tiene un teléfono válido en su ficha.");
        try
        {
            var (ok, error) = await _whatsApp.EnviarAsync(numero, mensaje);
            return ok ? (true, null) : (false, error ?? "No se pudo enviar por WhatsApp.");
        }
        catch (Exception e)
        {
            _logger.LogWarning(e, "Portal: falló el envío por WhatsApp");
            return (false, "No se pudo enviar por WhatsApp.");
        }
    }

    /// <summary>
    /// La dirección pública del portal: la configurada para WhatsApp; si no hay, la de la página desde donde se pidió
    /// (el panel al invitar, el portal al recuperar), que es la que el cliente puede abrir.
    /// </summary>
    private string Enlace(string accion, string token)
    {
        var baseUrl = _opcionesWhatsApp.UrlPublica.TrimEnd('/');
        var request = _http.HttpContext?.Request;
        if (baseUrl.Length == 0 && request is not null)
        {
            var origen = request.Headers.Origin.ToString();
            baseUrl = origen.Length > 0 ? origen.TrimEnd('/') : $"{request.Scheme}://{request.Host}";
        }
        return $"{baseUrl}/portal/{accion}/{token}";
    }

    private async Task<string> NombreEmpresaAsync() => NombreDe(await _empresas.GetActivaAsync());

    private static string NombreDe(Empresa? empresa) =>
        empresa?.NombreComercial is { Length: > 0 } comercial ? comercial : empresa?.RazonSocial ?? "Tu distribuidora";

    private static string NuevoToken() => WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));

    private static string Hash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).ToLowerInvariant();

    private static string LimpiarUsuario(string? usuario) => (usuario ?? string.Empty).Trim().ToLowerInvariant();

    private static string SoloDigitos(string? texto) => Regex.Replace(texto ?? string.Empty, @"\D", "");

    /// <summary>El teléfono en dígitos (puede traer el 51 delante); null si no alcanza para un celular.</summary>
    private static string? TelefonoWhatsApp(string? telefono)
    {
        var limpio = SoloDigitos(telefono);
        return limpio.Length >= 9 ? limpio : null;
    }

    [GeneratedRegex("^[a-z0-9._-]{4,30}$")]
    private static partial Regex UsuarioValido();

    private static void ExigirUsuarioValido(string usuario)
    {
        if (!UsuarioValido().IsMatch(usuario))
        {
            throw new BadRequestException(
                "El usuario debe tener de 4 a 30 caracteres: letras, números, punto, guion o guion bajo (sin espacios).");
        }
    }

    private static void ExigirPasswordValida(string? password)
    {
        if (string.IsNullOrEmpty(password) || password.Length < 6)
        {
            throw new BadRequestException("La contraseña debe tener al menos 6 caracteres.");
        }
        if (password.Length > 100) throw new BadRequestException("La contraseña es demasiado larga.");
    }
}
