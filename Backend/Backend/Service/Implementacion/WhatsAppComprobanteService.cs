using System.Globalization;
using System.Text.RegularExpressions;
using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Backend.Service.Pdf;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Backend.Service.Implementacion;

public class WhatsAppComprobanteService : IWhatsAppComprobanteService
{
    /// <summary>El mensaje de siempre; la empresa lo puede cambiar en Configuración > Empresa. Las {llaves} se reemplazan.</summary>
    public const string PlantillaPorDefecto =
        "Hola {cliente} 👋\nTe enviamos tu {tipo} {numero} por {total}.\n\nDescárgala aquí:\n{url}\n\nGracias por tu compra. — {empresa}";

    private readonly AppDbContext _context;
    private readonly IWhatsAppClient _whatsapp;
    private readonly IComprobanteElectronicoService _comprobantes;
    private readonly INotificador _notificador;
    private readonly IHttpContextAccessor _http;
    private readonly WhatsAppOpciones _opciones;
    private readonly ILogger<WhatsAppComprobanteService> _logger;

    public WhatsAppComprobanteService(
        AppDbContext context,
        IWhatsAppClient whatsapp,
        IComprobanteElectronicoService comprobantes,
        INotificador notificador,
        IHttpContextAccessor http,
        IOptions<WhatsAppOpciones> opciones,
        ILogger<WhatsAppComprobanteService> logger)
    {
        _context = context;
        _whatsapp = whatsapp;
        _comprobantes = comprobantes;
        _notificador = notificador;
        _http = http;
        _opciones = opciones.Value;
        _logger = logger;
    }

    public async Task<ComprobanteResponse> EnviarAsync(int comprobanteId, string? telefono)
    {
        var c = await _context.ComprobantesElectronicos.FirstOrDefaultAsync(x => x.Id == comprobanteId)
            ?? throw new NotFoundException($"No existe el comprobante {comprobanteId}");
        if (c.Estado != EstadoCpe.Aceptado)
            throw new BadRequestException("Solo se envía un comprobante que SUNAT ya aceptó");

        var empresa = await EmpresaAsync()
            ?? throw new BadRequestException("No hay una empresa activa");

        var error = await ProcesarAsync(c, empresa, telefono);
        if (error is not null) throw new BadRequestException(error);

        return await _comprobantes.GetAsync(c.Id);
    }

    public async Task EnviarAutomaticoAsync(int comprobanteId)
    {
        try
        {
            var c = await _context.ComprobantesElectronicos.FirstOrDefaultAsync(x => x.Id == comprobanteId);
            // Solo una vez: si ya se intentó (o el cliente no tenía teléfono), el reenvío es a mano.
            if (c is null || c.Estado != EstadoCpe.Aceptado || c.WhatsAppEstado is not null) return;

            var empresa = await EmpresaAsync();
            if (empresa is null || !empresa.WhatsAppAutomatico) return;

            await ProcesarAsync(c, empresa, null);
        }
        catch (Exception e)
        {
            _logger.LogError(e, "Falló el envío automático por WhatsApp del comprobante {Id}", comprobanteId);
        }
    }

    public async Task<EstadoWhatsAppResponse> EstadoAsync()
    {
        var estado = await _whatsapp.EstadoAsync();
        return new EstadoWhatsAppResponse
        {
            Estado = estado.Estado,
            EnCola = estado.EnCola,
            QrImagen = string.IsNullOrEmpty(estado.Qr) ? null : "data:image/png;base64," + Convert.ToBase64String(CodigoQr.Png(estado.Qr)),
            Error = estado.Error,
            FaltaToken = string.IsNullOrWhiteSpace(_opciones.Token),
        };
    }

    public Task<bool> DesvincularAsync() => _whatsapp.DesvincularAsync();

    // ------------------------------------------------------------------ Internos

    private Task<Empresa?> EmpresaAsync() => _context.Empresas.AsNoTracking().FirstOrDefaultAsync(e => e.Activa);

