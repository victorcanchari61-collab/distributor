using Backend.Dtos.Responses;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using Backend.Service.Pdf;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Implementacion;

/// <summary>
/// Arma los PDF a partir de lo que ya devuelven los servicios de venta y de
/// compra.
///
/// No recalcula ni un total: pide el documento tal como lo ve la pantalla y lo
/// dibuja. Si el PDF hiciera sus propias sumas habría dos fuentes de la verdad
/// y, tarde o temprano, un papel que no cuadra con el sistema.
/// </summary>
public class PdfService(
    IVentasService ventas,
    IComprasService compras,
    IEmpresaService empresas,
    IClienteRepository clientes,
    IProveedorRepository proveedores) : IPdfService
{
    /// <summary>
    /// Lo que hay que decir en un papel que no es comprobante de pago.
    ///
    /// Ante SUNAT solo lo son la factura y la boleta. Quien recibe una nota de
    /// venta tiene derecho a saber que no le sirve para sustentar gasto, y
    /// enterarse por el propio papel y no al presentarlo.
    /// </summary>
    private const string AvisoNoTributario =
        "Este documento no es un comprobante de pago electrónico. No sustenta crédito fiscal ni gasto ante SUNAT.";

    public async Task<(byte[], string)> PedidoAsync(int id, FormatoPdf formato)
    {
        var pedido = await ventas.GetPedidoAsync(id);
        var cliente = await clientes.GetByIdAsync(pedido.ClienteId);
        var empresa = await empresas.GetActivaAsync();

        var datos = new List<DatoImprimible>();
        if (pedido.ListaPrecio is { Length: > 0 } lista)
            datos.Add(new DatoImprimible("Lista de precios", lista));
        if (pedido.Almacen is { Length: > 0 } almacen)
            datos.Add(new DatoImprimible("Almacén", almacen));

        var doc = new DocumentoImprimible
        {
            Titulo = "PEDIDO",
            Numero = pedido.Numero,
            Fecha = pedido.Fecha,
            Anulado = pedido.Estado == "ANULADO",
            EtiquetaParte = "Cliente",
            ParteNombre = pedido.Cliente,
            ParteDocumento = cliente?.Documento,
            ParteDireccion = cliente?.Direccion,
            ParteTelefono = cliente?.Telefono,
            Datos = datos,
            EtiquetaImporte = "Precio",
            // Una linea quitada al editar el pedido se conserva marcada, no se
            // borra. En el papel no pinta nada: se pidio lo que queda.
            Lineas = [.. pedido.Detalle.Where(l => !l.Anulado).Select(Linea)],
            Total = pedido.Total,
            Observacion = pedido.Observacion,
            Usuario = pedido.Usuario,
            Empresa = empresa,
            Aviso = AvisoNoTributario,
        };

        return (Generar(doc, formato), Nombre("pedido", pedido.Numero, formato));
    }

    public async Task<(byte[], string)> NotaVentaAsync(int id, FormatoPdf formato)
    {
        var venta = await ventas.GetNotaVentaAsync(id);
        var cliente = await clientes.GetByIdAsync(venta.ClienteId);
        var empresa = await empresas.GetActivaAsync();

        var datos = new List<DatoImprimible>
        {
            new("Forma de pago", venta.FormaPago == "CREDITO" ? "Crédito" : "Contado"),
            new("Almacén", venta.Almacen),
        };
        if (venta.PedidoNumero is { Length: > 0 } pedido)
            datos.Add(new DatoImprimible("Pedido", pedido));

        var doc = new DocumentoImprimible
        {
            Titulo = "NOTA DE VENTA",
            Numero = venta.Numero,
            Fecha = venta.Fecha,
            Anulado = venta.Estado == "ANULADA",
            EtiquetaParte = "Cliente",
            ParteNombre = venta.Cliente,
            ParteDocumento = cliente?.Documento,
            ParteDireccion = cliente?.Direccion,
            ParteTelefono = cliente?.Telefono,
            Datos = datos,
            EtiquetaImporte = "Precio",
            Lineas = [.. venta.Detalle.Where(l => !l.Anulado).Select(Linea)],
            Total = venta.Total,
            // Un pago anulado no se cobro: sumarlo diria que esta pagada.
            Pagos = [.. venta.Pagos.Where(p => !p.Anulado).Select(p => new PagoImprimible(p.MetodoPago, p.Monto))],
            TotalPagado = venta.TotalPagado,
            Observacion = venta.Observacion,
            Usuario = venta.Usuario,
            Empresa = empresa,
            Aviso = AvisoNoTributario,
        };

        return (Generar(doc, formato), Nombre("nota-venta", venta.Numero, formato));
    }

    public async Task<(byte[], string)> OrdenCompraAsync(int id, FormatoPdf formato)
    {
        var orden = await compras.GetOrdenAsync(id);
        var proveedor = await proveedores.GetByIdAsync(orden.ProveedorId);
        var empresa = await empresas.GetActivaAsync();

        var datos = new List<DatoImprimible>();
        if (orden.FechaEsperada is { } esperada)
            datos.Add(new DatoImprimible("Entrega esperada", esperada.ToString("dd/MM/yyyy")));

        var doc = new DocumentoImprimible
        {
            Titulo = "ORDEN DE COMPRA",
            Numero = orden.Numero,
            Fecha = orden.Fecha,
            Anulado = orden.Estado == "ANULADA",
            EtiquetaParte = "Proveedor",
            ParteNombre = orden.Proveedor,
            ParteDocumento = proveedor?.Documento,
            ParteDireccion = proveedor?.Direccion,
            ParteTelefono = proveedor?.Telefono,
            Datos = datos,
            EtiquetaImporte = "Costo",
            Lineas =
            [
                .. orden.Detalle.Select(l => new LineaImprimible(
                    l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal)),
            ],
            Total = orden.Total,
            Observacion = orden.Observacion,
            Usuario = orden.Usuario,
            Empresa = empresa,
            // Una orden de compra la emitimos nosotros hacia el proveedor: no
            // pretende ser comprobante de nada, el aviso sobraria.
        };

        return (Generar(doc, formato), Nombre("orden-compra", orden.Numero, formato));
    }

    public async Task<(byte[], string)> CompraAsync(int id, FormatoPdf formato)
    {
        var compra = await compras.GetCompraAsync(id);
        var proveedor = await proveedores.GetByIdAsync(compra.ProveedorId);
        var empresa = await empresas.GetActivaAsync();

        var datos = new List<DatoImprimible>
        {
            new("Forma de pago", compra.FormaPago == "CREDITO" ? "Crédito" : "Contado"),
        };

        // El comprobante que nos dio el proveedor: esto es nuestra copia
        // interna de su factura, y sin ese numero no se puede casar con ella.
        var comprobante = Textos.Juntar(
            "-", compra.SerieComprobante, compra.NumeroComprobante);
        if (comprobante is not null)
            datos.Add(new DatoImprimible(compra.TipoComprobante, comprobante));
        if (compra.OrdenCompraNumero is { Length: > 0 } orden)
            datos.Add(new DatoImprimible("Orden", orden));

        var doc = new DocumentoImprimible
        {
            Titulo = "COMPRA",
            Numero = compra.Numero,
            Fecha = compra.Fecha,
            Anulado = compra.Estado == "ANULADA",
            EtiquetaParte = "Proveedor",
            ParteNombre = compra.Proveedor,
            ParteDocumento = proveedor?.Documento,
            ParteDireccion = proveedor?.Direccion,
            ParteTelefono = proveedor?.Telefono,
            Datos = datos,
            EtiquetaImporte = "Costo",
            Lineas =
            [
                .. compra.Detalle.Select(l => new LineaImprimible(
                    l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal)),
            ],
            Total = compra.Total,
            Pagos = [.. compra.Pagos.Where(p => !p.Anulado).Select(p => new PagoImprimible(p.MetodoPago, p.Monto))],
            TotalPagado = compra.TotalPagado,
            Observacion = compra.Observacion,
            Usuario = compra.Usuario,
            Empresa = empresa,
        };

        return (Generar(doc, formato), Nombre("compra", compra.Numero, formato));
    }

    private static LineaImprimible Linea(LineaVentaResponse l) =>
        new(l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.PrecioUnitario, l.Subtotal);

    private static byte[] Generar(DocumentoImprimible doc, FormatoPdf formato)
    {
        IDocument documento = formato == FormatoPdf.Ticket
            ? new DocumentoTicket(doc)
            : new DocumentoA4(doc);

        return documento.GeneratePdf();
    }

    /// <summary>
    /// El nombre con el que se guarda: "nota-venta-NV-0001.pdf".
    ///
    /// Lleva el número dentro porque al final del día hay quince en la carpeta
    /// de descargas, y "documento(7).pdf" no se busca.
    /// </summary>
    private static string Nombre(string tipo, string numero, FormatoPdf formato)
    {
        var limpio = string.Concat(numero.Select(c => char.IsLetterOrDigit(c) ? c : '-'));
        var sufijo = formato == FormatoPdf.Ticket ? "-ticket" : "";
        return $"{tipo}-{limpio}{sufijo}.pdf";
    }
}
