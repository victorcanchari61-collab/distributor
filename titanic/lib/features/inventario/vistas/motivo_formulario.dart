import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

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
  // Fuera del builder: abrirHoja lo vuelve a llamar cuando sube el teclado y
  // se perdería el estado.
  var guardando = false;
  String? error;
  String? errorCodigo;
  String? errorNombre;

  // abrirHoja ya pasa el acento de la vista a la hoja y deja lugar al teclado.
  return abrirHoja<void>(context, (context) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        Future<void> guardar() async {
          setSheetState(() {
            errorCodigo = codigoCtrl.text.trim().isEmpty
                ? 'Ingresa el código.'
                : null;
            errorNombre = nombreCtrl.text.trim().isEmpty
                ? 'Ingresa el nombre.'
                : null;
          });
          if (errorCodigo != null || errorNombre != null) return;

          setSheetState(() {
            guardando = true;
            error = null;
          });

          final navegador = Navigator.of(context);
          final mensajero = Aviso.de(context);
          // El código va en mayúsculas, como lo escribe el panel web.
          final cuerpo = <String, dynamic>{
            'codigo': codigoCtrl.text.trim().toUpperCase(),
            'nombre': nombreCtrl.text.trim(),
            'tipo': tipo,
            if (!esNuevo) 'activo': motivo.activo,
          };

          try {
            await ref
                .read(motivosProvider.notifier)
                .guardar(id: motivo?.id, cuerpo: cuerpo);
            navegador.pop();
            mensajero.mostrar(esNuevo ? 'Motivo creado' : 'Motivo actualizado');
          } on ApiExcepcion catch (e) {
            setSheetState(() {
              guardando = false;
              error = e.texto;
            });
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoHoja(
              esNuevo ? 'Nuevo motivo' : 'Editar ${motivo.nombre}',
            ),
            Padding(
              padding: const EdgeInsets.all(Dimen.espacio4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Suma o resta stock según el tipo. Los ingresos piden '
                    'costo; las salidas lo heredan del stock que sale.',
                    style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
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
                      Opcion(TipoMotivo.entrada, 'Ingreso (suma stock)'),
                      Opcion(TipoMotivo.salida, 'Salida (resta stock)'),
                    ],
                    onCambio: (v) =>
                        setSheetState(() => tipo = v ?? TipoMotivo.entrada),
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  AppBoton(
                    texto: esNuevo ? 'Crear motivo' : 'Guardar cambios',
                    cargando: guardando,
                    onPressed: guardar,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  });
}
