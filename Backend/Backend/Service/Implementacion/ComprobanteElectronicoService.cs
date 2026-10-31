using System.Text;
using System.Text.Json;
using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Backend.Service.Implementacion;

public class ComprobanteElectronicoService : IComprobanteElectronicoService
{
    /// <summary>Desde este monto una boleta ya necesita el documento del cliente (S/ 700, regla de SUNAT).</summary>
    private const decimal MontoBoletaConDocumento = 700m;

    private static readonly string[] MotivosCredito = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13"];
    private static readonly string[] MotivosDebito = ["01", "02", "03"];

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly AppDbContext _context;
    private readonly IFactuClient _factu;
    private readonly FacturacionOpciones _opciones;
    private readonly IUsuarioActual _usuarioActual;
    private readonly INotificador _notificador;
    private readonly IProtectorSecretos _protector;

    public ComprobanteElectronicoService(
        AppDbContext context,
        IFactuClient factu,
        IOptions<FacturacionOpciones> opciones,
        IUsuarioActual usuarioActual,
        INotificador notificador,
        IProtectorSecretos protector)
    {
        _protector = protector;
        _context = context;
        _factu = factu;
        _opciones = opciones.Value;
        _usuarioActual = usuarioActual;
        _notificador = notificador;
    }

    // ------------------------------------------------------------------ Consultas

    public async Task<List<ComprobanteResponse>> ListarAsync(
        IReadOnlyCollection<string> tipos, string? estado, DateTime? desde, DateTime? hasta, int? notaVentaId, int? afectadoId)
    {
        var consulta = Consulta().Where(c => tipos.Contains(c.Tipo));
        if (!string.IsNullOrWhiteSpace(estado)) consulta = consulta.Where(c => c.Estado == estado.Trim().ToUpperInvariant());
        if (desde is DateTime d) consulta = consulta.Where(c => c.FechaEmision >= d.Date);
        if (hasta is DateTime h) consulta = consulta.Where(c => c.FechaEmision <= h.Date);
        if (notaVentaId is int n) consulta = consulta.Where(c => c.NotaVentaId == n);
        if (afectadoId is int a) consulta = consulta.Where(c => c.AfectadoId == a);

        var filas = await consulta.OrderByDescending(c => c.Id).Take(500).ToListAsync();
        return filas.Select(Mapear).ToList();
    }

    public async Task<ComprobanteResponse> GetAsync(int id) => Mapear(await ObtenerAsync(id));

    public async Task<string> TipoAsync(int id) =>
        await _context.ComprobantesElectronicos.AsNoTracking().Where(c => c.Id == id).Select(c => c.Tipo).FirstOrDefaultAsync()
        ?? throw new NotFoundException($"No existe el comprobante {id}");

    // ------------------------------------------------------------ Factura y boleta

