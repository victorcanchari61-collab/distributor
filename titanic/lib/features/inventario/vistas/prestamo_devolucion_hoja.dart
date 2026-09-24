import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/prestamo.dart';
import '../estado/inventario_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Hoja para ver el historial de devoluciones de un prestamo, anular una que
/// se registro mal, y registrar una nueva — total o parcial.
Future<void> mostrarHojaDevolucion(
  BuildContext context,
  WidgetRef ref, {
  required Prestamo prestamo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (context) {
      // Vive fuera del StatefulBuilder para sobrevivir entre setSheetState:
      // se reemplaza tras registrar o anular una devolucion, para que la hoja
      // muestre el historial al dia sin tener que cerrarla y reabrirla.
      var prestamoActual = prestamo;
      var guardando = false;
      String? error;
      Map<int, TextEditingController> controladores = {
        for (final d in prestamoActual.detalle.where(
          (d) => d.cantidadPendiente > 0,
        ))
          d.id: TextEditingController(text: formatoNumero(d.cantidadPendiente)),
      };

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final pendientes = prestamoActual.detalle
              .where((d) => d.cantidadPendiente > 0)
              .toList();

          Future<void> refrescar() async {
            final fresco = await ref
                .read(prestamosProvider.notifier)
                .refrescarUno(prestamoActual.id);
            setSheetState(() {
              prestamoActual = fresco;
              controladores = {
                for (final d in fresco.detalle.where(
                  (d) => d.cantidadPendiente > 0,
                ))
                  d.id: TextEditingController(
                    text: formatoNumero(d.cantidadPendiente),
                  ),
              };
            });
          }

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
              setSheetState(
                () => error =
                    'Ingresa cuánto se devuelve de al menos un producto.',
              );
              return;
            }

            setSheetState(() {
              guardando = true;
              error = null;
            });

            final mensajero = Aviso.de(context);
            try {
              await ref
                  .read(prestamosProvider.notifier)
                  .devolver(prestamoActual.id, {'detalle': lineas});
              await refrescar();
              setSheetState(() => guardando = false);
              mensajero.mostrar('Devolución registrada');
            } on ApiExcepcion catch (e) {
              setSheetState(() {
                guardando = false;
                error = e.texto;
              });
            }
          }

          Future<void> anular(PrestamoDevolucion d) async {
            final ok = await confirmarAccion(
              context,
              titulo: 'Anular devolución ${d.numero}',
              mensaje:
                  'Revierte el stock que movió esta devolución y la línea del '
                  'préstamo vuelve a quedar pendiente por esa cantidad. No se '
                  'puede deshacer.',
              textoConfirmar: 'Anular',
              tono: ConfirmTono.peligro,
            );
            if (!ok || !context.mounted) return;

            final mensajero = Aviso.de(context);
            try {
              await ref
                  .read(prestamosProvider.notifier)
                  .anularDevolucion(d.id);
              await refrescar();
              mensajero.mostrar('Devolución anulada');
            } on ApiExcepcion catch (e) {
              mensajero.error(e.texto);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: Dimen.espacio4,
              right: Dimen.espacio4,
              top: Dimen.espacio2,
              bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Devolución de ${prestamoActual.numero}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colores.tinta,
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio2),
                  // Con qué almacén queda: la devolución siempre va al mismo
                  // almacén con el que se registró el préstamo (no se elige
                  // otro), pero hay que verlo antes de confirmar.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimen.espacio3,
                      vertical: Dimen.espacio2,
                    ),
                    decoration: BoxDecoration(
                      color: Colores.fondo,
                      borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colores.tintaSuave,
                        ),
                        children: [
                          TextSpan(
                            text: prestamoActual.esDado ? 'Vuelve a ' : 'Sale de ',
                          ),
                          TextSpan(
                            text: prestamoActual.almacen,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colores.tinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (prestamoActual.devoluciones.isNotEmpty) ...[
                    const SizedBox(height: Dimen.espacio4),
                    const Text(
                      'Devoluciones registradas',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                    const SizedBox(height: Dimen.espacio2),
                    for (final d in prestamoActual.devoluciones) ...[
                      _FilaDevolucion(devolucion: d, onAnular: () => anular(d)),
                      const SizedBox(height: Dimen.espacio2),
                    ],
                  ],

                  const SizedBox(height: Dimen.espacio2),
                  if (error != null) ...[
                    AppAlerta(error!),
                    const SizedBox(height: Dimen.espacio3),
                  ],

                  if (pendientes.isNotEmpty) ...[
                    const Text(
                      'Registrar nueva devolución',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                    const SizedBox(height: Dimen.espacio2),
                    for (final d in pendientes) ...[
                      Text(
                        d.producto,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colores.tinta,
                        ),
                      ),
                      const SizedBox(height: Dimen.espacio1),
                      AppCampo(
                        controlador: controladores[d.id]!,
                        etiqueta:
                            'Devuelve (${d.unidadBase}) · pendiente ${formatoNumero(d.cantidadPendiente)}',
                        tipoTeclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        habilitado: !guardando,
                      ),
                      const SizedBox(height: Dimen.espacio3),
                    ],
                    AppBoton(
                      texto: 'Registrar devolución',
                      cargando: guardando,
                      onPressed: guardar,
                    ),
                  ] else
                    const Text(
                      'Ya se devolvió todo. Anula una devolución si hace '
                      'falta corregir algo.',
                      style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

class _FilaDevolucion extends StatelessWidget {
  const _FilaDevolucion({required this.devolucion, required this.onAnular});

  final PrestamoDevolucion devolucion;
  final VoidCallback onAnular;

  @override
  Widget build(BuildContext context) {
    final resumen = devolucion.detalle.length == 1
        ? '${devolucion.detalle.first.producto} · '
              '${formatoNumero(devolucion.detalle.first.cantidadPresentacion)} '
              '${devolucion.detalle.first.presentacion ?? devolucion.detalle.first.unidadBase}'
        : '${devolucion.detalle.length} productos';

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      devolucion.numero,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio2),
                    AppEtiqueta(
                      devolucion.anulada ? 'Anulada' : 'Confirmada',
                      tono: devolucion.anulada
                          ? EtiquetaTono.peligro
                          : EtiquetaTono.exito,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$resumen · ${_fecha(devolucion.fecha)}',
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => mostrarOpcionesPdf(
              context,
              documento: DocumentoPdf.devolucionPrestamo,
              id: devolucion.id,
              numero: devolucion.numero,
            ),
            tooltip: 'PDF',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
          ),
          if (!devolucion.anulada)
            IconButton(
              onPressed: onAnular,
              tooltip: 'Anular',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.undo_rounded,
                size: 19,
                color: Colores.peligro,
              ),
            ),
        ],
      ),
    );
  }
}
