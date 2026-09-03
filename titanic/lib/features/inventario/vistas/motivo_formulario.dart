import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';

/// Hoja para crear o editar un motivo manual de ajuste.
Future<void> mostrarFormularioMotivo(
  BuildContext context,
  WidgetRef ref, {
  Motivo? motivo,
}) {
  final codigoCtrl = TextEditingController(text: motivo?.codigo ?? '');
  final nombreCtrl = TextEditingController(text: motivo?.nombre ?? '');
  String tipo = motivo?.tipo ?? TipoMotivo.entrada;
  final esNuevo = motivo == null;

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
      String? errorCodigo;
      String? errorNombre;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> guardar() async {
            setSheetState(() {
              errorCodigo = codigoCtrl.text.trim().isEmpty ? 'Ingresa el código.' : null;
              errorNombre = nombreCtrl.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
            });
            if (errorCodigo != null || errorNombre != null) return;

            setSheetState(() {
              guardando = true;
              error = null;
            });

            final navegador = Navigator.of(context);
            final mensajero = ScaffoldMessenger.of(context);
            final cuerpo = <String, dynamic>{
              'codigo': codigoCtrl.text.trim(),
              'nombre': nombreCtrl.text.trim(),
              'tipo': tipo,
              if (!esNuevo) 'activo': motivo.activo,
            };

            try {
              await ref
                  .read(motivosProvider.notifier)
                  .guardar(id: motivo?.id, cuerpo: cuerpo);
              navegador.pop();
              mensajero.showSnackBar(
                SnackBar(content: Text(esNuevo ? 'Motivo creado' : 'Motivo actualizado')),
              );
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
                  esNuevo ? 'Nuevo motivo' : 'Editar motivo',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
                const SizedBox(height: Dimen.espacio4),
                if (error != null) ...[
                  AppAlerta(error!),
                  const SizedBox(height: Dimen.espacio3),
                ],
                AppCampo(
                  controlador: codigoCtrl,
                  etiqueta: 'Código',
                  pista: 'MERMA, DONACION...',
                  icono: Icons.tag,
                  maxLargo: 20,
                  error: errorCodigo,
                  habilitado: !guardando,
                ),
                const SizedBox(height: Dimen.espacio4),
                AppCampo(
                  controlador: nombreCtrl,
                  etiqueta: 'Nombre',
                  icono: Icons.label_outline,
                  error: errorNombre,
                  habilitado: !guardando,
                ),
                const SizedBox(height: Dimen.espacio4),
                AppSelector<String>(
                  valor: tipo,
                  etiqueta: 'Tipo',
                  icono: Icons.swap_vert,
                  habilitado: !guardando,
                  opciones: const [
                    Opcion(TipoMotivo.entrada, 'Entrada'),
                    Opcion(TipoMotivo.salida, 'Salida'),
                  ],
                  onCambio: (v) => setSheetState(() => tipo = v ?? TipoMotivo.entrada),
                ),
                const SizedBox(height: Dimen.espacio4),
                AppBoton(
                  texto: esNuevo ? 'Crear motivo' : 'Guardar cambios',
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
