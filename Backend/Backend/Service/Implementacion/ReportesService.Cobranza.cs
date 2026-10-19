using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Cobranza: lo que se debe (hoy, con la regla de Cuentas por cobrar) y lo que se cobró en las
/// fechas elegidas. Las fechas solo filtran los cobros: la deuda es la de hoy, se haya vendido
/// cuando se haya vendido.
/// </summary>
public partial class ReportesService
{
    /// <summary>Los tramos de antigüedad, los mismos del gráfico.</summary>
    private static readonly (string Nombre, int Hasta)[] Tramos =
    [
        ("0–7 días", 7), ("8–15 días", 15), ("16–30 días", 30), ("31–60 días", 60), ("Más de 60", int.MaxValue),
    ];

    private static string TramoDe(int dias) => Tramos.First(t => dias <= t.Hasta).Nombre;

    private async Task<ReporteResponse> CobranzaAsync(ReporteRequest request)
    {
        var (primero, ultimo) = Rango(request);
        var hoy = Zona.Hoy;
        List<VistaReporte> vistas =
        [
            V("deuda_nota", "Deuda por nota"), V("deuda_cliente", "Deuda por cliente"), V("deuda_ruta", "Deuda por ruta"),
            V("cobros", "Cobros"), V("cobros_metodo", "Cobros por método"), V("cobros_cobrador", "Cobros por cobrador"),
        ];
        var vista = VistaDe(request, vistas);

        var abiertas = (await context.NotasVenta
                .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.FormaPago == FormaPagoVenta.Credito)
                .Select(n => new
                {
                    n.Id,
                    n.Numero,
                    n.Fecha,
                    Cliente = n.Cliente != null ? n.Cliente.Nombre : "Sin cliente",
                    Ruta = n.Cliente != null && n.Cliente.Ruta != null ? n.Cliente.Ruta.Nombre : "Sin ruta",
                    Total = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m,
                    Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
                })
                .Where(n => n.Total > n.Pagado)
                .AsNoTracking()
                .ToListAsync())
            .Select(n =>
            {
                var dia = Zona.DiaDe(n.Fecha);
                var dias = Math.Max(0, (int)(hoy - dia).TotalDays);
                return new { n.Id, n.Numero, Dia = dia, n.Cliente, n.Ruta, n.Total, n.Pagado, Saldo = n.Total - n.Pagado, Dias = dias, Tramo = TramoDe(dias) };
            })
            .ToList();

        var cobros = (await context.PagosVenta
                .Where(p => !p.Anulado
                            && p.NotaVenta!.Estado == EstadoNotaVenta.Confirmada
                            && p.Fecha >= Zona.AUtc(primero)
                            && p.Fecha < Zona.AUtc(ultimo.AddDays(1)))
                .Select(p => new
                {
                    p.Id,
                    p.Fecha,
                    p.Monto,
                    Nota = p.NotaVenta!.Numero,
                    Cliente = p.NotaVenta.Cliente != null ? p.NotaVenta.Cliente.Nombre : "Sin cliente",
                    Ruta = p.NotaVenta.Cliente != null && p.NotaVenta.Cliente.Ruta != null ? p.NotaVenta.Cliente.Ruta.Nombre : "Sin ruta",
                    Metodo = p.MetodoPago != null ? p.MetodoPago.Nombre : "Otro",
                    Cobrador = p.Usuario != null ? p.Usuario.Nombre : "Sin usuario",
                })
                .AsNoTracking()
                .ToListAsync())
            .Select(p => new { p.Id, Dia = Zona.DiaDe(p.Fecha), p.Monto, p.Nota, p.Cliente, p.Ruta, p.Metodo, p.Cobrador })
            .ToList();

        List<FiltroReporte> filtros =
        [
            Filtro("cliente", "Cliente", abiertas.Select(a => a.Cliente).Concat(cobros.Select(c => c.Cliente))),
            Filtro("ruta", "Ruta", abiertas.Select(a => a.Ruta).Concat(cobros.Select(c => c.Ruta))),
            Filtro("antiguedad", "Antigüedad", Tramos.Select(t => (t.Nombre, t.Nombre)).ToList()),
            Filtro("metodo", "Método de pago", cobros.Select(c => c.Metodo)),
            Filtro("cobrador", "Cobrador", cobros.Select(c => c.Cobrador)),
        ];
        // Los tramos van en su orden (de reciente a vencido), no por nombre.
        filtros[2].Opciones = Tramos.Select(t => new OpcionReporte { Valor = t.Nombre, Texto = t.Nombre }).ToList();