    public async Task<ComprobanteResponse> EmitirAsync(EmitirComprobanteRequest request)
    {
        if (request.Tipo is not (TipoCpe.Factura or TipoCpe.Boleta))
            throw new BadRequestException("El tipo debe ser 01 (factura) o 03 (boleta)");

        var venta = await _context.NotasVenta
            .Include(n => n.Cliente)
            .Include(n => n.Detalle).ThenInclude(d => d.Producto)
            .Include(n => n.Detalle).ThenInclude(d => d.Presentacion)
            .Include(n => n.Recojos)
            .FirstOrDefaultAsync(n => n.Id == request.NotaVentaId)
            ?? throw new NotFoundException($"No existe la nota de venta {request.NotaVentaId}");

        if (venta.Estado == EstadoNotaVenta.Anulada)
            throw new BadRequestException("La nota de venta está anulada: no se puede facturar");

        // Una venta se factura una sola vez. Si el comprobante anterior fue rechazado, se puede emitir otro.
        var yaEmitido = await _context.ComprobantesElectronicos.AsNoTracking()
            .Where(c => c.NotaVentaId == venta.Id && c.Estado != EstadoCpe.Rechazado && (c.Tipo == TipoCpe.Factura || c.Tipo == TipoCpe.Boleta))
            .Select(c => c.Serie + "-" + c.Numero)
            .FirstOrDefaultAsync();
        if (yaEmitido is not null)
            throw new ConflictException($"Esta venta ya tiene el comprobante {yaEmitido}");

        // Un recojo se descuenta de esta venta pero no es una línea de ella: el comprobante no tendría de dónde
        // restarlo. Por ahora se avisa en vez de emitir un importe que no cuadra con lo cobrado.
        if (venta.Recojos.Any(r => r.Estado != EstadoRecojo.Anulado))
            throw new BadRequestException("Esta venta tiene recojos descontados y todavía no se puede facturar");

        var lineas = venta.Detalle.Where(d => !d.Anulado)
            .Select(d => new LineaCpe(
                Descripcion(d),
                d.CantidadPresentacion,
                d.PrecioPresentacion,
                d.AfectoIgv,
                d.Producto?.Codigo))
            .ToList();
        if (lineas.Count == 0) throw new BadRequestException("La venta no tiene líneas para facturar");

        var totales = Totales(lineas);
        var cliente = ClienteDe(venta.Cliente!, request.Tipo, totales.Total);
        var emisora = await EmpresaAsync();
        var empresa = emisora.Api;
        var hoy = Zona.Hoy;

        var credito = venta.FormaPago == FormaPagoVenta.Credito;
        var comprobante = new ComprobanteElectronico
        {
            Tipo = request.Tipo,
            NotaVentaId = venta.Id,
            ClienteId = venta.ClienteId,
            FechaEmision = hoy,
            ClienteTipoDoc = cliente.TipoDoc,
            ClienteDocumento = cliente.Documento,
            ClienteNombre = cliente.Nombre,
            ClienteDireccion = cliente.Direccion,
            OpGravada = totales.Gravada,
            OpExonerada = totales.Exonerada,
            Igv = totales.Igv,
            Total = totales.Total,
            DetalleJson = JsonSerializer.Serialize(lineas.Select(l => new LineaComprobanteResponse
            {
                Descripcion = l.Descripcion, Cantidad = l.Cantidad, Precio = l.Precio, AfectoIgv = l.AfectoIgv,
            }), Json),
            Entorno = emisora.Entorno,
            UsuarioId = _usuarioActual.Id,
        };

        await GenerarYGuardarAsync(comprobante, emisora.EmpresaId, null, async numero =>
        {
            var cuerpo = new Dictionary<string, object?>
            {
                ["endpoint"] = emisora.Entorno,
                ["documento"] = TipoCpe.ParaApi(request.Tipo),
                ["certificado"] = emisora.Certificado,
                ["empresa"] = empresa,
                ["serie"] = comprobante.Serie,
                ["numero"] = numero.ToString(),
                ["fecha_emision"] = hoy.ToString("yyyy-MM-dd"),
                ["moneda"] = "PEN",
                ["forma_pago"] = credito ? "credito" : "contado",
                ["cliente"] = new
                {
                    num_doc = cliente.Documento, rzn_social = cliente.Nombre, tipo_doc = cliente.TipoDoc,
                    direccion = cliente.Direccion ?? "-",
                },
                ["detalles"] = lineas.Select(DetalleApi).ToList(),
            };
            if (credito)
            {
                cuerpo["fecha_vencimiento"] = hoy.AddDays(_opciones.DiasCredito).ToString("yyyy-MM-dd");
                cuerpo["cuotas_credito"] = new[]
                {
                    new { fecha = hoy.AddDays(_opciones.DiasCredito).ToString("yyyy-MM-dd"), monto = totales.Total },
                };
            }
            AgregarTotales(cuerpo, totales);
            return await _factu.GenerarComprobanteAsync(cuerpo);
        });

        return await EnviarYResponderAsync(comprobante.Id);
    }

    // ----------------------------------------------------------- Crédito y débito

