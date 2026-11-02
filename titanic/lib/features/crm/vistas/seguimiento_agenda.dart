import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';
import 'crm_comun.dart';
import 'seguimiento_pagina.dart';

/// La agenda de seguimiento: a quién hay que llamar, escribir o visitar.
///
/// Es la lista detrás del aviso de la campanita ("3 contactos vencidos"): los
/// vencidos primero, después los de hoy y los de los próximos días. Cuenta lo
/// mismo que el aviso, así que los números coinciden. Se abre cuando todavía no
/// se eligió un cliente.
class SeguimientoAgenda extends ConsumerWidget {
  const SeguimientoAgenda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final todos = ref.watch(agendaTodosProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(agendaProvider.future),
      child: agenda.when(
        loading: () =>
            const _Desplazable(child: Center(child: CircularProgressIndicator())),
        error: (e, _) => _Desplazable(
          child: AppVacio(
            icono: Icons.wifi_off_outlined,
            titulo: 'No se pudo cargar la agenda',
            detalle: e is ApiExcepcion ? e.texto : null,
          ),
        ),
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            0,
            Dimen.espacio4,
            Dimen.espacio5,
          ),
          children: [
            _Resumen(agenda: a),
            const SizedBox(height: Dimen.espacio3),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Mis contactos')),
                ButtonSegment(value: true, label: Text('Todos')),
              ],
              selected: {todos},
              onSelectionChanged: (s) =>
                  ref.read(agendaTodosProvider.notifier).state = s.first,
            ),
            const SizedBox(height: Dimen.espacio3),
            if (a.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: Dimen.espacio6),
                child: AppVacio(
                  icono: Icons.event_available_outlined,
                  titulo: 'No hay contactos programados',
                  detalle:
                      'Cuando registres una gestión y dejes programado el '
                      'siguiente contacto, aparecerá aquí. También puedes '
                      'buscar un cliente arriba.',
                ),
              )
            else ...[
              _Grupo('Vencidos', [
                for (final i in a.items)
                  if (i.vencida) i,
              ]),
              _Grupo('Hoy', [
                for (final i in a.items)
                  if (i.esHoy) i,
              ]),
              _Grupo('Próximos ${a.dias} días', [
                for (final i in a.items)
                  if (!i.vencida && !i.esHoy) i,
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// El contenido de un estado sin lista, pero que igual se puede estirar para actualizar.
class _Desplazable extends StatelessWidget {
  const _Desplazable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: c.maxHeight, child: child),
    ),
  );
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.agenda});

  final AgendaSeguimiento agenda;

  @override
  Widget build(BuildContext context) {
    Widget cifra(String etiqueta, int n, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Dimen.espacio3),
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: n == 0 ? Colores.tintaSuave : color,
              ),
            ),
            Text(
              etiqueta,
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        cifra('Vencidos', agenda.vencidos, Colores.peligro),
        const SizedBox(width: Dimen.espacio2),
        cifra('Hoy', agenda.hoy, Colores.advertencia),
        const SizedBox(width: Dimen.espacio2),
        cifra('Próximos', agenda.proximos, Acento.de(context)),
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo(this.titulo, this.items);

  final String titulo;
  final List<AgendaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Dimen.espacio3, bottom: 6),
          child: Text(
            '$titulo · ${items.length}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        for (final i in items) ...[
          _Fila(item: i),
          const SizedBox(height: Dimen.espacio2),
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final tipo = item.tipoContacto;
    final cuando = item.vencida
        ? 'Venció ${fechaHora(item.proximo)}'
        : fechaHora(item.proximo);

    return Material(
      color: Colores.superficie,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: item.vencida ? Colores.peligro : Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
        // Se entra directo a la pestaña de seguimiento: es lo que se viene a hacer.
        onTap: () => context.go(
          '${SeguimientoPagina.ruta}?cliente=${item.clienteId}&pestana=seguimiento',
        ),
        child: Padding(
          padding: const EdgeInsets.all(Dimen.espacio3),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorDeTono(item.tono),
                child: Icon(
                  tipo?.icono ?? Icons.event_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        item.tipoEtiqueta,
                        if (item.proximaAccion != null) item.proximaAccion!,
                      ].join(' — '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colores.tintaSuave,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cuando,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.vencida
                            ? Colores.peligro
                            : Colores.tintaSuave,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.telefono != null) ...[
                IconButton(
                  tooltip: 'Llamar',
                  icon: const Icon(Icons.call_outlined, color: Colores.exito),
                  onPressed: () => _llamar(context, item.telefono!),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  icon: const Icon(Icons.chat_outlined, color: Colores.exito),
                  onPressed: () => abrirWhatsapp(context, item.telefono!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _llamar(BuildContext context, String telefono) async {
    final aviso = Aviso.de(context);
    final ok = await launchUrl(Uri(scheme: 'tel', path: telefono));
    if (!ok) aviso.error('No pudimos abrir el teléfono.');
  }
}
