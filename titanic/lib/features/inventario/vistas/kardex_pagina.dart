import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../datos/kardex.dart';
import '../estado/inventario_controlador.dart';
import 'almacen_tabs.dart';

/// Todo lo que entró y salió, con el saldo que dejó cada movimiento.
///
/// Solo lectura. Lo alimentan hoy los ajustes; mañana también las compras y
/// las ventas, todos por el mismo camino.
class KardexPagina extends ConsumerWidget {
  const KardexPagina({super.key});

  static const ruta = '/inv/kardex';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(kardexProvider).valueOrNull ?? const <MovimientoKardex>[];
    final almacenes = ref.watch(almacenesActivosProvider);
    final almacenId = ref.watch(almacenKardexProvider);

    final entradas = todos.where((k) => k.esEntrada).length;
    final salidas = todos.length - entradas;

    return AppListaPagina<MovimientoKardex>(
      titulo: 'Kardex',
      ruta: ruta,
      estado: ref.watch(kardexProvider),
      visibles: ref.watch(kardexFiltradoProvider),
      busqueda: ref.watch(busquedaKardexProvider),
      onBuscar: (t) => ref.read(busquedaKardexProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por documento, motivo o producto',
      onRecargar: () async {
        ref.invalidate(kardexProvider);
        await ref.read(kardexProvider.future);
      },
      iconoVacio: Icons.menu_book_outlined,
      singular: 'movimiento',
      plural: 'movimientos',
      detalleVacio: 'Se generan al registrar un ajuste.',
      encabezado: AlmacenTabs(
        almacenes: almacenes,
        valor: almacenId,
        color: color,
        onCambio: (v) => ref.read(almacenKardexProvider.notifier).state = v,
      ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Entradas',
          valor: '$entradas',
          icono: Icons.arrow_downward_rounded,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Salidas',
          valor: '$salidas',
          icono: Icons.arrow_upward_rounded,
          tono: DatoTono.aviso,
        ),
      ],
      fila: (context, movimiento) => _TarjetaKardex(movimiento: movimiento, color: color),
    );
  }
}

class _TarjetaKardex extends StatelessWidget {
  const _TarjetaKardex({required this.movimiento, required this.color});

  final MovimientoKardex movimiento;
  final Color color;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Fecha', _fecha(movimiento.fecha)),
    CampoDetalle(
      'Motivo',
      movimiento.motivo,
      widget: !movimiento.anulado
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    movimiento.motivo,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colores.tinta),
                  ),
                ),
                const SizedBox(width: 6),
                const AppEtiqueta('Anulado', tono: EtiquetaTono.peligro),
              ],
            ),
    ),
    CampoDetalle('Producto', movimiento.producto),
    CampoDetalle('Almacén', movimiento.almacen, enTarjeta: false),
    CampoDetalle(
      'Cantidad',
      movimiento.presentacion == null
          ? '${movimiento.cantidadPresentacion} ${movimiento.unidadBase}'
          : '${movimiento.cantidadPresentacion} ${movimiento.presentacion}',
      enTarjeta: false,
    ),
    CampoDetalle(
      'En unidad base',
      '${movimiento.esEntrada ? '+' : '−'}${movimiento.cantidad} ${movimiento.unidadBase}',
      widget: Text(
        '${movimiento.esEntrada ? '+' : '−'}${movimiento.cantidad} ${movimiento.unidadBase}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: movimiento.esEntrada ? Colores.exito : Colores.advertencia,
        ),
      ),
    ),
    CampoDetalle('Costo', 'S/ ${movimiento.costoTotal.toStringAsFixed(2)}', enTarjeta: false),
    CampoDetalle('Saldo', '${movimiento.saldo} ${movimiento.unidadBase}'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: movimiento.esEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
      color: movimiento.esEntrada ? Colores.exito : Colores.advertencia,
      titulo: movimiento.documento,
      insignia: AppEtiqueta(
        movimiento.esEntrada ? 'Ingreso' : 'Salida',
        tono: movimiento.esEntrada ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: movimiento.esEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        color: movimiento.esEntrada ? Colores.exito : Colores.advertencia,
        titulo: movimiento.documento,
        subtitulo: movimiento.producto,
        campos: _campos,
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
