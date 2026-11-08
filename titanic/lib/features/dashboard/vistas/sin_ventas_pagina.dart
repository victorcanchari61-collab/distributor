import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart' show mismoDia;
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/red/tiempo_real_provider.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../crm/datos/crm.dart' show EstadoCaida;
import '../../crm/vistas/crm_comun.dart'
    show
        EtiquetaEstadoCaida,
        colorCambio,
        colorDeDias,
        fechaDia,
        porcentaje,
        soles;
import '../../tms/datos/flota_api.dart' show ArchivoApi;
import '../datos/sin_ventas_analisis_modelos.dart';
import '../estado/sin_ventas_analisis_controlador.dart';
import '../widgets/grafico_barras_h.dart';
import '../widgets/grafico_dona.dart';
import '../widgets/grafico_linea.dart';
import '../widgets/grafico_util.dart' show PaletaDash, numeroEs;
import '../widgets/marco_grafico.dart';

/// Productos sin ventas: lo que vendió cada producto en el tramo frente al mes
/// (o el año) anterior y en qué estado queda, por cuánto cayó o por los días que
/// lleva sin venderse.
///
/// Las tarjetas de estado son filtros: tocar una deja solo esos productos en la
/// lista (volver a tocar la quita). Todo lo demás se elige en el icono de
/// filtros.
class SinVentasPagina extends ConsumerWidget {
  const SinVentasPagina({super.key});

  static const ruta = '/dashboard/sinventas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupo = resolverRuta(ruta).grupo;
    final color = grupo?.color ?? Colores.marca;

    // Una venta, una compra o un ajuste de stock cambian el análisis.
    escucharCambios(ref, const [
      'notasventa',
      'productos',
      'stock',
      'compras',
      'recepciones',
    ], () => ref.invalidate(sinVentasAnalisisProvider));

    // Se piden al abrir para que la hoja de filtros ya los tenga. Si el rol no
    // los puede ver, el filtro queda sin opciones y nada más.
    ref.watch(almacenesSinVentasProvider);
    ref.watch(categoriasSinVentasProvider);
    ref.watch(marcasSinVentasProvider);

    Future<void> recargar() async {
      ref.invalidate(sinVentasAnalisisProvider);
      try {
        await ref.read(sinVentasAnalisisProvider.future);
      } catch (_) {
        // El fallo ya se ve en la pantalla, con su botón de reintentar.
      }
    }

