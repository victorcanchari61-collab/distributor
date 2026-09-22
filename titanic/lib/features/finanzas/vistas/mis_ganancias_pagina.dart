import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/ganancia.dart';
import '../estado/ganancia_controlador.dart';

/// El servidor no acepta un rango de más de un año.
const _diasMaximos = 366;

/// Mis ganancias: cuánto se ganó con cada producto.
///
/// La base es el producto: lo vendido menos lo que costó la mercadería que
/// salió (el costo real de cada salida, la más antigua primero, no uno de
/// referencia). El rango y los filtros recortan qué ventas entran en la suma y
/// los totales de arriba siguen ese mismo recorte.
///
/// Lo que se ve lo recorta el alcance, y lo aplica el servidor: quien solo
/// vende ve lo suyo.
class MisGananciasPagina extends ConsumerStatefulWidget {
  const MisGananciasPagina({super.key});

  static const ruta = '/finanzas/ganancias';

  @override
  ConsumerState<MisGananciasPagina> createState() => _MisGananciasPaginaState();
}

class _MisGananciasPaginaState extends ConsumerState<MisGananciasPagina> {
  // Lo que hay escrito en el buscador. Lo que se le pide al servidor es otra
  // cosa: ver busquedaGananciasProvider.
  String _texto = '';
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  /// Cada letra pedida recalcularía todas las ganancias del rango: se espera a
  /// que la persona deje de teclear.
  void _buscar(String texto) {
    setState(() => _texto = texto);
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      ref.read(busquedaGananciasProvider.notifier).state = texto.trim();
    });
  }

  void _cambiarRango(DateTimeRange? rango) {
    if (rango != null && rango.duration.inDays >= _diasMaximos) {
      Aviso.de(context).error('Elige un rango de hasta $_diasMaximos días.');
      return;
    }
    ref.read(rangoGananciasProvider.notifier).state = rango;
  }

  @override
  Widget build(BuildContext context) {
    final color =
        resolverRuta(MisGananciasPagina.ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(gananciasProvider);
    final pagina = estado.valueOrNull;
    final resumen = pagina?.resumen;
    final ganancia = resumen?.ganancia ?? 0;
    final margen = resumen?.margen;

    return AppListaPagina<GananciaProducto>(
      titulo: 'Mis ganancias',
      ruta: MisGananciasPagina.ruta,
      estado: estado.whenData((p) => p.items),
      visibles: pagina?.items ?? const <GananciaProducto>[],
      busqueda: _texto,
      onBuscar: _buscar,
      pistaBusqueda: 'Buscar por producto, categoría o marca',
      onRecargar: () async {
        ref.invalidate(gananciasProvider);
        try {
          await ref.read(gananciasProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.trending_up,
      singular: 'producto',
      plural: 'productos',
      tituloVacio: 'Sin ventas',
      detalleVacio: 'No hay ventas con esos filtros.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Vendido',
          valor: formatoSoles(resumen?.importe ?? 0),
          icono: Icons.payments_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Costo',
          valor: formatoSoles(resumen?.costo ?? 0),
          icono: Icons.inventory_2_outlined,
          tono: DatoTono.neutral,
          nota: 'De la mercadería',
        ),
        AppTarjetaDato(
          etiqueta: 'Ganancia',
          valor: formatoSoles(ganancia),
          icono: Icons.trending_up,
          tono: ganancia < 0 ? DatoTono.peligro : DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Margen',
          valor: margen == null ? '—' : '${margen.toStringAsFixed(1)} %',
          icono: Icons.percent,
          color: color,
          nota: 'Sobre lo vendido',
        ),
        AppTarjetaDato(
          etiqueta: 'Ventas',
          valor: '${resumen?.ventas ?? 0}',
          icono: Icons.receipt_long_outlined,
          tono: DatoTono.neutral,
          // El alcance lo aplica el servidor: aquí solo se dice cuál es.
          nota: resumen?.soloPropio == true ? 'Solo lo tuyo' : null,
        ),
        AppTarjetaDato(
          etiqueta: 'Productos',
          valor: '${resumen?.productos ?? 0}',
          icono: Icons.category_outlined,
          tono: DatoTono.neutral,
        ),
      ],
      encabezado: _Encabezado(
        resumen: resumen,
        cargados: pagina?.items.length ?? 0,
        total: pagina?.total ?? 0,
        rango: ref.watch(rangoGananciasProvider),
        onRango: _cambiarRango,
      ),
      filtro: BotonFiltros(
        activos: ref.watch(filtrosGananciasActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context),
      ),
      fila: (context, producto) =>
          _TarjetaGanancia(producto: producto, color: color),
    );
  }

  Future<void> _abrirFiltros(BuildContext context) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosGananciasActivosProvider),
      onLimpiar: () {
        ref.read(vendedorGananciasFiltroProvider.notifier).state = null;
        ref.read(categoriaGananciasFiltroProvider.notifier).state = null;
        ref.read(marcaGananciasFiltroProvider.notifier).state = null;
        ref.read(ventaGananciasFiltroProvider.notifier).state = null;
        ref.read(productoGananciasFiltroProvider.notifier).state = null;
      },
      grupos: [
        _grupo(
          'Vendedor',
          vendedorGananciasFiltroProvider,
          (o) => o.vendedores,
        ),
        _grupo(
          'Categoría',
          categoriaGananciasFiltroProvider,
          (o) => o.categorias,
        ),
        _grupo('Marca', marcaGananciasFiltroProvider, (o) => o.marcas),
        _grupo('Venta', ventaGananciasFiltroProvider, (o) => o.ventas),
        _grupo('Producto', productoGananciasFiltroProvider, (o) => o.productos),
      ],
    );
  }

  /// Un filtro de lista: elige entre lo que el servidor dice que hay en el
  /// rango. Sin opciones —todavía no llegó la respuesta— no se pinta.
  Widget _grupo(
    String titulo,
    AutoDisposeStateProvider<String?> filtro,
    List<String> Function(GananciaOpciones) opcionesDe,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final lista = opcionesDe(ref.watch(opcionesGananciasProvider));
        final valor = ref.watch(filtro);
        if (lista.isEmpty && valor == null) return const SizedBox.shrink();

        return GrupoFiltro<String?>(
          titulo: titulo,
          valor: valor,
          opciones: [
            const OpcionFiltro(null, 'Todos'),
            // Un filtro puesto con otro rango puede no estar en la lista de
            // este: se deja a la vista en vez de dar un campo vacío que sigue
            // recortando.
            if (valor != null && !lista.contains(valor))
              OpcionFiltro(valor, valor),
            for (final o in lista) OpcionFiltro(o, o),
          ],
          onCambio: (v) => ref.read(filtro.notifier).state = v,
        );
      },
    );
  }
}

