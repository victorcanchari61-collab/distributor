using Backend.Dtos.Responses;
using Backend.Models;
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
    IInventarioService inventario,
    IEmpresaService empresas,
    IClienteRepository clientes,
    IProveedorRepository proveedores) : IPdfService
{
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
            // El pedido lo firma el cliente en su puesto: el codigo interno del
            // producto no le dice nada y le quita ancho a la descripcion.
            MostrarCodigo = false,
            // Una linea quitada al editar el pedido se conserva marcada, no se
            // borra. En el papel no pinta nada: se pidio lo que queda.
            Lineas = [.. pedido.Detalle.Where(l => !l.Anulado).Select(Linea)],
            Total = pedido.Total,
            Observacion = pedido.Observacion,
            Usuario = pedido.Usuario,
            Empresa = empresa,
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

    // --- Inventario: mercadería que se mueve y alguien tiene que firmar ---

    public async Task<(byte[], string)> AjusteAsync(int id, FormatoPdf formato)
    {
        var ajuste = await DocumentoDeTipo(id, TipoDocumentoInventario.Ajuste, "ajuste");

        var doc = Base(ajuste, await empresas.GetActivaAsync()) with
        {
            Titulo = "AJUSTE DE INVENTARIO",
            // Un ajuste no va dirigido a nadie: lo que hay que ver arriba es
            // POR QUE se movio el stock, que es lo que se autoriza.
            EtiquetaParte = "Motivo",
            ParteNombre = ajuste.Motivo,
            Datos = [new DatoImprimible("Almacén", ajuste.Almacen)],
        };

        return (Generar(doc, formato), Nombre("ajuste", ajuste.Numero, formato));
    }

    public async Task<(byte[], string)> TransferenciaAsync(int id, FormatoPdf formato)
    {
        var envio = await DocumentoDeTipo(id, TipoDocumentoInventario.Transferencia, "transferencia");

        var doc = Base(envio, await empresas.GetActivaAsync()) with
        {
            Titulo = "TRANSFERENCIA",
            EtiquetaParte = "Almacén destino",
            ParteNombre = envio.AlmacenDestino ?? "—",
            Datos = [new DatoImprimible("Almacén origen", envio.Almacen)],
            /*
             * Solo las lineas de SALIDA.
             *
             * Una transferencia guarda cada producto dos veces — sale de un
             * almacen y entra en el otro — y sin este filtro el papel diria el
             * doble de lo que de verdad viaja en la camioneta.
             */
            Lineas =
            [
                .. envio.Detalle
                    .Where(l => l.Tipo == TipoMovimiento.Salida)
                    .Select(LineaInventario),
            ],
        };

        return (Generar(doc, formato), Nombre("transferencia", envio.Numero, formato));
    }

    public async Task<(byte[], string)> RecepcionAsync(int id, FormatoPdf formato)
    {
        var recepcion = await DocumentoDeTipo(id, TipoDocumentoInventario.Recepcion, "recepción");

        var datos = new List<DatoImprimible> { new("Almacén", recepcion.Almacen) };

        // Quien firma que la mercaderia llego necesita saber de QUIEN vino, y
        // el proveedor no viaja en el documento de inventario: esta en la
        // compra que lo origino.
        string parte = recepcion.Compra ?? "—";
        if (recepcion.CompraId is { } compraId)
        {
            var compra = await compras.GetCompraAsync(compraId);
            parte = compra.Proveedor;
            datos.Insert(0, new DatoImprimible("Compra", compra.Numero));
        }

        var doc = Base(recepcion, await empresas.GetActivaAsync()) with
        {
            Titulo = "RECEPCIÓN",
            EtiquetaParte = "Proveedor",
            ParteNombre = parte,
            Datos = datos,
        };

        return (Generar(doc, formato), Nombre("recepcion", recepcion.Numero, formato));
    }

    public async Task<(byte[], string)> PrestamoAsync(int id, FormatoPdf formato)
    {
        var prestamo = await inventario.GetPrestamoAsync(id);
        var empresa = await empresas.GetActivaAsync();

        var dado = prestamo.Tipo == "DADO";

        var doc = new DocumentoImprimible
        {
            Titulo = dado ? "PRÉSTAMO ENTREGADO" : "PRÉSTAMO RECIBIDO",
            Numero = prestamo.Numero,
            Fecha = prestamo.Fecha,
            // Un prestamo no se anula: se devuelve. El estado va como un dato
            // mas, que es lo que de verdad se consulta en el papel.
            EtiquetaParte = dado ? "Prestado a" : "Recibido de",
            ParteNombre = prestamo.Contraparte,
            Datos =
            [
                new DatoImprimible("Almacén", prestamo.Almacen),
                new DatoImprimible("Estado", prestamo.Estado == "DEVUELTO" ? "Devuelto" : "Pendiente"),
            ],
            EtiquetaImporte = "Costo",
            Lineas =
            [
                .. prestamo.Detalle.Select(l => new LineaImprimible(
                    l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal)),
            ],
            Total = prestamo.Total,
            Observacion = prestamo.Observacion,
            Usuario = prestamo.Usuario,
            Empresa = empresa,
        };

        return (Generar(doc, formato), Nombre("prestamo", prestamo.Numero, formato));
    }

    /// <summary>
    /// Lo común de un documento de inventario, que cada tipo completa.
    ///
    /// Los cuatro comparten forma en el backend, así que lo único que cambia
    /// es el título y a quién va dirigido.
    /// </summary>
    private static DocumentoImprimible Base(DocumentoInventarioResponse d, EmpresaResponse empresa) =>
        new()
        {
            Titulo = d.Tipo,
            Numero = d.Numero,
            Fecha = d.Fecha,
            Anulado = d.Estado == "ANULADO",
            EtiquetaParte = "Almacén",
            ParteNombre = d.Almacen,
            EtiquetaImporte = "Costo",
            Lineas = [.. d.Detalle.Select(LineaInventario)],
            Total = d.Total,
            Observacion = d.Observacion,
            Usuario = d.Usuario,
            Empresa = empresa,
        };

    /// <summary>
    /// Trae el documento y comprueba que sea del tipo que promete la ruta.
    ///
    /// Los cuatro viven en la misma tabla y comparten numeración de id, así
    /// que sin esto se podría pedir un ajuste por la ruta de transferencias y
    /// el permiso que se exigiría sería el equivocado.
    /// </summary>
    private async Task<DocumentoInventarioResponse> DocumentoDeTipo(int id, string tipo, string nombre)
    {
        var doc = await inventario.GetDocumentoAsync(id);
        if (doc.Tipo != tipo)
            throw new KeyNotFoundException($"El documento {id} no es una {nombre}.");

        return doc;
    }

    private static LineaImprimible LineaInventario(LineaDocumentoResponse l) =>
        new(l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal);

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