    public async Task<ComprobanteResponse> EmitirNotaAsync(int afectadoId, EmitirNotaRequest request)
    {
        if (request.Tipo is not (TipoCpe.NotaCredito or TipoCpe.NotaDebito))
            throw new BadRequestException("El tipo debe ser 07 (nota de crédito) o 08 (nota de débito)");

        var motivos = request.Tipo == TipoCpe.NotaCredito ? MotivosCredito : MotivosDebito;
        if (!motivos.Contains(request.CodMotivo))
            throw new BadRequestException("El motivo no es válido para este tipo de nota");
        if (string.IsNullOrWhiteSpace(request.DesMotivo))
            throw new BadRequestException("Escribe el motivo de la nota");

        var afectado = await ObtenerAsync(afectadoId);
        if (afectado.Tipo is not (TipoCpe.Factura or TipoCpe.Boleta))
            throw new BadRequestException("Solo se corrigen facturas y boletas");
        if (afectado.Estado != EstadoCpe.Aceptado)
            throw new BadRequestException("Solo se puede corregir un comprobante que SUNAT ya aceptó");

        List<LineaCpe> lineas;
        if (request.Lineas is { Count: > 0 })
        {
            lineas = request.Lineas.Select(l => new LineaCpe(l.Descripcion.Trim(), l.Cantidad, l.Precio, l.AfectoIgv, null)).ToList();
            if (lineas.Any(l => string.IsNullOrWhiteSpace(l.Descripcion) || l.Cantidad <= 0 || l.Precio <= 0))
                throw new BadRequestException("Cada línea necesita descripción, cantidad y precio mayores que cero");
        }
        else if (request.Tipo == TipoCpe.NotaCredito)
        {
            // Sin líneas: se repiten las del comprobante, que es la anulación o devolución total.
            lineas = LineasDe(afectado);
        }
        else
        {
            throw new BadRequestException("Una nota de débito necesita al menos una línea con el cargo");
        }

        var totales = Totales(lineas);

        // Entre todas las notas de crédito no se puede devolver más de lo que se facturó.
        if (request.Tipo == TipoCpe.NotaCredito)
        {
            var yaCorregido = await _context.ComprobantesElectronicos.AsNoTracking()
                .Where(c => c.AfectadoId == afectado.Id && c.Tipo == TipoCpe.NotaCredito && c.Estado != EstadoCpe.Rechazado)
                .SumAsync(c => (decimal?)c.Total) ?? 0m;
            if (yaCorregido + totales.Total > afectado.Total + 0.01m)
                throw new BadRequestException(
                    $"Las notas de crédito no pueden pasar de lo facturado ({afectado.Total:0.00}); ya se corrigió {yaCorregido:0.00}");
        }

        var emisora = await EmpresaAsync();
        var empresa = emisora.Api;
        var hoy = Zona.Hoy;
        var nota = new ComprobanteElectronico
        {
            Tipo = request.Tipo,
            AfectadoId = afectado.Id,
            NotaVentaId = afectado.NotaVentaId,
            ClienteId = afectado.ClienteId,
            FechaEmision = hoy,
            ClienteTipoDoc = afectado.ClienteTipoDoc,
            ClienteDocumento = afectado.ClienteDocumento,
            ClienteNombre = afectado.ClienteNombre,
            ClienteDireccion = afectado.ClienteDireccion,
            OpGravada = totales.Gravada,
            OpExonerada = totales.Exonerada,
            Igv = totales.Igv,
            Total = totales.Total,
            CodMotivo = request.CodMotivo,
            DesMotivo = request.DesMotivo.Trim(),
            DetalleJson = JsonSerializer.Serialize(lineas.Select(l => new LineaComprobanteResponse
            {
                Descripcion = l.Descripcion, Cantidad = l.Cantidad, Precio = l.Precio, AfectoIgv = l.AfectoIgv,
            }), Json),
            Entorno = emisora.Entorno,
            UsuarioId = _usuarioActual.Id,
        };

        await GenerarYGuardarAsync(nota, emisora.EmpresaId, afectado.Tipo, async numero =>
        {
            var cuerpo = new Dictionary<string, object?>
            {
                ["endpoint"] = emisora.Entorno,
                ["documento"] = TipoCpe.ParaApi(request.Tipo),
                ["certificado"] = emisora.Certificado,
                ["empresa"] = empresa,
                ["serie"] = nota.Serie,
                ["numero"] = numero.ToString(),
                ["fecha_emision"] = hoy.ToString("yyyy-MM-dd"),
                ["doc_afectado"] = TipoCpe.ParaApi(afectado.Tipo),
                ["serie_numero_afectado"] = afectado.NumeroCompleto,
                ["cod_motivo"] = request.CodMotivo,
                ["des_motivo"] = nota.DesMotivo,
                ["moneda"] = "PEN",
                ["cliente"] = new
                {
                    num_doc = nota.ClienteDocumento, rzn_social = nota.ClienteNombre, tipo_doc = nota.ClienteTipoDoc,
                    direccion = nota.ClienteDireccion ?? "-",
                },
                ["detalles"] = lineas.Select(DetalleApi).ToList(),
            };
            AgregarTotales(cuerpo, totales);
            return await _factu.GenerarNotaAsync(cuerpo);
        });

        return await EnviarYResponderAsync(nota.Id);
    }