    return AppShell(
      titulo: 'Productos sin ventas',
      subtitulo: grupo?.titulo,
      acentado: color,
      rutaActual: ruta,
      acciones: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: recargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        color: color,
        onRefresh: recargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _Cabecera(color: color)),
            const SliverToBoxAdapter(child: _Tarjetas()),
            const SliverToBoxAdapter(child: _Graficos()),
            const SliverToBoxAdapter(child: _EncabezadoLista()),
            const _ListaProductos(),
            const SliverToBoxAdapter(
              child: SizedBox(height: Dimen.espacio6 * 2),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Formatos

/// Soles o unidades, según lo que se mide.
String _valor(double n, MedidaSinVentas medida) =>
    medida == MedidaSinVentas.soles
    ? soles(n)
    : '${numeroEs(n, n % 1 == 0 ? 0 : 2)} u.';

/// Lo mismo con "+" o "−" delante: para diferencias.
String _valorConSigno(double n, MedidaSinVentas medida) =>
    '${n < 0
        ? '−'
        : n > 0
        ? '+'
        : ''}${_valor(n.abs(), medida)}';

/// Lo que dice el servidor cuando algo falla.
String _mensajeError(Object e) =>
    e is ApiExcepcion ? e.texto : 'No pudimos cargar el análisis.';

// ----------------------------------------------------------------- Cabecera

/// El tramo que se mide, contra qué, y el icono de filtros.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consulta = ref.watch(consultaSinVentasProvider);
    final locales = ref.watch(localesSinVentasProvider);
    final cargando = ref.watch(sinVentasAnalisisProvider).isLoading;
    final activos =
        consulta.activosFrente(ConsultaSinVentas.inicial()) + locales.activos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio2,
            Dimen.espacio2,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${fechaDia(consulta.desde)} - ${fechaDia(consulta.hasta)} '
                  'frente a ${consulta.comparar.referencia}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colores.tintaSuave,
                  ),
                ),
              ),
              BotonFiltros(
                activos: activos,
                color: color,
                onAbrir: () => _abrirFiltros(context, ref),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 2,
          child: cargando ? const LinearProgressIndicator() : null,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Tarjetas

/// Una tarjeta por estado, más la de los que ya cayeron. Son filtros de la
/// lista.
class _Tarjetas extends ConsumerWidget {
  const _Tarjetas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sinVentasAnalisisProvider);
    final datos = estado.valueOrNull;
    final elegido = ref.watch(estadoSinVentasProvider);

    if (datos == null) {
      if (estado.hasError) {
        return _ErrorCarga(
          mensaje: _mensajeError(estado.error!),
          onReintentar: () => ref.invalidate(sinVentasAnalisisProvider),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(Dimen.espacio4),
        child: Esqueleto(alto: 100),
      );
    }

    final medida = datos.medida;
    void elegir(String clave) =>
        ref.read(estadoSinVentasProvider.notifier).state = elegido == clave
        ? null
        : clave;

    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimen.espacio4,
          vertical: Dimen.espacio3,
        ),
        children: [
          _TarjetaEstado(
            titulo: 'Productos sin ventas',
            valor: datos.resumen.enCaida,
            nota: 'En caída',
            detalle:
                'Venta perdida ${_valor(datos.resumen.ventaPerdida, medida)}',
            color: Colores.peligro,
            activa: elegido == claveEnCaida,
            onTap: () => elegir(claveEnCaida),
          ),
          for (final e in EstadoCaida.values) ...[
            const SizedBox(width: Dimen.espacio2),
            _TarjetaEstado(
              titulo: e.etiqueta,
              valor: datos.deEstado(e)?.productos ?? 0,
              nota: rangoDeEstado(e, datos.criterio, datos.comparar),
              detalle: e == EstadoCaida.sinBase
                  ? (datos.criterio == CriterioSinVentas.dias
                        ? 'Sin ninguna venta'
                        : 'No vendieron ${datos.comparar.referencia}')
                  : '${soles(datos.deEstado(e)?.costoStock ?? 0)} en stock',
              color: e.color,
              activa: elegido == e.clave,
              onTap: () => elegir(e.clave),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaEstado extends StatelessWidget {
  const _TarjetaEstado({
    required this.titulo,
    required this.valor,
    required this.nota,
    required this.detalle,
    required this.color,
    required this.activa,
    required this.onTap,
  });

  final String titulo;
  final int valor;
  final String nota;
  final String detalle;
  final Color color;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const suave = TextStyle(fontSize: 11, color: Colores.tintaSuave);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(Dimen.espacio3),
        decoration: BoxDecoration(
          color: activa ? color.withValues(alpha: 0.08) : Colores.superficie,
          border: Border.all(
            color: activa ? color : Colores.linea,
            width: activa ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colores.tintaSuave,
              ),
            ),
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            Text(
              nota,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: suave,
            ),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: suave,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimen.espacio4),
      child: AppVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No se pudo cargar',
        detalle: mensaje,
        accion: FilledButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar'),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Gráficos

/// Dona por estado, categorías con mayor caída y evolución de las ventas.
class _Graficos extends ConsumerWidget {
  const _Graficos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sinVentasAnalisisProvider);
    final datos = estado.valueOrNull;
    final elegido = ref.watch(estadoSinVentasProvider);

    // Con error, la tarjeta de arriba ya lo dice con su botón.
    if (datos == null && estado.hasError) return const SizedBox.shrink();
    final cargando = datos == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: Column(
        children: [
          _marcoDona(datos, cargando),
          const SizedBox(height: Dimen.espacio3),
          _marcoCategorias(datos, cargando),
          const SizedBox(height: Dimen.espacio3),
          _marcoEvolucion(datos, cargando, elegido),
        ],
      ),
    );
  }

  Widget _marcoDona(AnalisisSinVentas? d, bool cargando) {
    final total = d?.totalEnEstados ?? 0;

    return MarcoGrafico(
      titulo: 'Distribución por estado',
      subtitulo: d == null
          ? null
          : '$total ${total == 1 ? 'producto analizado' : 'productos analizados'}',
      cargando: cargando,
      vacio: total == 0,
      mensajeVacio: 'No hay productos para analizar',
      alto: 200,
      contenido: () => GraficoDona(
        porciones: [
          for (final e in EstadoCaida.values)
            if ((d!.deEstado(e)?.productos ?? 0) > 0)
              PorcionDona(
                nombre: e.etiqueta,
                valor: d.deEstado(e)!.productos.toDouble(),
                color: e.color,
              ),
        ],
        formato: (n) => numeroEs(n),
        decimalesPct: 1,
        centro: (titulo: 'productos', valor: '$total'),
      ),
    );
  }

  Widget _marcoCategorias(AnalisisSinVentas? d, bool cargando) {
    final categorias = (d?.porCategoria ?? const <CategoriaAnalisis>[])
        .take(8)
        .toList();

    return MarcoGrafico(
      titulo: 'Categorías con mayor caída',
      subtitulo: 'Venta perdida y % de caída',
      cargando: cargando,
      vacio: categorias.isEmpty,
      mensajeVacio: 'Ninguna categoría vendió menos',
      alto: 160,
      contenido: () => GraficoBarrasH(
        unColor: Colores.peligro,
        formato: (n) => _valor(n, d!.medida),
        items: [
          for (final c in categorias)
            ItemBarraH(
              nombre: c.categoria,
              valor: -c.variacion,
              detalle: c.caidaPct == null
                  ? 'sin base'
                  : '${c.caidaPct!.toStringAsFixed(1)} %',
            ),
        ],
      ),
    );
  }

  Widget _marcoEvolucion(AnalisisSinVentas? d, bool cargando, String? elegido) {
    // La serie es la de lo que se mira: el estado elegido o todos los que cayeron.
    final clave = elegido != null && elegido != claveEnCaida
        ? elegido
        : 'TODOS';
    final serie = d?.serie(clave);
    final medida = d?.medida ?? MedidaSinVentas.soles;

    return MarcoGrafico(
      titulo: 'Evolución de ventas',
      subtitulo: d == null || serie == null
          ? null
          : 'Anterior ${_valor(serie.anterior, medida)} · '
                'actual ${_valor(serie.actual, medida)} · perdida ',
      enfasis: d == null || serie == null
          ? null
          : _valor(d.perdidaDeSerie(clave), medida),
      cargando: cargando,
      vacio: serie == null || serie.sinVentas,
      mensajeVacio: 'Sin ventas para comparar',
      alto: 220,
      contenido: () {
        final porDia = d!.porDia;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeyendaLinea(anterior: d.comparar.etiqueta),
            const SizedBox(height: Dimen.espacio2),
            GraficoLinea(
              alto: 200,
              formato: (n) => _valor(n, medida),
              etiquetas: [
                for (final p in serie!.puntos)
                  etiquetaEjeEvolucion(p.etiqueta, porDia: porDia),
              ],
              etiquetasLargas: [
                for (final p in serie.puntos)
                  etiquetaLargaEvolucion(p.etiqueta, porDia: porDia),
              ],
              series: [
                SerieLinea(
                  id: 'anterior',
                  nombre: d.comparar.etiqueta,
                  color: PaletaDash.neutro,
                  punteada: true,
                  valores: [for (final p in serie.puntos) p.anterior],
                ),
                SerieLinea(
                  id: 'actual',
                  nombre: 'Período actual',
                  color: Colores.marca,
                  area: true,
                  valores: [for (final p in serie.puntos) p.actual],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LeyendaLinea extends StatelessWidget {
  const _LeyendaLinea({required this.anterior});

  final String anterior;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
        ),
      ],
    );

    return Wrap(
      spacing: Dimen.espacio4,
      children: [
        item(PaletaDash.neutro, anterior),
        item(Colores.marca, 'Período actual'),
      ],
    );
  }
}

// -------------------------------------------------------------------- Lista

/// El título de la lista, cuántos productos hay en ella y el buscador.
class _EncabezadoLista extends ConsumerWidget {
  const _EncabezadoLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sinVentasAnalisisProvider);
    if (estado.valueOrNull == null) return const SizedBox.shrink();

    final cuantos = ref.watch(sinVentasAnalisisFiltradosProvider).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimen.espacio4,
        Dimen.espacio4,
        Dimen.espacio4,
        Dimen.espacio3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$cuantos ${cuantos == 1 ? 'producto' : 'productos'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio2),
          AppBuscador(
            valor: ref.watch(busquedaSinVentasAnalisisProvider),
            onCambio: (t) =>
                ref.read(busquedaSinVentasAnalisisProvider.notifier).state = t,
            pista: 'Buscar producto, código, marca o categoría',
          ),
        ],
      ),
    );
  }
}

