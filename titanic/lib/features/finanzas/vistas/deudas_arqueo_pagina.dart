import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/arqueo.dart';
import '../estado/arqueo_controlador.dart';
import 'arqueo_pagina.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Lo que debe cada persona por los faltantes de sus cuadres.
///
/// Va aparte de la lista de cuadres porque se mira en otro momento: no al
/// cerrar el día, sino cuando toca descontar en planilla.
class DeudasArqueoPagina extends ConsumerWidget {
  const DeudasArqueoPagina({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(deudasProvider);

    return Acento.modulo(
      'finanzas',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Deudas por faltantes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: estado.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Dimen.espacio4),
              child: AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las deudas.',
              ),
            ),
          ),
          data: (deudas) => deudas.isEmpty
              ? const AppVacio(
                  icono: Icons.verified_outlined,
                  titulo: 'Nadie debe nada',
                  detalle: 'Ningún cuadre quedó con faltante pendiente.',
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(deudasProvider.notifier).recargar(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Dimen.espacio4),
                    itemCount: deudas.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Dimen.espacio3),
                    itemBuilder: (_, i) => _TarjetaDeuda(
                      deuda: deudas[i],
                      onSaldar: (arqueo) =>
                          _saldar(context, ref, deudas[i], arqueo),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _saldar(
    BuildContext context,
    WidgetRef ref,
    DeudaUsuario deuda,
    ArqueoCaja arqueo,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Marcar como descontado',
      mensaje:
          'El faltante de ${formatoSoles(arqueo.faltante)} del ${fechaCorta(arqueo.fecha)} '
          'deja de contar como deuda de ${deuda.usuario}. Hazlo cuando ya se le descontó '
          'o repuso el dinero.',
      textoConfirmar: 'Descontado',
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(deudasProvider.notifier).saldar(arqueo.id);
      mensajero.mostrar('Faltante saldado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaDeuda extends StatelessWidget {
  const _TarjetaDeuda({required this.deuda, required this.onSaldar});

  final DeudaUsuario deuda;
  final void Function(ArqueoCaja arqueo) onSaldar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTarjetaRegistro(
          icono: Icons.person_outline,
          color: Acento.de(context),
          titulo: deuda.usuario,
          insignia: AppEtiqueta(
            formatoSoles(deuda.pendiente),
            tono: EtiquetaTono.peligro,
          ),
          campos: [
            CampoDetalle('Días con faltante', '${deuda.dias}'),
            CampoDetalle('Ya saldado', formatoSoles(deuda.saldado)),
          ],
        ),
        // Los días uno a uno bajo la tarjeta: se descuenta faltante por
        // faltante, no la deuda entera de golpe.
        for (final arqueo in deuda.detalle)
          Padding(
            padding: const EdgeInsets.only(
              left: Dimen.espacio4,
              right: Dimen.espacio2,
              top: Dimen.espacio2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fechaCorta(arqueo.fecha),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ),
                Text(
                  formatoSoles(arqueo.faltante),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colores.peligro,
                  ),
                ),
                const SizedBox(width: Dimen.espacio2),
                TextButton(
                  onPressed: () => onSaldar(arqueo),
                  child: const Text('Descontado'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