/// Lo que se está mirando: el rango de ventas y lo que conviene saber de él.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.resumen,
    required this.cargados,
    required this.total,
    required this.rango,
    required this.onRango,
  });

  final GananciaResumen? resumen;

  /// Cuántos productos se trajeron y cuántos hay con esos filtros.
  final int cargados;
  final int total;

  final DateTimeRange? rango;
  final ValueChanged<DateTimeRange?> onRango;

  @override
  Widget build(BuildContext context) {
    final r = resumen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelectorRango(
            rango: rango,
            // Sin fechas el servidor cuenta lo que va del mes: se dice cuáles
            // son esos días en vez de dejar un "Este mes" sin fechas.
            textoVacio: r == null
                ? 'Este mes'
                : 'Este mes: ${_fecha(r.desde)} — ${_fecha(r.hasta)}',
            onCambio: onRango,
          ),
          // Lo que sigue solo sale cuando hay algo que avisar: este encabezado
          // no se desplaza, y en un teléfono chico cada línea de más se la
          // quita a la lista.
          if (r != null && r.lineasSinCosto > 0) ...[
            const SizedBox(height: Dimen.espacio2),
            AppAlerta(
              '${r.lineasSinCosto} ${r.lineasSinCosto == 1 ? 'producto sin costo' : 'productos sin costo'}: '
              'ahí la ganancia sale igual al precio y el total queda inflado.',
              tono: AlertaTono.aviso,
            ),
          ],
          // Cubrir mil productos en un teléfono no tiene sentido: se avisa que
          // la lista está cortada, y que los totales de arriba no lo están.
          if (total > cargados) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              'Se muestran $cargados de $total productos, los que más ganancia dejan. '
              'Los totales incluyen todos.',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaGanancia extends StatelessWidget {
  const _TarjetaGanancia({required this.producto, required this.color});

  final GananciaProducto producto;
  final Color color;

  /// Verde si se ganó, roja si se perdió plata.
  Widget get _ganancia => Text(
    formatoSoles(producto.ganancia),
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: producto.enPerdida ? Colores.peligro : Colores.exito,
    ),
  );

  List<CampoDetalle> get _campos => [
    CampoDetalle(
      'Vendido',
      '${formatoNumero(producto.cantidad)} ${producto.unidadBase}',
    ),
    CampoDetalle('Importe', formatoSoles(producto.importe)),
    CampoDetalle('Costo', formatoSoles(producto.costo)),
    CampoDetalle(
      'Ganancia',
      formatoSoles(producto.ganancia),
      widget: _ganancia,
    ),
    CampoDetalle(
      'Margen',
      producto.margen == null
          ? null
          : '${producto.margen!.toStringAsFixed(1)} %',
    ),
    CampoDetalle('Categoría', producto.categoria, enTarjeta: false),
    CampoDetalle('Marca', producto.marca, enTarjeta: false),
    // Un producto puede haber salido por varias personas y en varias ventas: en
    // la ficha se leen todas, sin cortar.
    CampoDetalle(
      'Vendedor',
      producto.vendedores.join(', '),
      widget: _lista(producto.vendedores),
      enTarjeta: false,
    ),
    CampoDetalle(
      producto.ventas == 1 ? 'Venta' : 'Ventas (${producto.ventas})',
      producto.notas.join(', '),
      widget: _lista(producto.notas),
      enTarjeta: false,
    ),
    CampoDetalle(
      'Última venta',
      _fecha(producto.ultimaVenta),
      enTarjeta: false,
    ),
  ];

  static Widget _lista(List<String> valores) => Text(
    valores.join(', '),
    textAlign: TextAlign.right,
    style: const TextStyle(fontSize: 12, color: Colores.tinta),
  );

  @override
  Widget build(BuildContext context) {
    final codigo = AppEtiqueta(producto.codigo);
    final sinCosto = producto.sinCosto
        ? const AppEtiqueta('Sin costo', tono: EtiquetaTono.aviso)
        : null;

    return AppTarjetaRegistro(
      icono: Icons.trending_up,
      color: color,
      titulo: producto.producto,
      insignia: codigo,
      estado: sinCosto,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.trending_up,
        color: color,
        titulo: producto.producto,
        subtitulo: producto.codigo,
        estado: sinCosto,
        campos: _campos,
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
