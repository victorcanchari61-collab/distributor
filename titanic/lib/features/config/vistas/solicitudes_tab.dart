import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/permiso_modelos.dart';
import '../estado/config_controlador.dart';

/// Como se lee la accion pedida, sin la pantalla al lado.
const _accionPedida = {
  'ver': 'entrar',
  'crear': 'crear',
  'editar': 'editar',
  'anular': 'anular',
  'eliminar': 'eliminar',
  'exportar': 'exportar',
  'importar': 'importar',
  'confirmar': 'confirmar',
  'cobrar': 'cobrar',
};

String _pantalla(String submodulo) =>
    vistaPorId(submodulo)?.titulo ?? submodulo;

String _dia(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String _diaYHora(DateTime f) =>
    '${_dia(f)} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

/// Lo que la gente pidió al toparse con una acción bloqueada.
///
/// Se resuelve desde el teléfono porque es donde está quien aprueba cuando le
/// llega el aviso: obligarle a sentarse frente a una computadora deja parado
/// al vendedor que está delante del cliente, que es justo lo que el circuito
/// de pedir y aprobar venía a evitar.
///
/// Lo rechazado se guarda igual: que algo se pida mucho y se niegue siempre es
/// la señal de que el rol está mal repartido.
class SolicitudesTab extends ConsumerWidget {
  const SolicitudesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(solicitudesProvider);

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(Dimen.espacio4),
        child: AppAlerta(
          e is ApiExcepcion ? e.texto : 'No pudimos cargar las solicitudes.',
        ),
      ),
      data: (todas) {
        if (todas.isEmpty) {
          return const AppVacio(
            icono: Icons.inbox_outlined,
            titulo: 'Sin solicitudes',
            detalle:
                'Aquí llega lo que alguien pide al toparse con un candado.',
          );
        }

        // Lo pendiente arriba: es lo único sobre lo que hay algo que hacer.
        final pendientes = todas.where((s) => s.pendiente).toList();
        final resueltas = todas.where((s) => !s.pendiente).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(solicitudesProvider);
            await ref.read(solicitudesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(Dimen.espacio4),
            children: [
              if (pendientes.isNotEmpty) ...[
                Text(
                  pendientes.length == 1
                      ? '1 solicitud espera respuesta'
                      : '${pendientes.length} solicitudes esperan respuesta',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                const SizedBox(height: Dimen.espacio3),
                for (final s in pendientes) ...[
                  _Tarjeta(solicitud: s),
                  const SizedBox(height: Dimen.espacio3),
                ],
              ],

              if (resueltas.isNotEmpty) ...[
                const SizedBox(height: Dimen.espacio2),
                const Text(
                  'Ya resueltas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colores.tintaSuave,
                  ),
                ),
                const SizedBox(height: Dimen.espacio3),
                for (final s in resueltas) ...[
                  _Tarjeta(solicitud: s),
                  const SizedBox(height: Dimen.espacio3),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Tarjeta extends ConsumerStatefulWidget {
  const _Tarjeta({required this.solicitud});

  final SolicitudPermiso solicitud;

  @override
  ConsumerState<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends ConsumerState<_Tarjeta> {
  bool _ocupado = false;

  Future<void> _rechazar() async {
    setState(() => _ocupado = true);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(configApiProvider).rechazarSolicitud(widget.solicitud.id);
      ref.invalidate(solicitudesProvider);
      mensajero.mostrar('Solicitud rechazada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;

    final (String texto, EtiquetaTono tono) = switch (s.estado) {
      EstadoSolicitud.aprobada => ('Aprobada', EtiquetaTono.exito),
      EstadoSolicitud.rechazada => ('Rechazada', EtiquetaTono.peligro),
      _ => ('Pendiente', EtiquetaTono.aviso),
    };

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
                  s.usuario,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
              ),
              AppEtiqueta(texto, tono: tono),
            ],
          ),
          const SizedBox(height: 2),

          Text(
            'Quiere ${_accionPedida[s.accion] ?? s.accion} en '
            '${_pantalla(s.submodulo)}',
            style: const TextStyle(fontSize: 13, color: Colores.tinta),
          ),

          // El motivo lo escribió quien pide: es lo único que explica para qué
          // hace falta, y sin ello aprobar es firmar a ciegas.
          if (s.motivo != null && s.motivo!.trim().isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              s.motivo!,
              style: const TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Colores.tintaSuave,
              ),
            ),
          ],

          const SizedBox(height: Dimen.espacio2),
          Text(
            _diaYHora(s.fechaSolicitud),
            style: const TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
          ),

          if (s.pendiente) ...[
            const SizedBox(height: Dimen.espacio3),
            Row(
              children: [
                Expanded(
                  child: AppBoton(
                    texto: 'Rechazar',
                    variante: BotonVariante.secundario,
                    onPressed: _ocupado ? null : _rechazar,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: AppBoton(
                    texto: 'Aprobar',
                    onPressed: _ocupado
                        ? null
                        : () => _mostrarAprobacion(context, ref, s),
                  ),
                ),
              ],
            ),
          ],

          if (!s.pendiente &&
              s.respuesta != null &&
              s.respuesta!.trim().isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              s.respuesta!,
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aprobar es elegir hasta cuándo vale, no solo decir que sí.
Future<void> _mostrarAprobacion(
  BuildContext context,
  WidgetRef ref,
  SolicitudPermiso solicitud,
) {
  final acento = Acento.de(context);

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
    builder: (_) => Acento(
      color: acento,
      child: _HojaAprobar(solicitud: solicitud),
    ),
  );
}

class _HojaAprobar extends ConsumerStatefulWidget {
  const _HojaAprobar({required this.solicitud});

  final SolicitudPermiso solicitud;

  @override
  ConsumerState<_HojaAprobar> createState() => _HojaAprobarState();
}

class _HojaAprobarState extends ConsumerState<_HojaAprobar> {
  int _alcance = Alcance.unaVez;
  DateTime? _expira;
  final _respuesta = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _respuesta.dispose();
    super.dispose();
  }

  Future<void> _aprobar() async {
    if (_alcance == Alcance.temporal && _expira == null) {
      setState(() => _error = 'Elige hasta cuándo vale.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(configApiProvider)
          .aprobarSolicitud(
            widget.solicitud.id,
            alcance: _alcance,
            expiraEn: _alcance == Alcance.temporal ? _expira : null,
            respuesta: _respuesta.text.trim().isEmpty
                ? null
                : _respuesta.text.trim(),
          );
      ref.invalidate(solicitudesProvider);
      ref.invalidate(excepcionesProvider);
      navegador.pop();
      mensajero.mostrar('Permiso concedido');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;

    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dar ${_accionPedida[s.accion] ?? s.accion} en '
            '${_pantalla(s.submodulo)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'a ${s.usuario}',
            style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio4),

          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],

          AppSelector<int>(
            valor: _alcance,
            etiqueta: 'Hasta cuándo vale',
            icono: Icons.timelapse_outlined,
            habilitado: !_guardando,
            opciones: [
              for (final a in Alcance.todos) Opcion(a, Alcance.etiqueta(a)),
            ],
            onCambio: (v) => setState(() => _alcance = v ?? Alcance.unaVez),
          ),
          const SizedBox(height: Dimen.espacio2),
          Text(
            Alcance.explicacion(_alcance),
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),

          if (_alcance == Alcance.temporal) ...[
            const SizedBox(height: Dimen.espacio3),
            InkWell(
              onTap: _guardando
                  ? null
                  : () async {
                      final hoy = DateTime.now();
                      final elegida = await showDatePicker(
                        context: context,
                        initialDate:
                            _expira ?? hoy.add(const Duration(days: 7)),
                        firstDate: hoy,
                        lastDate: hoy.add(const Duration(days: 365)),
                      );
                      if (elegida != null) {
                        // Hasta el final de ese día: elegir "el 20" y que
                        // caduque a las 00:00 del 20 no deja ningún día útil.
                        setState(
                          () => _expira = DateTime(
                            elegida.year,
                            elegida.month,
                            elegida.day,
                            23,
                            59,
                          ),
                        );
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Vence',
                  constraints: BoxConstraints(minHeight: Dimen.campoLg),
                ),
                child: Text(
                  _expira == null ? 'Elige la fecha' : _dia(_expira!),
                  style: TextStyle(
                    fontSize: 14,
                    color: _expira == null ? Colores.tintaSuave : Colores.tinta,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: Dimen.espacio3),
          AppCampo(
            controlador: _respuesta,
            etiqueta: 'Respuesta',
            pista: 'Opcional: queda en el historial de la solicitud',
            opcional: true,
            habilitado: !_guardando,
            maxLargo: 250,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppBoton(
            texto: 'Conceder',
            cargando: _guardando,
            onPressed: _aprobar,
          ),
          const SizedBox(height: Dimen.espacio2),
        ],
      ),
    );
  }
}
