import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../datos/permiso_modelos.dart';
import '../estado/config_controlador.dart';

const _acciones = {
  'ver': 'Entrar',
  'crear': 'Crear',
  'editar': 'Editar',
  'anular': 'Anular',
  'eliminar': 'Eliminar',
  'exportar': 'Exportar',
  'importar': 'Importar',
  'confirmar': 'Confirmar',
  'cobrar': 'Cobrar',
};

/// Permisos que tiene una persona y su rol no le da.
///
/// El rol resuelve el caso general —todos los vendedores hacen lo mismo— pero
/// no el particular: uno concreto tiene que corregir hoy un pedido suyo. Sin
/// esto la única salida era subirlo de rol, que le daba de golpe todo lo que
/// ese rol puede hacer y ya no se lo quitaba nadie.
///
/// Aquí solo se consulta y se retira. Conceder se hace aprobando lo que la
/// persona pidió, en la pestaña de al lado: así queda escrito para qué era.
class ExcepcionesTab extends ConsumerWidget {
  const ExcepcionesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider).valueOrNull ?? const <Usuario>[];
    final elegido = ref.watch(usuarioExcepcionesProvider);

    // El primero de la lista mientras nadie elija: una pantalla que arranca
    // vacía parece rota, y aquí siempre hay a quién mirar.
    if (elegido == null && usuarios.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(usuarioExcepcionesProvider) == null) {
          ref.read(usuarioExcepcionesProvider.notifier).state = usuarios.first.id;
        }
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio3,
            Dimen.espacio4,
            0,
          ),
          child: AppSelector<int>(
            valor: elegido,
            etiqueta: 'Persona',
            icono: Icons.person_outline,
            opciones: [
              for (final u in usuarios) Opcion(u.id, '${u.nombre} · ${u.rol}'),
            ],
            onCambio: (v) =>
                ref.read(usuarioExcepcionesProvider.notifier).state = v,
          ),
        ),

        Expanded(
          child: ref
              .watch(excepcionesProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(Dimen.espacio4),
                  child: AppAlerta(
                    e is ApiExcepcion
                        ? e.texto
                        : 'No pudimos cargar los permisos.',
                  ),
                ),
                data: (permisos) => permisos.isEmpty
                    ? const AppVacio(
                        icono: Icons.key_off_outlined,
                        titulo: 'Sin permisos sueltos',
                        detalle:
                            'Esta persona solo puede lo que le da su rol. Lo que '
                            'pida y se le apruebe aparecerá aquí.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(Dimen.espacio4),
                        itemCount: permisos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Dimen.espacio3),
                        itemBuilder: (context, i) =>
                            _Tarjeta(permiso: permisos[i]),
                      ),
              ),
        ),
      ],
    );
  }
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({required this.permiso});

  final UsuarioPermiso permiso;

  Future<void> _revocar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Retirar el permiso',
      mensaje:
          'Dejará de poder ${(_acciones[permiso.accion] ?? permiso.accion).toLowerCase()} '
          'en ${vistaPorId(permiso.submodulo)?.titulo ?? permiso.submodulo}.',
      textoConfirmar: 'Retirar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(configApiProvider).revocarPermiso(permiso.id);
      ref.invalidate(excepcionesProvider);
      mensajero.mostrar('Permiso retirado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantalla =
        vistaPorId(permiso.submodulo)?.titulo ?? permiso.submodulo;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_acciones[permiso.accion] ?? permiso.accion} en $pantalla',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
              ),

              // Lo gastado o vencido se queda a la vista: es el historial de
              // lo que se concedió, y borrarlo esconde a quién se le dio qué.
              AppEtiqueta(
                permiso.vigente ? 'Vigente' : 'Terminado',
                tono: permiso.vigente ? EtiquetaTono.exito : EtiquetaTono.neutral,
              ),
            ],
          ),
          const SizedBox(height: 2),

          Text(
            _detalle,
            style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
          ),

          if (permiso.motivo != null && permiso.motivo!.trim().isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              permiso.motivo!,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colores.tintaSuave,
              ),
            ),
          ],

          if (permiso.vigente) ...[
            const SizedBox(height: Dimen.espacio2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _revocar(context, ref),
                icon: const Icon(Icons.block, size: 16, color: Colores.peligro),
                label: const Text(
                  'Retirar',
                  style: TextStyle(fontSize: 13, color: Colores.peligro),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hasta cuándo vale, dicho como se entiende y no como se guarda.
  String get _detalle {
    if (permiso.revocado) return 'Retirado a mano';

    return switch (permiso.alcance) {
      Alcance.unaVez => permiso.usos > 0
          ? 'De una sola vez · ya se usó'
          : 'De una sola vez · sin usar',
      Alcance.temporal => permiso.expiraEn == null
          ? 'Por un tiempo'
          : 'Vence el ${permiso.expiraEn!.day.toString().padLeft(2, '0')}/'
                '${permiso.expiraEn!.month.toString().padLeft(2, '0')}/'
                '${permiso.expiraEn!.year}',
      _ => 'Para siempre',
    };
  }
}