    /// <summary>Arma el mensaje, lo encola en el servicio y deja anotado en qué quedó. Devuelve el error, o nulo si salió.</summary>
    private async Task<string?> ProcesarAsync(ComprobanteElectronico c, Empresa empresa, string? telefonoManual)
    {
        var telefono = SoloDigitos(telefonoManual)
            ?? SoloDigitos(await _context.Clientes.AsNoTracking()
                .Where(x => x.Id == c.ClienteId).Select(x => x.Telefono).FirstOrDefaultAsync());

        string? error = null;
        if (telefono is null)
        {
            c.WhatsAppEstado = EstadoWhatsApp.SinTelefono;
            c.WhatsAppTelefono = null;
            c.WhatsAppEnviadoEn = null;
            error = "El cliente no tiene teléfono: escríbelo para enviarlo";
        }
        else
        {
            var (ok, fallo) = await _whatsapp.EnviarAsync(telefono, Mensaje(c, empresa));
            c.WhatsAppEstado = ok ? EstadoWhatsApp.Encolado : EstadoWhatsApp.Error;
            c.WhatsAppTelefono = telefono;
            c.WhatsAppEnviadoEn = ok ? DateTime.UtcNow : null;
            error = ok ? null : fallo;
        }

        c.WhatsAppError = error;
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("comprobantes", "whatsapp", new { c.Id, c.WhatsAppEstado });
        return error;
    }

    private string Mensaje(ComprobanteElectronico c, Empresa empresa)
    {
        var plantilla = string.IsNullOrWhiteSpace(empresa.WhatsAppPlantilla) ? PlantillaPorDefecto : empresa.WhatsAppPlantilla;

        var texto = plantilla
            .Replace("{cliente}", c.ClienteNombre.Trim(), StringComparison.OrdinalIgnoreCase)
            .Replace("{tipo}", NombreCorto(c.Tipo), StringComparison.OrdinalIgnoreCase)
            .Replace("{numero}", $"{c.Serie}-{c.Numero:D8}", StringComparison.OrdinalIgnoreCase)
            .Replace("{total}", "S/ " + c.Total.ToString("0.00", CultureInfo.InvariantCulture), StringComparison.OrdinalIgnoreCase)
            .Replace("{empresa}", empresa.NombreComercial, StringComparison.OrdinalIgnoreCase)
            .Replace("{url}", UrlPublica(c), StringComparison.OrdinalIgnoreCase);

        // El enlace siempre va, aunque la plantilla lo haya borrado: es lo único que sirve del mensaje.
        if (!texto.Contains(UrlPublica(c), StringComparison.Ordinal)) texto += $"\n\n{UrlPublica(c)}";

        // Un comprobante de pruebas no vale: que quien lo recibe no lo tome por real.
        return c.Entorno == "produccion" ? texto : "🧪 PRUEBA — sin validez tributaria\n" + texto;
    }

    /// <summary>El enlace que baja el PDF directo: /api/publico/comprobante/{token}. El token es aleatorio y no se adivina.</summary>
    private string UrlPublica(ComprobanteElectronico c)
    {
        var baseUrl = _opciones.UrlPublica.TrimEnd('/');
        if (baseUrl.Length == 0 && _http.HttpContext?.Request is { } r) baseUrl = $"{r.Scheme}://{r.Host}";
        return $"{baseUrl}/api/publico/comprobante/{c.TokenPublico}";
    }

    private static string NombreCorto(string tipo) => tipo switch
    {
        TipoCpe.Factura => "factura",
        TipoCpe.Boleta => "boleta",
        TipoCpe.NotaCredito => "nota de crédito",
        TipoCpe.NotaDebito => "nota de débito",
        _ => "comprobante",
    };

    /// <summary>El teléfono sin espacios ni guiones (puede quedar con el +51): el servicio de WhatsApp completa el país.</summary>
    private static string? SoloDigitos(string? telefono)
    {
        if (string.IsNullOrWhiteSpace(telefono)) return null;
        var limpio = Regex.Replace(telefono, @"\D", "");
        return limpio.Length >= 9 ? limpio : null;
    }
}
