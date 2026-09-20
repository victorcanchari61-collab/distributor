using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
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
    IDespachoService despachos,
    INovedadService novedades,
    IEmpresaService empresas,
    IClienteRepository clientes,
    IProveedorRepository proveedores) : IPdfService
{
    public async Task<(byte[], string)> PedidoAsync(int id, FormatoPdf formato)
    {
        var doc = await ArmarPedidoAsync(id);

        /*
         * Tres formatos, no dos: la hoja de siempre, el ticket, y la hoja con
         * las dos copias.
         *
         * El de dos copias NO reemplaza al normal — se suma. El papel del
         * pedido se entrega y se pierde, y para reponerlo hacen falta otra vez
         * los dos, el del cliente y el que vuelve firmado; pero para archivar
         * o consultar sigue sirviendo la hoja simple.
         */
        var contenido = formato switch
        {
            FormatoPdf.Copias => new PedidosLoteA4([doc]).GeneratePdf(),
            FormatoPdf.Ticket => Generar(doc, formato),
            // La hoja vertical del pedido usa el mismo dibujo que la de dos
            // copias, no la maqueta generica: son el mismo documento.
            _ => new PedidoA4(doc).GeneratePdf(),
        };

        return (contenido, Nombre("pedido", doc.Numero, formato));
    }

    /// <summary>
    /// El pedido listo para dibujar.
    ///
    /// Está aparte porque lo usan dos caminos: el pedido suelto y el lote de
    /// dos copias por hoja. Si cada uno lo armara por su cuenta, un cambio en
    /// la cabecera saldría en un papel y no en el otro.
    /// </summary>
    private async Task<DocumentoImprimible> ArmarPedidoAsync(int id)
    {
        var pedido = await ventas.GetPedidoAsync(id);
        var cliente = await clientes.GetByIdAsync(pedido.ClienteId);
        var empresa = await empresas.GetActivaAsync();

        /*
         * La condicion va primero.
         *
         * Es lo que el repartidor mira al llegar: si deja la mercaderia solo
         * contra el dinero o si va fiada. Con el papel en la mano no hay
         * sistema que consultar, asi que si no esta impreso no existe.
         */
        var datos = new List<DatoImprimible>
        {
            new("Condición de pago", pedido.CondicionPago == "CREDITO" ? "CRÉDITO" : "CONTADO"),
        };

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
            EtiquetaUsuario = "VENDEDOR",
            Empresa = empresa,
        };

        return doc;
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
            EtiquetaUsuario = "VENDEDOR",
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
                .. orden.Detalle.Select(LineaCompra),
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
                .. compra.Detalle.Select(LineaCompra),
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

    public async Task<(byte[], string)> DespachoAsync(int id)
    {
        var despacho = await despachos.GetAsync(id);

        var docs = new List<DocumentoImprimible>();
        foreach (var pedido in despacho.Detalle)
        {
            docs.Add(await ArmarPedidoAsync(pedido.PedidoId));
        }

        if (docs.Count == 0) throw new BadRequestException("Este despacho no tiene pedidos");

        var contenido = new PedidosLoteA4(docs).GeneratePdf();
        return (contenido, Nombre("despacho", despacho.Numero, FormatoPdf.A4));
    }

    public async Task<(byte[], string)> DetalleClientesDespachoAsync(int id)
    {
        var despacho = await despachos.GetAsync(id);
        if (despacho.Detalle.Count == 0) throw new BadRequestException("Este despacho no tiene pedidos");

        var contenido = new DetalleClientesA4(despacho).GeneratePdf();
        return (contenido, Nombre("detalle-clientes", despacho.Numero, FormatoPdf.A4));
    }

    public async Task<(byte[], string)> CargaDespachoAsync(
        int id, IReadOnlyCollection<int>? mercados, IReadOnlyCollection<string>? unidades, bool porMercado,
        int? corte = null)
    {
        var despacho = await despachos.GetAsync(id);
        if (despacho.Detalle.Count == 0) throw new BadRequestException("Este despacho no tiene pedidos");

        // Sin corte (o 0) sale todo el camión, como siempre.
        var conCorte = corte is int c && CortesCarga.EsValido(c);

        List<LineaCargaResponse> todas;
        DateTime? diaCarga = null;
        if (conCorte)
        {
            var resultado = await despachos.LineasCargaCorteAsync(id, corte!.Value);
            todas = resultado.Lineas;
            diaCarga = resultado.DiaCarga;
        }
        else
        {
            todas = await despachos.LineasCargaAsync(id);
        }

        var lineas = todas
            .Where(l => mercados is null || mercados.Count == 0 || mercados.Contains(l.MercadoId))
            .Where(l => unidades is null || unidades.Count == 0
                        || unidades.Contains(l.UnidadCodigo, StringComparer.OrdinalIgnoreCase))
            .ToList();

        // Lo que se filtró, dicho con los nombres y no con los ids.
        var partes = new List<string>();

        // El corte primero, con el día de carga que se tomó: un papel de
        // aumentos que no dice de qué día es no se puede comprobar.
        if (conCorte)
            partes.Add($"{CortesCarga.Nombre(corte!.Value)}   ·   día de carga {diaCarga:dd/MM/yyyy}");

        if (mercados is { Count: > 0 })
            partes.Add("Mercado " + string.Join(", ", todas
                .Where(l => mercados.Contains(l.MercadoId))
                .Select(l => l.Mercado).Distinct()));
        if (unidades is { Count: > 0 })
            partes.Add(string.Join(", ", todas
                .Where(l => unidades.Contains(l.UnidadCodigo, StringComparer.OrdinalIgnoreCase))
                .Select(l => l.UnidadNombre).Distinct()));

        var contenido = new CargaDespachoA4(
            despacho, lineas, partes.Count == 0 ? null : string.Join("   ·   ", partes), porMercado,
            aumentos: conCorte && CortesCarga.EsAumento(corte!.Value)).GeneratePdf();
        return (contenido, Nombre("carga", conCorte ? $"{despacho.Numero}-corte{corte}" : despacho.Numero, FormatoPdf.A4));
    }

    public async Task<(byte[], string)> NovedadesAsync(ConsultaTablaRequest consulta)
    {
        // Sin tope de página: el papel es todo lo que ve el filtro, no un trozo.
        var (filas, total) = await novedades.ExportarAsync(consulta);

        var contenido = new NovedadesA4(
            filas, total, DescribirFiltrosNovedades(consulta), Zona.ALocal(DateTime.UtcNow)).GeneratePdf();

        return (contenido, $"novedades-{Zona.Hoy:yyyy-MM-dd}.pdf");
    }

    /// <summary>
    /// Lo que se filtró, dicho con palabras: la hoja tiene que decir de qué es
    /// un recorte, o pasa por el total de todo.
    /// </summary>
    private static string? DescribirFiltrosNovedades(ConsultaTablaRequest consulta)
    {
        var partes = new List<string>();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
            partes.Add($"búsqueda «{consulta.Buscar.Trim()}»");

        foreach (var filtro in consulta.Filtros)
        {
            if (string.IsNullOrWhiteSpace(filtro.Valor) && string.IsNullOrWhiteSpace(filtro.ValorHasta)) continue;

            if (filtro.Columna == "fecha")
            {
                partes.Add(string.IsNullOrWhiteSpace(filtro.ValorHasta)
                    ? $"desde el {Dia(filtro.Valor)}"
                    : string.IsNullOrWhiteSpace(filtro.Valor)
                        ? $"hasta el {Dia(filtro.ValorHasta)}"
                        : $"del {Dia(filtro.Valor)} al {Dia(filtro.ValorHasta)}");
                continue;
            }

            var etiqueta = filtro.Columna switch
            {
                "producto" => "Producto",
                "pedido" => "Pedido",
                "cliente" => "Cliente",
                "despacho" => "Despacho",
                "motivo" => "Motivo",
                "tipo" => "Qué pasó",
                "estado" => "Estado",
                _ => filtro.Columna,
            };

            var valor = filtro.Columna switch
            {
                "tipo" => filtro.Valor switch
                {
                    TipoNovedad.Linea => "Entregado en menos",
                    TipoNovedad.Pedido => "Pedido sin entregar",
                    _ => filtro.Valor,
                },
                "estado" => filtro.Valor switch
                {
                    EstadoNovedad.Pendiente => "Por revisar",
                    EstadoNovedad.Recibida => "Recibida",
                    EstadoNovedad.Faltante => "Faltante",
                    EstadoNovedad.SinRetorno => "Sin retorno",
                    EstadoNovedad.Anulada => "Anulada",
                    _ => filtro.Valor,
                },
                _ => filtro.Valor,
            };

            partes.Add($"{etiqueta} {valor}");
        }

        return partes.Count == 0 ? null : string.Join("   ·   ", partes);
    }

    /// <summary>Un día como lo manda el panel (yyyy-MM-dd), escrito dd/MM/yyyy.</summary>
    private static string Dia(string? valor) =>
        DateTime.TryParse(valor, System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.None, out var d)
            ? d.ToString("dd/MM/yyyy")
            : valor ?? string.Empty;

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
                .. prestamo.Detalle.Select(l => l.PrecioPorPresentacion && l.CantidadPresentacion > 0
                    ? new LineaImprimible(
                        l.Codigo, l.Producto, l.Presentacion, l.CantidadPresentacion,
                        l.Presentacion ?? l.UnidadBase, Math.Round(l.CostoTotal / l.CantidadPresentacion, 2), l.CostoTotal)
                    : new LineaImprimible(
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
            throw new NotFoundException($"El documento {id} no es una {nombre}.");

        return doc;
    }

    /*
     * Lo que costo cada saco, sacado del total de la linea.
     *
     * La compra guarda el costo por unidad base y no el pactado —eso solo se
     * arreglo en ventas—, asi que aqui se deduce dividiendo el importe entre
     * las presentaciones: da el mismo numero sin arrastrar el redondeo de la
     * division por el factor.
     */
    /*
     * Una línea de compra, por unidad base o por presentación según el marcador de la presentación.
     *
     * Sin marcar sale en unidad base ("125 KG × 5.60"); marcada, por lo que se compró ("5 × ½ saco
     * a 140.00"). El importe es el mismo en los dos casos.
     */
    private static LineaImprimible LineaCompra(LineaCompraResponse l) =>
        l.PrecioPorPresentacion && l.CantidadPresentacion > 0
            ? new(l.Codigo, l.Producto, l.Presentacion, l.CantidadPresentacion,
                l.Presentacion ?? l.UnidadBase, CostoPorPresentacion(l), l.CostoTotal)
            : new(l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal);

    private static LineaImprimible LineaCompra(CompraDetalleResponse l) =>
        l.PrecioPorPresentacion && l.CantidadPresentacion > 0
            ? new(l.Codigo, l.Producto, l.Presentacion, l.CantidadPresentacion,
                l.Presentacion ?? l.UnidadBase, CostoPorPresentacion(l), l.CostoTotal)
            : new(l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal);

    private static decimal CostoPorPresentacion(LineaCompraResponse l) =>
        l.CantidadPresentacion == 0 ? 0 : Math.Round(l.CostoTotal / l.CantidadPresentacion, 2);

    private static decimal CostoPorPresentacion(CompraDetalleResponse l) =>
        l.CantidadPresentacion == 0 ? 0 : Math.Round(l.CostoTotal / l.CantidadPresentacion, 2);

    /*
     * Una línea de inventario, por unidad base o por presentación según el marcador de la
     * presentación.
     *
     * Por unidad base sale "1,800 × 6.92", que sirve para el stock pero no lo reconoce quien
     * contó "150 cajas". Con el marcador puesto sale "150 × 83.00" y el importe no cambia. Solo
     * vale si la línea se hizo en esa presentación: una cantidad en unidad base no se puede
     * repartir en cajas sin inventarse decimales.
     */
    private static LineaImprimible LineaInventario(LineaDocumentoResponse l) =>
        l.PrecioPorPresentacion && l.CantidadPresentacion > 0
            ? new(l.Codigo, l.Producto, l.Presentacion, l.CantidadPresentacion,
                l.Presentacion ?? l.UnidadBase, Math.Round(l.CostoTotal / l.CantidadPresentacion, 2), l.CostoTotal)
            : new(l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.CostoUnitario, l.CostoTotal);

    /*
     * La linea, tal como se vendio.
     *
     * Por defecto sale en unidad base ("250 KG × 5.90"). Si la presentacion lleva el marcador "Por
     * presentacion (PDF)", sale con la cantidad y el precio de la PRESENTACION —"5 sacos a 295.00"—,
     * que es lo que el cliente pidio: el marcador se enciende en las que se venden asi. El importe no
     * cambia; la unidad base sigue guardada para el stock y los margenes.
     */
    private static LineaImprimible Linea(LineaVentaResponse l) =>
        l.PrecioPorPresentacion
            ? new(l.Codigo, l.Producto, l.Presentacion, l.CantidadPresentacion,
                l.Presentacion ?? l.UnidadBase, l.PrecioPresentacion, l.Subtotal)
            : new(l.Codigo, l.Producto, l.Presentacion, l.Cantidad, l.UnidadBase, l.PrecioUnitario, l.Subtotal);

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
        var sufijo = formato switch
        {
            FormatoPdf.Ticket => "-ticket",
            FormatoPdf.Copias => "-copias",
            _ => "",
        };
        return $"{tipo}-{limpio}{sufijo}.pdf";
    }
}
