import 'package:flutter/material.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../datos/lista_precio.dart';

/// Lo que junta el formulario: listo para mandarse en un PUT de precios.
class NuevoPrecio {
  const NuevoPrecio({
    required this.presentacionId,
    required this.precio,
    required this.cantidadMinima,
  });

  final int presentacionId;
  final double precio;
  final double cantidadMinima;

  Map<String, dynamic> aCuerpo() => {
    'presentacionId': presentacionId,
    'precio': precio,
    'cantidadMinima': cantidadMinima,
  };
}

/// Hoja para agregar o editar un precio: producto, presentacion, precio y el
/// escalon por volumen desde el que aplica.
Future<NuevoPrecio?> mostrarFormularioPrecio(
  BuildContext context, {
  required List<Producto> productos,
  Precio? existente,
}) async {
  Producto? producto;
  if (existente != null) {
    for (final p in productos) {
      if (p.id == existente.productoId) producto = p;
    }
  } else {
    producto = await mostrarSelectorBuscable<Producto>(
      context: context,
      titulo: 'Elige el producto',
      items: productos.where((p) => p.activo).toList(),
      buscable: (p) => p.buscable,
      pistaBusqueda: 'Buscar por código o nombre',
      fila: (p) => Text('${p.codigo} · ${p.nombre}', style: const TextStyle(fontSize: 14)),
    );
  }
  if (producto == null || !context.mounted) return null;

  final presentaciones = producto.presentaciones.where((p) => p.esVenta && p.activo).toList();
  if (presentaciones.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto no tiene presentaciones de venta.')),
      );
    }
    return null;
  }

  int? presentacionId = existente?.presentacionId ??
      (presentaciones.length == 1 ? presentaciones.first.id : null);
  final precioCtrl = TextEditingController(
    text: existente == null ? '' : formatoNumero(existente.precio),
  );
  final cantidadMinimaCtrl = TextEditingController(
    text: existente == null ? '1' : formatoNumero(existente.cantidadMinima),
  );
  String? errorPresentacion;
  String? errorPrecio;
  String? errorCantidad;

  return showModalBottomSheet<NuevoPrecio>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Presentacion? presentacion;
          for (final p in presentaciones) {
            if (p.id == presentacionId) presentacion = p;
          }
          final precio = double.tryParse(precioCtrl.text.trim().replaceAll(',', '.'));
          final previa = precio != null && presentacion != null && presentacion.factor > 0
              ? precio / presentacion.factor
              : null;

          void guardar() {
            final precioVal = double.tryParse(precioCtrl.text.trim().replaceAll(',', '.'));
            final cantidadVal =
                double.tryParse(cantidadMinimaCtrl.text.trim().replaceAll(',', '.'));

            setSheetState(() {
              errorPresentacion = presentacionId == null ? 'Elige la presentación.' : null;
              errorPrecio = precioVal == null || precioVal < 0 ? 'Ingresa un precio válido.' : null;
              errorCantidad = cantidadVal == null || cantidadVal <= 0
                  ? 'Debe ser mayor que cero.'
                  : null;
            });
            if (errorPresentacion != null || errorPrecio != null || errorCantidad != null) {
              return;
            }

            Navigator.of(context).pop(
              NuevoPrecio(
                presentacionId: presentacionId!,
                precio: precioVal!,
                cantidadMinima: cantidadVal!,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: Dimen.espacio4,
              right: Dimen.espacio4,
              top: Dimen.espacio2,
              bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  producto!.nombre,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
                const SizedBox(height: Dimen.espacio4),
                AppSelector<int>(
                  valor: presentacionId,
                  etiqueta: 'Presentación',
                  icono: Icons.inventory_2_outlined,
                  habilitado: existente == null,
                  error: errorPresentacion,
                  opciones: [
                    for (final p in presentaciones)
                      Opcion(p.id, '${p.nombre} (${formatoNumero(p.factor)} ${producto.unidadBase})'),
                  ],
                  onCambio: (v) => setSheetState(() => presentacionId = v),
                ),
                const SizedBox(height: Dimen.espacio4),
                AppCampo(
                  controlador: precioCtrl,
                  etiqueta: 'Precio',
                  icono: Icons.payments_outlined,
                  tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                  error: errorPrecio,
                  alEnviar: () => setSheetState(() {}),
                ),
                const SizedBox(height: Dimen.espacio4),
                AppCampo(
                  controlador: cantidadMinimaCtrl,
                  etiqueta: 'Desde',
                  pista: 'Cuántas presentaciones para que aplique este precio',
                  icono: Icons.stacked_line_chart,
                  tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                  error: errorCantidad,
                ),
                if (previa != null) ...[
                  const SizedBox(height: Dimen.espacio3),
                  Container(
                    padding: const EdgeInsets.all(Dimen.espacio3),
                    decoration: BoxDecoration(
                      color: Colores.fondo,
                      borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    ),
                    child: Text(
                      'Equivale a S/ ${previa.toStringAsFixed(4)} por ${producto.unidadBase}',
                      style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                  ),
                ],
                const SizedBox(height: Dimen.espacio4),
                AppBoton(
                  texto: existente == null ? 'Agregar precio' : 'Guardar cambios',
                  onPressed: guardar,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
