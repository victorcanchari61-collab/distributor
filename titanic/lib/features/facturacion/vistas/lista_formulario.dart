import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/lista_precio.dart';
import '../estado/facturacion_controlador.dart';

/// Hoja para crear o editar una lista de precios.
Future<ListaPrecio?> mostrarFormularioLista(
  BuildContext context,
  WidgetRef ref, {
  ListaPrecio? lista,
}) {
  final nombreCtrl = TextEditingController(text: lista?.nombre ?? '');
  final descripcionCtrl = TextEditingController(text: lista?.descripcion ?? '');
  final esNueva = lista == null;

  return showModalBottomSheet<ListaPrecio>(
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
      String? errorNombre;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> guardar() async {
            setSheetState(() {
              errorNombre = nombreCtrl.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
            });
            if (errorNombre != null) return;

            setSheetState(() {
              guardando = true;
              error = null;
            });

            final navegador = Navigator.of(context);
            final cuerpo = <String, dynamic>{
              'nombre': nombreCtrl.text.trim(),
              'descripcion': descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
              if (esNueva) 'esPredeterminada': false,
              if (!esNueva) 'activo': lista.activo,
            };

            try {
              if (esNueva) {
                final creada = await ref.read(listasPrecioProvider.notifier).crear(cuerpo);
                navegador.pop(creada);
              } else {
                await ref.read(listasPrecioProvider.notifier).actualizar(lista.id, cuerpo);
                navegador.pop();
              }
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
                  esNueva ? 'Nueva lista de precios' : 'Editar lista',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
                const SizedBox(height: Dimen.espacio4),
                if (error != null) ...[
                  AppAlerta(error!),
                  const SizedBox(height: Dimen.espacio3),
                ],
                AppCampo(
                  controlador: nombreCtrl,
                  etiqueta: 'Nombre',
                  pista: 'Mayorista, Minorista, Distribuidores...',
                  icono: Icons.sell_outlined,
                  error: errorNombre,
                  habilitado: !guardando,
                ),
                const SizedBox(height: Dimen.espacio4),
                AppCampo(
                  controlador: descripcionCtrl,
                  etiqueta: 'Descripción',
                  icono: Icons.notes_outlined,
                  opcional: true,
                  maxLargo: 250,
                  habilitado: !guardando,
                ),
                const SizedBox(height: Dimen.espacio4),
                AppBoton(
                  texto: esNueva ? 'Crear lista' : 'Guardar cambios',
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
