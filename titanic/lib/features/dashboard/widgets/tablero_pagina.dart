import 'package:flutter/material.dart';

import '../../../compartido/widgets/app_shell.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../estado/periodo_tablero.dart';
import 'grafico_util.dart';

/// El armazón de cada dashboard: barra con el botón de actualizar, una línea
/// que dice de qué trata, los atajos de período y, debajo, los indicadores y
/// gráficos en una sola columna.
///
/// Tirar hacia abajo también actualiza. Es el `Encabezado` del panel web.
class TableroPagina extends StatelessWidget {
  const TableroPagina({
    super.key,
    required this.ruta,
    required this.descripcion,
    required this.onRecargar,
    required this.hijos,
    this.periodo,
    this.onPeriodo,
  });

  /// Ruta del menú: de ahí salen el título, el módulo y el color.
  final String ruta;
  final String descripcion;
  final Future<void> Function() onRecargar;
  final List<Widget> hijos;

  /// Inventario es una foto de hoy: no tiene rango que elegir y va sin período.
  final PeriodoTablero? periodo;
  final ValueChanged<PeriodoTablero>? onPeriodo;

  @override
  Widget build(BuildContext context) {
    final vista = resolverRuta(ruta);
    final color = vista.grupo?.color ?? Colores.marca;

    return AppShell(
      titulo: vista.item?.titulo ?? 'Dashboard',
      subtitulo: vista.grupo?.titulo,
      acentado: color,
      rutaActual: ruta,
      acciones: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => onRecargar(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        color: color,
        onRefresh: onRecargar,
        child: ListView(
          // Aun con poco contenido tiene que poder tirarse para actualizar.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio4,
            Dimen.espacio4,
            Dimen.espacio6 * 2,
          ),
          children: [
            Text(
              descripcion,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colores.tintaSuave,
              ),
            ),
            if (periodo != null && onPeriodo != null) ...[
              const SizedBox(height: Dimen.espacio3),
              SelectorPeriodo(periodo: periodo!, onCambio: onPeriodo!),
            ],
            for (final h in hijos) ...[
              const SizedBox(height: Dimen.espacio4),
              h,
            ],
          ],
        ),
      ),
    );
  }
}

/// Los atajos de período (7 días, 30 días, este mes, 90 días) y el selector de
/// fechas para un rango propio.
class SelectorPeriodo extends StatelessWidget {
  const SelectorPeriodo({
    super.key,
    required this.periodo,
    required this.onCambio,
  });

  final PeriodoTablero periodo;
  final ValueChanged<PeriodoTablero> onCambio;

  @override
  Widget build(BuildContext context) {
    final acento = Acento.de(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Dimen.espacio2,
          runSpacing: Dimen.espacio2,
          children: [
            for (final a in PeriodoTablero.atajos())
              _ChipPeriodo(
                etiqueta: a.etiqueta,
                activo: periodo.id == a.id,
                color: acento,
                onTap: () => onCambio(a),
              ),
          ],
        ),
        const SizedBox(height: Dimen.espacio2),
        _CampoRango(
          periodo: periodo,
          color: acento,
          onCambio: (r) => onCambio(PeriodoTablero.propio(r.start, r.end)),
        ),
      ],
    );
  }
}

class _ChipPeriodo extends StatelessWidget {
  const _ChipPeriodo({
    required this.etiqueta,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? color : Colores.superficie,
          border: Border.all(color: activo ? color : Colores.linea),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : Colores.tintaSuave,
          ),
        ),
      ),
    );
  }
}

/// El rango que se está mirando, y el toque que abre el selector de fechas.
class _CampoRango extends StatelessWidget {
  const _CampoRango({
    required this.periodo,
    required this.color,
    required this.onCambio,
  });

  final PeriodoTablero periodo;
  final Color color;
  final ValueChanged<DateTimeRange> onCambio;

  /// "21 ago — 19 set", con el año cuando el rango no cae entero en el actual.
  String get _texto {
    final d = periodo.desde;
    final h = periodo.hasta;
    final conAnio = d.year != h.year || h.year != DateTime.now().year;
    String f(DateTime x) => conAnio ? '${diaCorto(x)} ${x.year}' : diaCorto(x);
    return '${f(d)} — ${f(h)}';
  }

  @override
  Widget build(BuildContext context) {
    final propio = periodo.id == 'custom';

    return InkWell(
      onTap: () async {
        final hoy = DateTime.now();
        final elegido = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(
            start: periodo.desde,
            end: periodo.hasta,
          ),
          firstDate: DateTime(hoy.year - 2),
          lastDate: DateTime(hoy.year, hoy.month, hoy.day),
        );
        if (elegido != null) onCambio(elegido);
      },
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        height: Dimen.campoSm,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
        decoration: BoxDecoration(
          color: propio ? color.withValues(alpha: 0.08) : Colores.superficie,
          border: Border.all(color: propio ? color : Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_outlined,
              size: 18,
              color: propio ? color : Colores.tintaSuave,
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: Text(
                _texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colores.tinta),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