    // ------------------------------------------------------------------ Reenvío

    public async Task<ComprobanteResponse> ReenviarAsync(int id)
    {
        var c = await ObtenerAsync(id);
        if (c.Estado is not (EstadoCpe.Generado or EstadoCpe.Error))
            throw new BadRequestException("Este comprobante ya tiene respuesta de SUNAT");

        return await EnviarYResponderAsync(id);
    }

    // ---------------------------------------------------------------- Descargas

    public async Task<(byte[] Contenido, string Nombre)> DescargarXmlAsync(int id)
    {
        var c = await ObtenerAsync(id);
        return (Encoding.UTF8.GetBytes(c.XmlFirmado), $"{c.NombreArchivo}.xml");
    }

    public async Task<(byte[] Contenido, string Nombre)> DescargarCdrAsync(int id)
    {
        var c = await ObtenerAsync(id);
        if (c.CdrZip is null || c.CdrZip.Length == 0)
            throw new NotFoundException("Este comprobante todavía no tiene CDR: SUNAT no ha respondido");

        return (c.CdrZip, $"R-{c.NombreArchivo}.zip");
    }

    // ------------------------------------------------------------------ Internos

    private IQueryable<ComprobanteElectronico> Consulta() =>
        _context.ComprobantesElectronicos.AsNoTracking()
            .Include(c => c.NotaVenta)
            .Include(c => c.Afectado)
            .Include(c => c.Usuario);

    private async Task<ComprobanteElectronico> ObtenerAsync(int id) =>
        await _context.ComprobantesElectronicos
            .Include(c => c.NotaVenta)
            .Include(c => c.Afectado)
            .Include(c => c.Usuario)
            .FirstOrDefaultAsync(c => c.Id == id)
        ?? throw new NotFoundException($"No existe el comprobante {id}");

    /// <summary>
    /// Toma el siguiente número de la serie, firma el XML con él y guarda el comprobante, todo en una transacción:
    /// si la firma falla el número no se gasta, y no quedan huecos en la numeración.
    /// </summary>
    private async Task GenerarYGuardarAsync(
        ComprobanteElectronico c, int empresaId, string? aplicaA, Func<int, Task<XmlGenerado>> generar)
    {
        await using var tx = await _context.Database.BeginTransactionAsync();

        var serie = await _context.SeriesCpe.AsNoTracking()
            .Where(s => s.EmpresaId == empresaId && s.Activa && s.Tipo == c.Tipo && s.AplicaA == aplicaA)
            .OrderBy(s => s.Id)
            .FirstOrDefaultAsync()
            ?? throw new BadRequestException(SinSerie(c.Tipo, aplicaA));

        // El número se toma con un UPDATE de la base: dos emisiones al mismo tiempo no pueden recibir el mismo.
        await _context.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE SeriesCpe SET UltimoNumero = UltimoNumero + 1 WHERE Id = {serie.Id}");
        var numero = await _context.SeriesCpe.AsNoTracking()
            .Where(s => s.Id == serie.Id).Select(s => s.UltimoNumero).SingleAsync();

        c.Serie = serie.Serie;
        c.Numero = numero;

        var xml = await generar(numero);
        c.NombreArchivo = xml.NombreArchivo;
        c.Hash = xml.Hash;
        c.QrInfo = xml.QrInfo;
        c.XmlFirmado = xml.Xml;
        c.Estado = EstadoCpe.Generado;

        _context.ComprobantesElectronicos.Add(c);
        await _context.SaveChangesAsync();
        await tx.CommitAsync();
    }

