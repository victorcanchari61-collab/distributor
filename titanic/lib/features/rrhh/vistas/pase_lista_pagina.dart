import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/asistencia.dart';
import '../estado/asistencia_controlador.dart';

/// El pase de lista de un dia: todos los empleados en una lista, cada uno con
/// su estado, y se guarda todo junto. A quien ya tenia marca se le corrige.
///
/// Igual que en el panel web: salen los que trabajaban ese dia segun su fecha
/// de ingreso y de cese, y tocar otra vez el estado elegido lo quita mientras
/// no este guardado. Una marca ya guardada se anula desde el registro.
class PaseListaPagina extends ConsumerStatefulWidget {
  const PaseListaPagina({super.key, required this.fecha});

  final DateTime fecha;

  @override
  ConsumerState<PaseListaPagina> createState() => _PaseListaPaginaState();
}

class _Fila {
  _Fila({this.estado, this.observacion = ''});

  String? estado;
  String observacion;
}

class _PaseListaPaginaState extends ConsumerState<PaseListaPagina> {
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String? _feriado;

  List<EmpleadoAsistencia> _lista = const [];
  Map<int, Asistencia> _marcaDe = const {};
  final Map<int, _Fila> _filas = {};
  final Map<int, TextEditingController> _observaciones = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _observaciones.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Si esa persona trabajaba ese dia: ya habia entrado y todavia no cesaba. Desactivado sin
  /// fecha de cese no cuenta: no se sabe hasta cuando trabajo (el servidor tampoco lo deja marcar).
  bool _trabajaba(EmpleadoAsistencia e) {
    final dia = DateUtils.dateOnly(widget.fecha);
    final ingreso = e.fechaIngreso;
    final cese = e.fechaCese;
    return (e.activo || cese != null) &&
        (ingreso == null || !DateUtils.dateOnly(ingreso).isAfter(dia)) &&
        (cese == null || !DateUtils.dateOnly(cese).isBefore(dia));
  }

  Future<void> _cargar() async {
    final api = ref.read(rrhhApiProvider);
    try {
      final resultados = await Future.wait([
        // Los de Asistencia, con su propio permiso: no hace falta poder ver Empleados.
        api.empleadosAsistencia(),
        api.asistencias(widget.fecha, widget.fecha),
        api.feriados(),
      ]);
      final empleados = resultados[0] as List<EmpleadoAsistencia>;
      final marcas = (resultados[1] as List<Asistencia>).where(
        (m) => !m.anulado,
      );
      final feriados = resultados[2] as List<Feriado>;

      final marcaDe = {for (final m in marcas) m.empleadoId: m};
      final lista =
          empleados
              .where((e) => _trabajaba(e) || marcaDe.containsKey(e.id))
              .toList()
            ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

      for (final e in lista) {
        final m = marcaDe[e.id];
        _filas[e.id] = _Fila(
          estado: m?.estado,
          observacion: m?.observacion ?? '',
        );
        _observaciones[e.id] = TextEditingController(
          text: m?.observacion ?? '',
        );
      }

      setState(() {
        _lista = lista;
        _marcaDe = marcaDe;
        _feriado = feriados
            .where((f) => mismoDia(f.fecha, widget.fecha))
            .map((f) => f.nombre)
            .firstOrNull;
        _cargando = false;
      });
    } on ApiExcepcion catch (e) {
      setState(() {
        _error = e.texto;
        _cargando = false;
      });
    }
  }

  bool _bloqueada(int id, bool puedeCorregir) =>
      _marcaDe.containsKey(id) && !puedeCorregir;

  void _elegir(int id, String estado) {
    final fila = _filas[id]!;
    setState(() {
      // Tocar otra vez el estado elegido lo quita, pero solo si todavia no
      // esta guardado: una marca ya registrada se anula desde el registro.
      if (fila.estado == estado && !_marcaDe.containsKey(id)) {
        fila.estado = null;
        fila.observacion = '';
        _observaciones[id]!.clear();
      } else {
        fila.estado = estado;
      }
    });
  }