class _ListaProductos extends ConsumerWidget {
  const _ListaProductos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sinVentasAnalisisProvider);
    final datos = estado.valueOrNull;

    if (datos == null) {
      if (estado.hasError) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Dimen.espacio4),
          child: Esqueleto(alto: 140),
        ),
      );
    }

    final items = ref.watch(sinVentasAnalisisFiltradosProvider);
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppVacio(
          icono: Icons.inventory_2_outlined,
          titulo: 'Sin productos',
          detalle: 'Ninguno coincide con estos filtros.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, i) =>
            const SizedBox(height: Dimen.espacio2),
        itemBuilder: (context, i) =>
            _TarjetaProducto(producto: items[i], medida: datos.medida),
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({required this.producto, required this.medida});

  final ProductoAnalisis producto;
  final MedidaSinVentas medida;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final subtitulo = [
      p.codigo,
      p.marca,
      p.categoria,
    ].where((t) => t != null && t.isNotEmpty).join(' · ');

    final caida = p.caidaPct;

    final datos = <_DatoProducto>[
      _DatoProducto(
        'Última venta',
        p.ultimaVenta == null ? 'Nunca' : fechaDia(p.ultimaVenta),
      ),
      _DatoProducto(
        'Días sin venta',
        '${p.diasSinVenta}',
        color: colorDeDias(p.diasSinVenta),
        fuerte: true,
      ),
      _DatoProducto(
        'Stock',
        p.stock > 0
            ? '${numeroEs(p.stock, p.stock % 1 == 0 ? 0 : 2)} ${p.unidadBase}'
                  .trim()
            : 'Sin stock',
      ),
      _DatoProducto(
        'Costo stock',
        p.costoStock > 0 ? soles(p.costoStock) : '—',
      ),
      _DatoProducto(
        'Última compra',
        p.ultimaCompra == null ? '—' : fechaDia(p.ultimaCompra),
      ),
      _DatoProducto('Anterior', _valor(p.anterior, medida)),
      _DatoProducto('Actual', _valor(p.actual, medida), fuerte: true),
      _DatoProducto(
        'Variación',
        _valorConSigno(p.variacion, medida),
        color: colorCambio(p.variacion),
        fuerte: true,
      ),
      _DatoProducto(
        '% caída',
        caida == null ? '—' : porcentaje(-caida),
        color: caida == null ? Colores.tintaSuave : colorCambio(-caida),
      ),
      _DatoProducto(
        'Pérdida',
        p.perdida > 0 ? _valor(p.perdida, medida) : '—',
        color: p.perdida > 0 ? Colores.peligro : null,
        fuerte: p.perdida > 0,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Foto(foto: p.foto),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.producto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                    if (subtitulo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colores.tintaSuave,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              EtiquetaEstadoCaida(p.estado),
            ],
          ),
          const SizedBox(height: Dimen.espacio3),
          LayoutBuilder(
            builder: (context, caja) {
              const separacion = Dimen.espacio3;
              final ancho = (caja.maxWidth - separacion) / 2;
              return Wrap(
                spacing: separacion,
                runSpacing: Dimen.espacio2,
                children: [
                  for (final d in datos) SizedBox(width: ancho, child: d),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// La foto del producto; sin ella (o si no carga), un recuadro con su icono.
class _Foto extends StatelessWidget {
  const _Foto({required this.foto});

  final String? foto;

  @override
  Widget build(BuildContext context) {
    const lado = 48.0;

    Widget vacia() => Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: PaletaDash.fondoSuave,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 22,
        color: Colores.tintaTenue,
      ),
    );

    final ruta = foto;
    if (ruta == null || ruta.isEmpty) return vacia();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        ArchivoApi.url(ruta),
        width: lado,
        height: lado,
        fit: BoxFit.cover,
        errorBuilder: (context, error, pila) => vacia(),
      ),
    );
  }
}

class _DatoProducto extends StatelessWidget {
  const _DatoProducto(
    this.etiqueta,
    this.valor, {
    this.color,
    this.fuerte = false,
  });

  final String etiqueta;
  final String valor;
  final Color? color;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colores.tintaSuave),
        ),
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
            color: color ?? Colores.tinta,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Filtros

typedef _ResultadoFiltros = ({
  ConsultaSinVentas consulta,
  FiltrosLocalesSinVentas locales,
});

Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) async {
  final resultado = await abrirHoja<_ResultadoFiltros>(
    context,
    (_) => _HojaFiltros(
      consulta: ref.read(consultaSinVentasProvider),
      locales: ref.read(localesSinVentasProvider),
    ),
  );
  if (resultado == null) return;

  ref.read(consultaSinVentasProvider.notifier).state = resultado.consulta;
  ref.read(localesSinVentasProvider.notifier).state = resultado.locales;
}