    /// <summary>
    /// Manda el XML a SUNAT y guarda lo que respondió. Si no hubo respuesta (red, SUNAT caído) el comprobante queda
    /// en Error y se puede reenviar: el XML ya está firmado y guardado.
    /// </summary>
    private async Task<ComprobanteResponse> EnviarYResponderAsync(int id)
    {
        var c = await ObtenerAsync(id);
        var emisora = await EmpresaAsync();

        // Un comprobante se manda al entorno con el que se firmó: cambiar el modo después no lo mueve de SUNAT.
        try
        {
            var r = await _factu.EnviarAsync(
                c.Entorno, emisora.Api.ruc, emisora.Api.usuario, emisora.Api.clave, c.NombreArchivo, c.XmlFirmado);
            c.EnviadoEn = DateTime.UtcNow;
            c.CodigoSunat = r.Codigo;
            c.MensajeSunat = Corto(r.Mensaje, 500);
            c.NotasSunat = r.Notas.Count > 0 ? Corto(string.Join('\n', r.Notas), 1000) : null;

            if (r.Recibida)
            {
                c.CdrZip = r.CdrZip;
                c.Estado = r.Aceptado ? EstadoCpe.Aceptado : EstadoCpe.Rechazado;
            }
            else
            {
                c.Estado = EstadoCpe.Error;
            }
        }
        catch (AppException e) when (e.StatusCode == StatusCodes.Status502BadGateway)
        {
            c.EnviadoEn = DateTime.UtcNow;
            c.Estado = EstadoCpe.Error;
            c.MensajeSunat = Corto(e.Message, 500);
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("comprobantes", "emitido", new { c.Id, c.Estado });

        return Mapear(c);
    }

    /// <summary>La empresa como la pide la API: los nombres van tal cual porque son los de su JSON.</summary>
    private record EmpresaApi(
        string ruc, string usuario, string clave, string razon_social, string nombreComercial,
        string direccion, string ubigeo, string distrito, string provincia, string departamento);

    /// <summary>La empresa activa, lista para emitir: con sus datos de SUNAT y el entorno que eligió.</summary>
    private record EmpresaEmisora(int EmpresaId, EmpresaApi Api, string Entorno, string Certificado);

    private static string SinSerie(string tipo, string? aplicaA)
    {
        var que = TipoCpe.Nombre(tipo).ToLowerInvariant();
        if (aplicaA is not null) que += aplicaA == TipoCpe.Factura ? " de facturas" : " de boletas";
        return $"La empresa no tiene una serie activa para {que}. Créala en Configuración > Empresas > Series";
    }

    private async Task<EmpresaEmisora> EmpresaAsync()
    {
        var e = await _context.Empresas.AsNoTracking().FirstOrDefaultAsync(x => x.Activa)
            ?? throw new BadRequestException("No hay una empresa activa: configúrala antes de facturar");
        if (e.Ruc.Length != 11)
            throw new BadRequestException("La empresa activa no tiene un RUC de 11 dígitos");

        // Sin estos datos SUNAT no recibe nada: se pide completarlos donde se configuran, no se inventan.
        var faltan = new List<string>();
        if (string.IsNullOrWhiteSpace(e.UsuarioSol)) faltan.Add("el usuario SOL");
        if (string.IsNullOrWhiteSpace(e.ClaveSol)) faltan.Add("la clave SOL");
        if (string.IsNullOrWhiteSpace(e.Ubigeo)) faltan.Add("el ubigeo");
        if (faltan.Count > 0)
            throw new BadRequestException(
                $"Falta {string.Join(", ", faltan)} de la empresa para facturar. Complétalo en Configuración > Empresas");

        // El certificado se guarda cifrado en la empresa y va a la API en cada emisión: ella no guarda ninguno.
        if (string.IsNullOrEmpty(e.CertificadoPem))
            throw new BadRequestException("La empresa no tiene certificado digital. Súbelo en Configuración > Empresas");
        var certificado = _protector.Desproteger(e.CertificadoPem)
            ?? throw new BadRequestException("No se pudo leer el certificado de la empresa. Vuelve a subirlo en Configuración > Empresas");

        var api = new EmpresaApi(e.Ruc, e.UsuarioSol!, e.ClaveSol!, e.RazonSocial, e.NombreComercial,
            e.Direccion ?? "-", e.Ubigeo!, e.Distrito ?? "-", e.Provincia ?? "-", e.Departamento ?? "-");
        return new EmpresaEmisora(e.Id, api, e.ModoPrueba ? "beta" : "produccion", certificado);
    }

    // ------------------------------------------------------------------- Cálculo

    private record LineaCpe(string Descripcion, decimal Cantidad, decimal Precio, bool AfectoIgv, string? Codigo);

    private record TotalesCpe(decimal Gravada, decimal Igv, decimal Exonerada, decimal Total);

    private static List<LineaCpe> LineasDe(ComprobanteElectronico c) =>
        (JsonSerializer.Deserialize<List<LineaComprobanteResponse>>(c.DetalleJson, Json) ?? [])
            .Select(l => new LineaCpe(l.Descripcion, l.Cantidad, l.Precio, l.AfectoIgv, null))
            .ToList();

    /// <summary>
    /// Separa lo cobrado en base gravada + IGV + exonerado, igual que la nota de venta: cada línea ya trae el IGV
    /// incluido si es afecta, así que no se agrega plata, solo se desglosa.
    /// </summary>
    private static TotalesCpe Totales(IEnumerable<LineaCpe> lineas)
    {
        var gravadoConIgv = lineas.Where(l => l.AfectoIgv).Sum(l => l.Cantidad * l.Precio);
        var exonerado = lineas.Where(l => !l.AfectoIgv).Sum(l => l.Cantidad * l.Precio);

        var gravada = Math.Round(gravadoConIgv / (1 + Impuestos.TasaIgv), 2);
        var igv = Math.Round(gravadoConIgv - gravada, 2);
        var exo = Math.Round(exonerado, 2);
        return new TotalesCpe(gravada, igv, exo, gravada + igv + exo);
    }

    /// <summary>
    /// Los totales ya redondeados se mandan a la API: así el comprobante dice lo mismo que la venta y no lo que
    /// saldría de volver a dividir cada línea entre 1.18.
    /// </summary>
    private static void AgregarTotales(Dictionary<string, object?> cuerpo, TotalesCpe t)
    {
        cuerpo["total"] = t.Total;
        cuerpo["mtoOperGravadas"] = t.Gravada;
        cuerpo["mtoIGV"] = t.Igv;
        cuerpo["totalImpuestos"] = t.Igv;
        cuerpo["valorVenta"] = t.Gravada + t.Exonerada;
        cuerpo["subTotal"] = t.Total;
        cuerpo["mtoImpVenta"] = t.Total;
        if (t.Exonerada > 0) cuerpo["mtoOperExoneradas"] = t.Exonerada;
    }

    private static object DetalleApi(LineaCpe l, int indice) => new
    {
        cod_producto = string.IsNullOrWhiteSpace(l.Codigo) ? (indice + 1).ToString() : l.Codigo,
        cod_sunat = "",
        unidad = "NIU",
        descripcion = l.Descripcion,
        cantidad = l.Cantidad,
        precio = l.Precio,
        tipo_igv = l.AfectoIgv ? "gravado" : "exonerado",
    };

    private static string Descripcion(NotaVentaDetalle d)
    {
        var nombre = d.Producto?.Nombre ?? "PRODUCTO";
        var presentacion = d.Presentacion;
        // "ACEITE 1L - Caja x12": la presentación dice cómo se vendió. Si es la unidad base no agrega nada.
        return presentacion is not null && presentacion.Factor != 1m ? $"{nombre} - {presentacion.Nombre}" : nombre;
    }

    private record ClienteCpe(string TipoDoc, string Documento, string Nombre, string? Direccion);

    /// <summary>
    /// El cliente como lo pide SUNAT. La factura exige RUC. La boleta acepta DNI o RUC, y bajo S/ 700 también
    /// "clientes varios" (sin documento).
    /// </summary>
    private static ClienteCpe ClienteDe(Cliente c, string tipo, decimal total)
    {
        var documento = c.Documento?.Trim() ?? string.Empty;
        var esRuc = c.TipoDoc == TipoDocumento.Ruc && documento.Length == 11 && documento.All(char.IsDigit);
        var esDni = c.TipoDoc == TipoDocumento.Dni && documento.Length == 8 && documento.All(char.IsDigit);

        if (tipo == TipoCpe.Factura)
        {
            if (!esRuc) throw new BadRequestException("Para emitir una factura el cliente necesita un RUC de 11 dígitos");
            return new ClienteCpe("6", documento, c.Nombre, c.Direccion);
        }

        if (esDni) return new ClienteCpe("1", documento, c.Nombre, c.Direccion);
        if (esRuc) return new ClienteCpe("6", documento, c.Nombre, c.Direccion);

        if (total >= MontoBoletaConDocumento)
            throw new BadRequestException($"Una boleta desde S/ {MontoBoletaConDocumento:0} necesita el DNI del cliente");

        return new ClienteCpe("0", "-", "CLIENTES VARIOS", null);
    }

    private static string? Corto(string? texto, int largo) =>
        texto is null ? null : texto.Length <= largo ? texto : texto[..largo];

    private static ComprobanteResponse Mapear(ComprobanteElectronico c) => new()
    {
        Id = c.Id,
        Tipo = c.Tipo,
        TipoNombre = TipoCpe.Nombre(c.Tipo),
        Serie = c.Serie,
        Numero = c.Numero,
        NumeroCompleto = c.NumeroCompleto,
        NotaVentaId = c.NotaVentaId,
        NotaVentaNumero = c.NotaVenta?.Numero,
        AfectadoId = c.AfectadoId,
        AfectadoNumero = c.Afectado?.NumeroCompleto,
        FechaEmision = c.FechaEmision,
        ClienteTipoDoc = c.ClienteTipoDoc,
        ClienteDocumento = c.ClienteDocumento,
        ClienteNombre = c.ClienteNombre,
        Moneda = c.Moneda,
        OpGravada = c.OpGravada,
        OpExonerada = c.OpExonerada,
        Igv = c.Igv,
        Total = c.Total,
        CodMotivo = c.CodMotivo,
        DesMotivo = c.DesMotivo,
        Estado = c.Estado,
        CodigoSunat = c.CodigoSunat,
        MensajeSunat = c.MensajeSunat,
        NotasSunat = c.NotasSunat,
        NombreArchivo = c.NombreArchivo,
        Hash = c.Hash,
        QrInfo = c.QrInfo,
        TieneCdr = c.CdrZip is { Length: > 0 },
        Entorno = c.Entorno,
        Usuario = c.Usuario?.Nombre,
        FechaCreacion = c.FechaCreacion,
        EnviadoEn = c.EnviadoEn,
        Lineas = JsonSerializer.Deserialize<List<LineaComprobanteResponse>>(c.DetalleJson, Json) ?? [],
    };
}