  void _presentesLosQueFaltan() {
    setState(() {
      for (final e in _lista) {
        _filas[e.id]!.estado ??= EstadoAsistencia.presente;
      }
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    final cambios = <Map<String, dynamic>>[];
    for (final e in _lista) {
      final fila = _filas[e.id]!;
      if (fila.estado == null) continue;
      final observacion = _observaciones[e.id]!.text.trim();
      final original = _marcaDe[e.id];
      // Lo que no cambio no se manda: corregir una marca pide permiso de
      // editar, y reenviarla igual lo exigiria sin razon.
      if (original != null &&
          original.estado == fila.estado &&
          (original.observacion ?? '') == observacion) {
        continue;
      }
      cambios.add({
        'empleadoId': e.id,
        'estado': fila.estado,
        'observacion': observacion.isEmpty ? null : observacion,
      });
    }

    if (cambios.isEmpty) {
      setState(() => _error = 'No hay cambios para guardar.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      final r = await ref
          .read(rrhhApiProvider)
          .marcarDia(widget.fecha, cambios);
      final partes = [
        if (r.creadas > 0)
          '${r.creadas} registrada${r.creadas == 1 ? '' : 's'}',
        if (r.corregidas > 0)
          '${r.corregidas} corregida${r.corregidas == 1 ? '' : 's'}',
      ];
      navegador.pop();
      mensajero.mostrar('Asistencia guardada: ${partes.join(', ')}');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeCorregir = puede(ref, 'rrhh.asistencia', Accion.editar);
    final marcados = _lista.where((e) => _filas[e.id]?.estado != null).length;
    final sinMarcar = _lista.length - marcados;
    final f = widget.fecha;
    final titulo =
        'Asistencia del ${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

    return Acento.modulo(
      'rrhh',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        bottomNavigationBar: _cargando || _lista.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Dimen.espacio4),
                  child: AppBoton(
                    texto: 'Guardar asistencia',
                    icono: Icons.check,
                    cargando: _guardando,
                    onPressed: _guardar,
                  ),
                ),
              ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(Dimen.espacio4),
                children: [
                  if (_error != null) ...[
                    AppAlerta(_error!),
                    const SizedBox(height: Dimen.espacio3),
                  ],
                  if (_feriado != null) ...[
                    AppAlerta(
                      'Feriado: $_feriado. A quien trabaje este día se le paga doble en la planilla.',
                      tono: AlertaTono.aviso,
                    ),
                    const SizedBox(height: Dimen.espacio3),
                  ],
                  if (_lista.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(Dimen.espacio5),
                      child: Text(
                        'Nadie trabajaba en esta fecha según su fecha de ingreso y cese.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colores.tintaSuave),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Marcados ',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colores.tintaSuave,
                            ),
                            children: [
                              TextSpan(
                                text: '$marcados',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colores.tinta,
                                ),
                              ),
                              TextSpan(text: ' de ${_lista.length}'),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (sinMarcar > 0)
                          TextButton.icon(
                            onPressed: _guardando
                                ? null
                                : _presentesLosQueFaltan,
                            icon: const Icon(Icons.done_all, size: 18),
                            label: Text(
                              'Presentes los que faltan ($sinMarcar)',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Dimen.espacio2),
                    for (final e in _lista)
                      _FilaEmpleado(
                        empleado: e,
                        fila: _filas[e.id]!,
                        observacion: _observaciones[e.id]!,
                        bloqueada: _bloqueada(e.id, puedeCorregir),
                        habilitada: !_guardando,
                        onElegir: (estado) => _elegir(e.id, estado),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Un empleado con sus cuatro estados y, si no vino a tiempo, la observacion.
class _FilaEmpleado extends StatelessWidget {
  const _FilaEmpleado({
    required this.empleado,
    required this.fila,
    required this.observacion,
    required this.bloqueada,
    required this.habilitada,
    required this.onElegir,
  });

  final EmpleadoAsistencia empleado;
  final _Fila fila;
  final TextEditingController observacion;

  /// Ya tiene marca y quien pasa lista no puede corregir.
  final bool bloqueada;
  final bool habilitada;
  final ValueChanged<String> onElegir;

  Color _colorDe(BuildContext context, String estado) => switch (estado) {
    EstadoAsistencia.presente => Colores.exito,
    EstadoAsistencia.tardanza => Colores.advertencia,
    EstadoAsistencia.falta => Colores.peligro,
    _ => Acento.de(context),
  };

  @override
  Widget build(BuildContext context) {
    final activo = habilitada && !bloqueada;

    return Container(
      margin: const EdgeInsets.only(bottom: Dimen.espacio2),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            empleado.nombreCompleto,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            '${empleado.cargo?.trim().isNotEmpty == true ? empleado.cargo : 'Sin cargo'}'
            '${bloqueada ? ' · ya marcado (corregir pide permiso de editar)' : ''}',
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio2),
          Row(
            children: [
              for (final estado in EstadoAsistencia.todos) ...[
                Expanded(
                  child: _BotonEstado(
                    texto: EstadoAsistencia.etiqueta(estado),
                    color: _colorDe(context, estado),
                    elegido: fila.estado == estado,
                    onTap: activo ? () => onElegir(estado) : null,
                  ),
                ),
                if (estado != EstadoAsistencia.todos.last)
                  const SizedBox(width: Dimen.espacio1),
              ],
            ],
          ),
          if (fila.estado != null &&
              fila.estado != EstadoAsistencia.presente &&
              !bloqueada) ...[
            const SizedBox(height: Dimen.espacio2),
            TextField(
              controller: observacion,
              enabled: habilitada,
              decoration: const InputDecoration(
                hintText: 'Observación: minutos de tardanza, motivo...',
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BotonEstado extends StatelessWidget {
  const _BotonEstado({
    required this.texto,
    required this.color,
    required this.elegido,
    required this.onTap,
  });

  final String texto;
  final Color color;
  final bool elegido;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !elegido ? 0.5 : 1,
      child: Material(
        color: elegido ? color : Colores.superficie,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: elegido ? color : Colores.lineaFuerte),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: elegido ? Colors.white : Colores.tintaSuave,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
