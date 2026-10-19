using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Pedidos y reparto: los pedidos tomados en las fechas (por pedido, ruta, vendedor, cliente o
/// día) y las novedades de entrega —lo que no llegó y por qué—.
///
/// Con el mismo alcance que el gráfico: quien solo ve lo suyo, ve sus pedidos; y las novedades
/// solo salen si tiene permiso de verlas.
/// </summary>
public partial class ReportesService
{
    private async Task<ReporteResponse> RepartoAsync(ReporteRequest request)
    {
        var (primero, ultimo) = Rango(request);
        var inicio = Zona.AUtc(primero);
        var fin = Zona.AUtc(ultimo.AddDays(1));

        var uid = usuarioActual.Id;
        var alcance = uid is int u ? await permisos.AlcanceFiltroAsync(u, "fact.pedidos") : null;
        var veNovedades = uid is int u2 && await permisos.PuedeAsync(u2, "tms.novedades", Accion.Ver);

        List<VistaReporte> vistas =
        [
            V("pedido", "Por pedido"), V("ruta", "Por ruta"), V("vendedor", "Por vendedor"),
            V("cliente", "Por cliente"), V("dia", "Por día"),
        ];
        if (veNovedades) vistas.AddRange([V("novedades", "Novedades"), V("motivo", "Novedades por motivo")]);
        var vista = VistaDe(request, vistas);

        var consulta = context.Pedidos.Where(p => p.Fecha >= inicio && p.Fecha < fin);
        if (alcance is { SinRestriccion: false })
        {
            var rutas = alcance.RutaIds;
            consulta = alcance.SoloPropios
                ? consulta.Where(p => p.UsuarioId == alcance.UsuarioId)
                : consulta.Where(p => p.UsuarioId == alcance.UsuarioId
                                      || (p.Cliente != null && p.Cliente.RutaId != null && rutas.Contains(p.Cliente.RutaId.Value)));
        }

        var pedidos = (await consulta
                .Select(p => new
                {
                    p.Id,
                    p.Numero,
                    p.Fecha,
                    p.Estado,
                    Cliente = p.Cliente != null ? p.Cliente.Nombre : "Sin cliente",
                    Ruta = p.Cliente != null && p.Cliente.Ruta != null ? p.Cliente.Ruta.Nombre : "Sin ruta",
                    Vendedor = p.Usuario != null ? p.Usuario.Nombre : "Sin asignar",
                    Total = p.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.CantidadPresentacion * d.PrecioPresentacion)) ?? 0m,
                    Venta = p.Ventas.Where(v => v.Estado != EstadoNotaVenta.Anulada).Select(v => v.Numero).FirstOrDefault(),
                })
                .AsNoTracking()
                .ToListAsync())
            .Select(p => new { p.Id, p.Numero, Dia = Zona.DiaDe(p.Fecha), p.Estado, p.Cliente, p.Ruta, p.Vendedor, p.Total, p.Venta })
            .ToList();

        // Sin permiso de novedades, la consulta no trae nada (la condición viaja como parámetro).
        var novedades = (await context.NovedadesEntrega
                    .Where(n => veNovedades && n.Estado != EstadoNovedad.Anulada && n.Fecha >= inicio && n.Fecha < fin)
                    .Select(n => new
                    {
                        n.Id,
                        n.Fecha,
                        Pedido = n.Pedido != null ? n.Pedido.Numero : "",
                        Venta = n.NotaVenta != null ? n.NotaVenta.Numero : null,
                        Cliente = n.Pedido != null && n.Pedido.Cliente != null ? n.Pedido.Cliente.Nombre : "Sin cliente",
                        Ruta = n.Pedido != null && n.Pedido.Cliente != null && n.Pedido.Cliente.Ruta != null ? n.Pedido.Cliente.Ruta.Nombre : "Sin ruta",
                        Vendedor = n.Pedido != null && n.Pedido.Usuario != null ? n.Pedido.Usuario.Nombre : "Sin asignar",
                        Producto = n.Producto != null ? n.Producto.Nombre : "",
                        Motivo = n.Motivo != null ? n.Motivo.Nombre : "Sin motivo",
                        n.Importe,
                        n.Estado,
                    })
                    .AsNoTracking()
                    .ToListAsync())
                .Select(n => new { n.Id, Dia = Zona.DiaDe(n.Fecha), n.Pedido, n.Venta, n.Cliente, n.Ruta, n.Vendedor, n.Producto, n.Motivo, n.Importe, n.Estado })
                .ToList();

        static string TextoEstado(string estado) => estado switch
        {
            EstadoPedido.Pendiente => "Pendiente",
            EstadoPedido.Confirmado => "Convertido",
            EstadoPedido.Anulado => "Anulado",
            _ => estado,
        };

        static string TextoNovedad(string estado) => estado switch
        {
            EstadoNovedad.Pendiente => "Por revisar",
            EstadoNovedad.Recibida => "Recibida",
            EstadoNovedad.Faltante => "Faltante",
            EstadoNovedad.SinRetorno => "Sin retorno",
            _ => estado,
        };

        List<FiltroReporte> filtros =
        [
            Filtro("ruta", "Ruta", pedidos.Select(p => p.Ruta)),
            Filtro("vendedor", "Vendedor", pedidos.Select(p => p.Vendedor)),
            Filtro("cliente", "Cliente", pedidos.Select(p => p.Cliente)),
            Filtro("estado", "Estado", pedidos.Select(p => (p.Estado, TextoEstado(p.Estado)))),
        ];
        if (veNovedades) filtros.Add(Filtro("motivo", "Motivo de novedad", novedades.Select(n => n.Motivo)));

        string? F(string clave) => request.Filtro(clave);
        var lista = pedidos.Where(p =>
                (F("ruta") is not string ruta || p.Ruta == ruta)
                && (F("vendedor") is not string ven || p.Vendedor == ven)
                && (F("cliente") is not string cli || p.Cliente == cli)
                && (F("estado") is not string est || p.Estado == est))
            .ToList();
        var noLlego = novedades.Where(n =>
                (F("ruta") is not string ruta || n.Ruta == ruta)
                && (F("vendedor") is not string ven || n.Vendedor == ven)
                && (F("cliente") is not string cli || n.Cliente == cli)
                && (F("motivo") is not string mot || n.Motivo == mot))
            .ToList();

        List<ColumnaReporte> columnas;
        IEnumerable<Dictionary<string, object?>> filas;
        // El total de un grupo es de los pedidos vigentes: uno anulado no se vendió.
        var conteos = new List<ColumnaReporte>
        {
            Col("pedidos", "Pedidos", TipoDato.Entero, suma: true, ancho: 54),
            Col("convertidos", "Convertidos", TipoDato.Entero, suma: true, ancho: 66),
            Col("anulados", "Anulados", TipoDato.Entero, suma: true, ancho: 56),
            Col("total", "Total", TipoDato.Moneda, suma: true, destacada: true, ancho: 78),
        };

        Dictionary<string, object?> Grupo(string clave, IEnumerable<(string Estado, decimal Total)> g, params (string, object?)[] extra)
        {
            var items = g.ToList();
            var fila = Fila(clave, extra);
            fila["pedidos"] = items.Count;
            fila["convertidos"] = items.Count(i => i.Estado == EstadoPedido.Confirmado);
            fila["anulados"] = items.Count(i => i.Estado == EstadoPedido.Anulado);
            fila["total"] = R2(items.Where(i => i.Estado != EstadoPedido.Anulado).Sum(i => i.Total));
            return fila;
        }

        switch (vista)
        {
            case "ruta":
            case "vendedor":
            case "cliente":
                columnas = [Col("nombre", vista == "ruta" ? "Ruta" : vista == "vendedor" ? "Vendedor" : "Cliente"), .. conteos];
                filas = lista.GroupBy(p => vista == "ruta" ? p.Ruta : vista == "vendedor" ? p.Vendedor : p.Cliente)
                    .OrderByDescending(g => g.Where(p => p.Estado != EstadoPedido.Anulado).Sum(p => p.Total))
                    .Select(g => Grupo(g.Key, g.Select(p => (p.Estado, p.Total)), ("nombre", g.Key)));
                break;
            case "dia":
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, apoyo: "semana"), .. conteos];
                filas = lista.GroupBy(p => p.Dia).OrderBy(g => g.Key)
                    .Select(g => Grupo(g.Key.ToString("yyyy-MM-dd"), g.Select(p => (p.Estado, p.Total)),
                                       ("fecha", g.Key), ("semana", DiaSemana(g.Key))));
                break;
            case "novedades":
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("pedido", "Pedido", apoyo: "venta", ancho: 70),
                            Col("cliente", "Cliente", apoyo: "ruta"), Col("producto", "Producto"), Col("motivo", "Motivo"),
                            Col("estado", "Estado", ancho: 70),
                            Col("importe", "No entregado", TipoDato.Moneda, suma: true, destacada: true, ancho: 76)];
                filas = noLlego.OrderByDescending(n => n.Dia).ThenByDescending(n => n.Id)
                    .Select(n => Fila(n.Id.ToString(), ("fecha", n.Dia), ("pedido", n.Pedido), ("venta", n.Venta),
                        ("cliente", n.Cliente), ("ruta", n.Ruta), ("producto", n.Producto), ("motivo", n.Motivo),
                        ("estado", TextoNovedad(n.Estado)), ("importe", R2(n.Importe))));
                break;
            case "motivo":
                columnas = [Col("nombre", "Motivo"), Col("novedades", "Novedades", TipoDato.Entero, suma: true, ancho: 66),
                            Col("importe", "No entregado", TipoDato.Moneda, suma: true, destacada: true, ancho: 76)];
                filas = noLlego.GroupBy(n => n.Motivo).OrderByDescending(g => g.Sum(n => n.Importe))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("novedades", g.Count()), ("importe", R2(g.Sum(n => n.Importe)))));
                break;
            default:
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("nombre", "Pedido", apoyo: "venta", ancho: 70),
                            Col("cliente", "Cliente", apoyo: "ruta"), Col("vendedor", "Vendedor"), Col("estado", "Estado", ancho: 70),
                            Col("total", "Total", TipoDato.Moneda, suma: true, destacada: true, ancho: 78)];
                filas = lista.OrderByDescending(p => p.Dia).ThenByDescending(p => p.Numero)
                    .Select(p => Fila(p.Id.ToString(), ("fecha", p.Dia), ("nombre", p.Numero),
                        ("venta", p.Venta is null ? null : $"Venta {p.Venta}"), ("cliente", p.Cliente), ("ruta", p.Ruta),
                        ("vendedor", p.Vendedor), ("estado", TextoEstado(p.Estado)),
                        // Un anulado se ve, pero no suma: no se vendió.
                        ("total", p.Estado == EstadoPedido.Anulado ? 0m : R2(p.Total))));
                break;
        }

        var vigentes = lista.Where(p => p.Estado != EstadoPedido.Anulado).ToList();

        return new ReporteResponse
        {
            Titulo = "Reporte de pedidos y reparto",
            Vista = vista,
            Vistas = vistas,
            ConFechas = true,
            Desde = primero,
            Hasta = ultimo,
            Columnas = columnas,
            Filas = filas.ToList(),
            Filtros = filtros,
            Resumen =
            [
                Resumen("Pedidos", vigentes.Count, TipoDato.Entero, "sys", nota: $"{lista.Count(p => p.Estado == EstadoPedido.Anulado)} anulados aparte"),
                Resumen("Convertidos a venta", lista.Count(p => p.Estado == EstadoPedido.Confirmado), TipoDato.Entero, "success"),
                Resumen("Total pedido", vigentes.Sum(p => p.Total)),
                veNovedades
                    ? Resumen("No entregado", noLlego.Sum(n => n.Importe), tono: "danger", nota: $"{noLlego.Count} novedades")
                    : Resumen("Pendientes", lista.Count(p => p.Estado == EstadoPedido.Pendiente), TipoDato.Entero, "warning"),
            ],
            Aviso = alcance is { SinRestriccion: false } ? "Solo ves los pedidos que te tocan: el reporte no es de todo el negocio." : null,
            Nota = "Total: lo pedido en los pedidos vigentes; los anulados se cuentan aparte y no suman.",
        };
    }
}