/// Los filtros se arman en un borrador y se aplican juntos: cada cambio del
/// servidor es una consulta nueva y no conviene pedir una por cada selector.
class _HojaFiltros extends ConsumerStatefulWidget {
  const _HojaFiltros({required this.consulta, required this.locales});

  final ConsultaSinVentas consulta;
  final FiltrosLocalesSinVentas locales;

  @override
  ConsumerState<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends ConsumerState<_HojaFiltros> {
  late ConsultaSinVentas _consulta = widget.consulta;
  late FiltrosLocalesSinVentas _locales = widget.locales;

  late final _desde = TextEditingController(
    text: _texto(widget.locales.stockDesde),
  );
  late final _hasta = TextEditingController(
    text: _texto(widget.locales.stockHasta),
  );

  static String _texto(double? n) =>
      n == null ? '' : numeroEs(n, n % 1 == 0 ? 0 : 2).replaceAll(',', '');

  static double? _numero(String texto) {
    final t = texto.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  @override
  void dispose() {
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  List<OpcionFiltro<int?>> _opciones(List<OpcionCatalogo> catalogo) => [
    const OpcionFiltro<int?>(null, 'Todas'),
    for (final o in catalogo) OpcionFiltro<int?>(o.id, o.nombre),
  ];

  void _aplicar() {
    Navigator.of(context).pop<_ResultadoFiltros>((
      consulta: _consulta,
      locales: FiltrosLocalesSinVentas(
        movimiento: _locales.movimiento,
        stock: _locales.stock,
        stockDesde: _numero(_desde.text),
        stockHasta: _numero(_hasta.text),
      ),
    ));
  }

  void _limpiar() {
    Navigator.of(context).pop<_ResultadoFiltros>((
      consulta: ConsultaSinVentas.inicial(),
      locales: const FiltrosLocalesSinVentas(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final base = ConsultaSinVentas.inicial();
    final almacenes = ref.watch(almacenesSinVentasProvider).valueOrNull ?? [];
    final categorias = ref.watch(categoriasSinVentasProvider).valueOrNull ?? [];
    final marcas = ref.watch(marcasSinVentasProvider).valueOrNull ?? [];

    final hayAlgo =
        _consulta.activosFrente(base) > 0 ||
        _locales.activos > 0 ||
        _desde.text.isNotEmpty ||
        _hasta.text.isNotEmpty;

    final porDefecto =
        mismoDia(_consulta.desde, base.desde) &&
        mismoDia(_consulta.hasta, base.hasta);

    const separacion = SizedBox(height: Dimen.espacio4);

    return HojaBase(
      titulo: 'Filtros',
      accionesTitulo: [
        if (hayAlgo)
          TextButton(
            onPressed: _limpiar,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Limpiar'),
          ),
      ],
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrupoFiltroFechas(
            rango: porDefecto
                ? null
                : DateTimeRange(start: _consulta.desde, end: _consulta.hasta),
            textoVacio: 'Del 1 del mes a hoy',
            onCambio: (r) => setState(
              () => _consulta = _consulta.copiar(
                desde: r?.start ?? base.desde,
                hasta: r?.end ?? base.hasta,
              ),
            ),
          ),
          separacion,
          GrupoFiltro<CompararSinVentas>(
            titulo: 'Comparar con',
            valor: _consulta.comparar,
            opciones: [
              for (final c in CompararSinVentas.values)
                OpcionFiltro(c, c.etiqueta),
            ],
            onCambio: (v) =>
                setState(() => _consulta = _consulta.copiar(comparar: v)),
          ),
          separacion,
          GrupoFiltro<MedidaSinVentas>(
            titulo: 'Comparar por',
            valor: _consulta.medida,
            opciones: [
              for (final m in MedidaSinVentas.values)
                OpcionFiltro(m, m.etiqueta),
            ],
            onCambio: (v) =>
                setState(() => _consulta = _consulta.copiar(medida: v)),
          ),
          separacion,
          GrupoFiltro<CriterioSinVentas>(
            titulo: 'Criterio',
            valor: _consulta.criterio,
            opciones: [
              for (final c in CriterioSinVentas.values)
                OpcionFiltro(c, c.etiqueta),
            ],
            onCambio: (v) =>
                setState(() => _consulta = _consulta.copiar(criterio: v)),
          ),
          separacion,
          GrupoFiltro<int?>(
            titulo: 'Sucursal',
            valor: _consulta.almacenId,
            opciones: _opciones(almacenes),
            onCambio: (v) => setState(
              () => _consulta = _consulta.copiar(almacenId: () => v),
            ),
          ),
          separacion,
          GrupoFiltro<int?>(
            titulo: 'Categoría',
            valor: _consulta.categoriaId,
            opciones: _opciones(categorias),
            onCambio: (v) => setState(
              () => _consulta = _consulta.copiar(categoriaId: () => v),
            ),
          ),
          separacion,
          GrupoFiltro<int?>(
            titulo: 'Marca',
            valor: _consulta.marcaId,
            opciones: _opciones(marcas),
            onCambio: (v) =>
                setState(() => _consulta = _consulta.copiar(marcaId: () => v)),
          ),
          separacion,
          GrupoFiltro<bool>(
            titulo: 'Incluir sin stock',
            valor: _consulta.incluirSinStock,
            opciones: const [
              OpcionFiltro(false, 'No'),
              OpcionFiltro(true, 'Sí'),
            ],
            onCambio: (v) => setState(
              () => _consulta = _consulta.copiar(incluirSinStock: v),
            ),
          ),
          separacion,
          GrupoFiltro<MovimientoSinVentas?>(
            titulo: 'Días sin movimiento',
            valor: _locales.movimiento,
            opciones: [
              const OpcionFiltro<MovimientoSinVentas?>(null, 'Todos'),
              for (final m in MovimientoSinVentas.values)
                OpcionFiltro<MovimientoSinVentas?>(m, m.etiqueta),
            ],
            onCambio: (v) => setState(
              () => _locales = FiltrosLocalesSinVentas(
                movimiento: v,
                stock: _locales.stock,
              ),
            ),
          ),
          separacion,
          GrupoFiltro<StockSinVentas?>(
            titulo: 'Stock',
            valor: _locales.stock,
            opciones: [
              const OpcionFiltro<StockSinVentas?>(null, 'Todos'),
              for (final s in StockSinVentas.values)
                OpcionFiltro<StockSinVentas?>(s, s.etiqueta),
            ],
            onCambio: (v) => setState(
              () => _locales = FiltrosLocalesSinVentas(
                movimiento: _locales.movimiento,
                stock: v,
              ),
            ),
          ),
          separacion,
          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _desde,
                  etiqueta: 'Stock desde',
                  tipoTeclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  accionTeclado: TextInputAction.next,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: _hasta,
                  etiqueta: 'Stock hasta',
                  tipoTeclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  accionTeclado: TextInputAction.done,
                ),
              ),
            ],
          ),
        ],
      ),
      pie: AppBoton(texto: 'Aplicar', onPressed: _aplicar),
    );
  }
}
