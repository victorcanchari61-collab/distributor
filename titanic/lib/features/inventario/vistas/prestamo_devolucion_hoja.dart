import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/prestamo.dart';
import '../estado/inventario_controlador.dart';

/// Hoja para registrar una devolucion, total o parcial, de un prestamo.
Future<void> mostrarHojaDevolucion(
  BuildContext context,
  WidgetRef ref, {
  required Prestamo prestamo,
}) {
  final pendientes = prestamo.detalle.where((d) => d.cantidadPendiente > 0).toList();
  final controladores = {
    for (final d in pendientes) d.id: TextEditingController(text: formatoNumero(d.cantidadPendiente)),
  };

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) {
      var guardando = false;
      String? error;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> guardar() async {
            final lineas = <Map<String, dynamic>>[];
            for (final d in pendientes) {
              final cantidad = double.tryParse(
                controladores[d.id]!.text.trim().replaceAll(',', '.'),
              );
              if (cantidad != null && cantidad > 0) {
                lineas.add({'prestamoDetalleId': d.id, 'cantidad': cantidad});
              }
            }
            if (lineas.isEmpty) {
              setSheetState(() => error = 'Ingresa cuánto se devuelve de al menos un producto.');
              return;
            }

            setSheetState(() {
              guardando = true;
              error = null;
            });

            final navegador = Navigator.of(context);
            final mensajero = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(prestamosProvider.notifier)
                  .devolver(prestamo.id, {'detalle': lineas});
              navegador.pop();
              mensajero.showSnackBar(const SnackBar(content: Text('Devolución registrada')));
            } on ApiExcepcion catch (e) {
              setSheetState(() {
                guardando = false;
                error = e.texto;
              });
            }
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
                  'Devolución de ${prestamo.numero}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
                const SizedBox(height: Dimen.espacio4),
                if (error != null) ...[
                  AppAlerta(error!),
                  const SizedBox(height: Dimen.espacio3),
                ],
                for (final d in pendientes) ...[
                  Text(
                    d.producto,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colores.tinta),
                  ),
                  const SizedBox(height: Dimen.espacio1),
                  AppCampo(
                    controlador: controladores[d.id]!,
                    etiqueta: 'Devuelve (${d.unidadBase}) · pendiente ${formatoNumero(d.cantidadPendiente)}',
                    tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                    habilitado: !guardando,
                  ),
                  const SizedBox(height: Dimen.espacio3),
                ],
                AppBoton(
                  texto: 'Registrar devolución',
                  cargando: guardando,
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