        string? F(string clave) => request.Filtro(clave);
        var deuda = abiertas.Where(a =>
                (F("cliente") is not string cli || a.Cliente == cli)
                && (F("ruta") is not string ruta || a.Ruta == ruta)
                && (F("antiguedad") is not string tramo || a.Tramo == tramo))
            .ToList();
        var cobrado = cobros.Where(c =>
                (F("cliente") is not string cli || c.Cliente == cli)
                && (F("ruta") is not string ruta || c.Ruta == ruta)
                && (F("metodo") is not string met || c.Metodo == met)
                && (F("cobrador") is not string cob || c.Cobrador == cob))
            .ToList();

        List<ColumnaReporte> columnas;
        IEnumerable<Dictionary<string, object?>> filas;
        var saldo = Col("saldo", "Saldo", TipoDato.Moneda, suma: true, destacada: true, ancho: 74);
        var monto = Col("monto", "Monto", TipoDato.Moneda, suma: true, destacada: true, ancho: 74);

        switch (vista)
        {
            case "deuda_cliente":
                columnas = [Col("nombre", "Cliente", apoyo: "ruta"), Col("notas", "Notas", TipoDato.Entero, suma: true, ancho: 50),
                            Col("dias", "Días (la más vieja)", TipoDato.Entero, ancho: 80), saldo];
                filas = deuda.GroupBy(a => a.Cliente).OrderByDescending(g => g.Sum(a => a.Saldo))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("ruta", g.First().Ruta), ("notas", g.Count()),
                                      ("dias", g.Max(a => a.Dias)), ("saldo", R2(g.Sum(a => a.Saldo)))));
                break;
            case "deuda_ruta":
                columnas = [Col("nombre", "Ruta"), Col("clientes", "Clientes", TipoDato.Entero, suma: true, ancho: 60),
                            Col("notas", "Notas", TipoDato.Entero, suma: true, ancho: 50), saldo];
                filas = deuda.GroupBy(a => a.Ruta).OrderByDescending(g => g.Sum(a => a.Saldo))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("clientes", g.Select(a => a.Cliente).Distinct().Count()),
                                      ("notas", g.Count()), ("saldo", R2(g.Sum(a => a.Saldo)))));
                break;
            case "cobros":
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("nota", "Nota", ancho: 66),
                            Col("cliente", "Cliente", apoyo: "ruta"), Col("metodo", "Método", ancho: 90),
                            Col("cobrador", "Cobrador"), monto];
                filas = cobrado.OrderByDescending(c => c.Dia).ThenByDescending(c => c.Id)
                    .Select(c => Fila(c.Id.ToString(), ("fecha", c.Dia), ("nota", c.Nota), ("cliente", c.Cliente),
                                      ("ruta", c.Ruta), ("metodo", c.Metodo), ("cobrador", c.Cobrador), ("monto", R2(c.Monto))));
                break;
            case "cobros_metodo":
            case "cobros_cobrador":
                var porMetodo = vista == "cobros_metodo";
                columnas = [Col("nombre", porMetodo ? "Método" : "Cobrador"),
                            Col("cobros", "Cobros", TipoDato.Entero, suma: true, ancho: 60), monto];
                filas = cobrado.GroupBy(c => porMetodo ? c.Metodo : c.Cobrador).OrderByDescending(g => g.Sum(c => c.Monto))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("cobros", g.Count()), ("monto", R2(g.Sum(c => c.Monto)))));
                break;
            default:
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("nota", "Nota", ancho: 66),
                            Col("cliente", "Cliente", apoyo: "ruta"), Col("dias", "Días", TipoDato.Entero, ancho: 44),
                            Col("total", "Total", TipoDato.Moneda, suma: true, ancho: 70),
                            Col("pagado", "Pagado", TipoDato.Moneda, suma: true, ancho: 70), saldo];
                filas = deuda.OrderByDescending(a => a.Dias)
                    .Select(a => Fila(a.Id.ToString(), ("fecha", a.Dia), ("nota", a.Numero), ("cliente", a.Cliente),
                                      ("ruta", a.Ruta), ("dias", a.Dias), ("total", R2(a.Total)), ("pagado", R2(a.Pagado)),
                                      ("saldo", R2(a.Saldo))));
                break;
        }

        var porCobrar = deuda.Sum(a => a.Saldo);
        var vieja = deuda.Where(a => a.Dias > 30).Sum(a => a.Saldo);

        return new ReporteResponse
        {
            Titulo = "Reporte de cobranza",
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
                Resumen("Por cobrar", porCobrar, tono: "warning", nota: $"{deuda.Count} notas · {deuda.Select(a => a.Cliente).Distinct().Count()} clientes"),
                Resumen("Más de 30 días", vieja, tono: vieja > 0 ? "danger" : "success"),
                Resumen("Cobrado", cobrado.Sum(c => c.Monto), tono: "success", nota: "En las fechas elegidas"),
                Resumen("Cobros", cobrado.Count, TipoDato.Entero, "neutral"),
            ],
            Aviso = "La deuda es la de hoy; las fechas solo filtran los cobros.",
        };
    }
}
