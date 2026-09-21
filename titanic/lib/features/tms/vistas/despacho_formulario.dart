import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/catalogo_listo.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/despacho.dart';
import '../datos/flota.dart';
import '../datos/ruta.dart';
import '../estado/despachos_controlador.dart';
import '../estado/tms_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

String _fechaTexto(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);

/// Los días como los guarda el backend, en el orden de `DateTime.weekday` (lunes = 1).
const _dias = ['LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO'];
const _diasTexto = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// Alta y edicion de un despacho: elegir el camion y marcar los pedidos que
/// suben, entre el rango de fechas en que se tomaron.
class DespachoFormulario extends ConsumerStatefulWidget {
  const DespachoFormulario({super.key, this.despacho});

  final Despacho? despacho;

  @override
  ConsumerState<DespachoFormulario> createState() => _DespachoFormularioState();
}

class _DespachoFormularioState extends ConsumerState<DespachoFormulario> {
  late final _observacion = TextEditingController(text: widget.despacho?.observacion ?? '');

  late DateTime _fecha = widget.despacho?.fecha ?? DateTime.now();
  late DateTime _desde = widget.despacho?.pedidosDesde ?? _diaMasTemprano();
  late DateTime _hasta = widget.despacho?.pedidosHasta ?? DateTime.now();

  /// Las rutas que carga el camión ese día: el lunes del camión 1 son la 1 y la 7.
  late final Set<int> _rutaIds = {
    if (widget.despacho != null)
      ...(widget.despacho!.rutaIds.isNotEmpty ? widget.despacho!.rutaIds : [widget.despacho!.rutaId]),
  };

  /// Si las rutas se tocaron a mano, el recorrido del vehículo deja de imponerlas. Al editar, las guardadas
  /// mandan: fueron una decisión que ya se tomó.
  late bool _rutasTocadas = widget.despacho != null;

  /// El día de visita que atiende el despacho: UNO solo, como en el reporte del sistema anterior (día de visita +
  /// camión → rutas). Decide qué clientes salen y no tiene por qué ser el día de la fecha del reparto. Mientras
  /// nadie lo elija a mano sigue a la fecha; al editar manda el guardado.
  late String _diaVisita = widget.despacho?.diaVisita ??
      widget.despacho?.detalle.map((p) => p.diaVisita).whereType<String>().firstOrNull ??
      _dias[(widget.despacho?.fecha ?? DateTime.now()).weekday - 1];
  late bool _diaTocado = widget.despacho != null;
  late int _vehiculoId = widget.despacho?.vehiculoId ?? 0;
  late String? _vehiculoPlaca = widget.despacho?.vehiculo;
  late int _conductorId = widget.despacho?.conductorId ?? 0;
  late String? _conductorNombre = widget.despacho?.conductor;

  /// Si el conductor se cambió a mano, el camión deja de imponerlo.
  late bool _conductorTocado = widget.despacho != null;

  final Set<int> _elegidos = {};

  bool _guardando = false;
  String? _error;

  DateTime _diaMasTemprano() {
    final dias = (widget.despacho?.detalle ?? const <DespachoPedido>[])
        .map((p) => _soloDia(p.fecha))
        .toList()
      ..sort();
    return dias.isEmpty ? DateTime.now() : dias.first;
  }

  bool get _esNuevo => widget.despacho == null;

  String get _diaTexto => _diasTexto[_dias.indexOf(_diaVisita).clamp(0, 6)];

  /// Las rutas que el vehículo elegido hace ese día, según su recorrido.
  List<int> get _rutasDelDia {
    if (_vehiculoId == 0) return const [];
    final recorrido = ref.read(recorridoVehiculoProvider(_vehiculoId)).valueOrNull;
    return recorrido?[_diaVisita] ?? const [];
  }

  /// Elegir vehículo o fecha propone las rutas de ese día, salvo que ya se hayan tocado a mano.
  Future<void> _proponerRutas() async {
    if (_rutasTocadas || _vehiculoId == 0) return;
    try {
      final recorrido = await ref.read(recorridoVehiculoProvider(_vehiculoId).future);
      if (!mounted || _rutasTocadas) return;
      final delDia = recorrido[_diaVisita] ?? const <int>[];
      setState(() {
        _rutaIds
          ..clear()
          ..addAll(delDia);
        _elegidos.clear();
      });
    } catch (_) {
      // Sin recorrido se sigue: las rutas se eligen a mano, como siempre.
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.despacho != null) {
      _elegidos.addAll(widget.despacho!.detalle.map((p) => p.pedidoId));
    }
  }

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  /// Los disponibles de la ruta, más los propios ya entregados: uno que el
  /// repartidor ya convirtió en venta deja de estar "disponible" para otro
  /// camión, pero sigue siendo parte de este despacho.
  List<DespachoPedido> _completar(List<DespachoPedido> disponibles) {
    final entregados = (widget.despacho?.detalle ?? const <DespachoPedido>[])
        .where((p) => !disponibles.any((x) => x.pedidoId == p.pedidoId));
    return [...disponibles, ...entregados];
  }

  bool _enRango(DespachoPedido p) =>
      !_soloDia(p.fecha).isBefore(_soloDia(_desde)) && !_soloDia(p.fecha).isAfter(_soloDia(_hasta));

  Future<void> _elegirVehiculo() async {
    final vehiculos = await catalogoListo(
      context,
      ref.read(vehiculosProvider.future),
      queEs: 'los vehículos',
    );
    if (!mounted) return;
    final activos = vehiculos.where((v) => v.activo).toList();
    final elegido = await mostrarSelectorBuscable<Vehiculo>(
      context: context,
      titulo: 'Elige el vehículo',
      items: activos,
      buscable: (v) => v.buscable,
      pistaBusqueda: 'Buscar por placa',
      fila: (v) => Text(v.placa, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    if (elegido == null) return;

    setState(() {
      _vehiculoId = elegido.id;
      _vehiculoPlaca = elegido.placa;
      // El camión propone su conductor habitual, mientras nadie haya elegido otro.
      if (!_conductorTocado && elegido.conductorId != null) {
        _conductorId = elegido.conductorId!;
        _conductorNombre = elegido.conductor;
      }
    });

    // Y las rutas que hace ese día, salvo que ya se hayan tocado a mano.
    unawaited(_proponerRutas());
  }

  Future<void> _elegirConductor() async {
    final conductores = await catalogoListo(
      context,
      ref.read(conductoresProvider.future),
      queEs: 'los conductores',
    );
    if (!mounted) return;
    final activos = conductores.where((c) => c.activo).toList();
    final elegido = await mostrarSelectorBuscable<Conductor>(
      context: context,
      titulo: 'Elige el conductor',
      items: activos,
      buscable: (c) => c.buscable,
      pistaBusqueda: 'Buscar por nombre',
      fila: (c) => Text(c.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    if (elegido != null) {
      setState(() {
        _conductorId = elegido.id;
        _conductorNombre = elegido.nombre;
        _conductorTocado = true;
      });
    }
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        // Mientras el dia no se haya elegido a mano, sigue a la fecha del reparto.
        if (!_diaTocado) {
          _diaVisita = _dias[elegida.weekday - 1];
          _elegidos.clear();
        }
      });
      unawaited(_proponerRutas());
    }
  }

  Future<void> _elegirDesde() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: _hasta,
    );
    if (elegida != null) setState(() => _desde = elegida);
  }

  Future<void> _elegirHasta() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _hasta,
      firstDate: _desde,
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (elegida != null) setState(() => _hasta = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (_rutaIds.isEmpty) return setState(() => _error = 'Elige al menos una ruta.');
    if (_vehiculoId == 0) return setState(() => _error = 'Elige el vehículo.');
    if (_conductorId == 0) return setState(() => _error = 'Elige el conductor.');
    if (_desde.isAfter(_hasta)) {
      return setState(() => _error = 'El "desde" de los pedidos no puede ser después del "hasta".');
    }
    if (_elegidos.isEmpty) {
      return setState(() => _error = 'Marca al menos un pedido para cargar.');
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    final cuerpo = <String, dynamic>{
      'fecha': _soloDia(_fecha).toIso8601String(),
      'pedidosDesde': _soloDia(_desde).toIso8601String(),
      'pedidosHasta': _soloDia(_hasta).toIso8601String(),
      'diaVisita': _diaVisita,
      'rutaIds': _rutaIds.toList(),
      'vehiculoId': _vehiculoId,
      'conductorId': _conductorId,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'pedidoIds': _elegidos.toList(),
    };

    try {
      if (_esNuevo) {
        await ref.read(despachosProvider.notifier).crear(cuerpo);
      } else {
        await ref.read(despachosProvider.notifier).actualizar(widget.despacho!.id, cuerpo);
      }
      navegador.pop();
      mensajero.mostrar(_esNuevo ? 'Despacho creado' : 'Despacho actualizado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rutasOrdenadas = _rutaIds.toList()..sort();
    final disponiblesAsync = _rutaIds.isEmpty
        ? null
        : ref.watch(
            disponiblesProvider((
              rutas: rutasOrdenadas.join(','),
              despachoId: widget.despacho?.id,
              // Sin fecha salen los de cualquier día de visita ("incluir otros días").
              dia: _diaVisita,
            )),
          );
    final todasLasRutas = (ref.watch(rutasProvider).valueOrNull ?? const <Ruta>[]).where((r) => r.activo).toList();
    // Se observa para mantener vivo el recorrido del vehiculo: `_rutasDelDia` lo lee sin suscribirse.
    if (_vehiculoId != 0) ref.watch(recorridoVehiculoProvider(_vehiculoId));

    final disponibles = _completar(disponiblesAsync?.valueOrNull ?? const <DespachoPedido>[]);

    final visibles = disponibles.where((p) => _enRango(p) || _elegidos.contains(p.pedidoId)).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final fueraDeRango = disponibles.where((p) => !_enRango(p) && !_elegidos.contains(p.pedidoId)).toList();
    final todosMarcados = visibles.isNotEmpty && visibles.every((p) => _elegidos.contains(p.pedidoId));

    final totalElegido = disponibles
        .where((p) => _elegidos.contains(p.pedidoId))
        .fold<double>(0, (n, p) => n + p.total);

    return Acento.modulo(
      'tms',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo despacho' : 'Editar ${widget.despacho!.numero}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            InkWell(
              onTap: _elegirFecha,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha del reparto',
                  prefixIcon: Icon(Icons.event_outlined, size: 19, color: Colores.tintaTenue),
                  constraints: BoxConstraints(minHeight: Dimen.campoLg),
                ),
                child: Text(_fechaTexto(_fecha), style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),

            // El día de visita que atiende este despacho: uno solo. Con el vehículo decide las rutas
            // (camión 1 + lunes = rutas 1 y 7) y qué clientes salen.
            AppSelector<String>(
              valor: _diaVisita,
              etiqueta: 'Día de visita',
              icono: Icons.calendar_view_week_outlined,
              habilitado: !_guardando,
              opciones: [
                for (var i = 0; i < 6; i++) Opcion<String>(_dias[i], _diasTexto[i][0].toUpperCase() + _diasTexto[i].substring(1)),
              ],
              onCambio: (v) {
                if (v == null) return;
                setState(() {
                  _diaVisita = v;
                  _diaTocado = true;
                  _elegidos.clear();
                });
                unawaited(_proponerRutas());
              },
            ),
            const SizedBox(height: Dimen.espacio4),

            InkWell(
              onTap: _elegirVehiculo,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Vehículo',
                  prefixIcon: const Icon(Icons.local_shipping_outlined, size: 19, color: Colores.tintaTenue),
                  suffixIcon: const Icon(Icons.search, size: 18, color: Colores.tintaTenue),
                  constraints: const BoxConstraints(minHeight: Dimen.campoLg),
                ),
                child: Text(
                  _vehiculoPlaca ?? 'Toca para elegir',
                  style: TextStyle(fontSize: 15, color: _vehiculoPlaca == null ? Colores.tintaTenue : Colores.tinta),
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),

            InkWell(
              onTap: _elegirConductor,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Conductor',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 19, color: Colores.tintaTenue),
                  suffixIcon: const Icon(Icons.search, size: 18, color: Colores.tintaTenue),
                  constraints: const BoxConstraints(minHeight: Dimen.campoLg),
                ),
                child: Text(
                  _conductorNombre ?? 'Toca para elegir',
                  style: TextStyle(
                    fontSize: 15,
                    color: _conductorNombre == null ? Colores.tintaTenue : Colores.tinta,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio5),

            // Las rutas que carga el camión ese día. El vehículo y la fecha las proponen desde su recorrido
            // semanal; se pueden cambiar para este despacho.
            const Text('Rutas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: Dimen.espacio2),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final r in todasLasRutas)
                  FilterChip(
                    label: Text(r.nombre),
                    selected: _rutaIds.contains(r.id),
                    onSelected: _guardando
                        ? null
                        : (v) => setState(() {
                            _rutasTocadas = true;
                            if (v) {
                              _rutaIds.add(r.id);
                            } else {
                              _rutaIds.remove(r.id);
                            }
                            _elegidos.clear();
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _vehiculoId == 0
                  ? 'Elige el vehículo y el día: sus rutas se proponen solas.'
                  : _rutasTocadas
                  ? 'Cambiadas a mano para este despacho.'
                  : _rutasDelDia.isEmpty
                  ? 'Este vehículo no tiene rutas los $_diaTexto. Elígelas a mano o cárgalas en Flota → Recorrido.'
                  : 'Del recorrido del vehículo para el $_diaTexto.',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio5),

            const Text(
              'Pedidos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Los pendientes de esas rutas, tomados entre estas fechas. Incluye el '
              'día en que se pesa: los aumentos de ese día también suben al camión.',
              style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio2),
            Text(
              'Solo salen los clientes que se visitan el $_diaTexto.',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio3),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _elegirDesde,
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Desde',
                        constraints: BoxConstraints(minHeight: Dimen.campoLg),
                      ),
                      child: Text(_fechaTexto(_desde), style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: InkWell(
                    onTap: _elegirHasta,
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hasta',
                        constraints: BoxConstraints(minHeight: Dimen.campoLg),
                      ),
                      child: Text(_fechaTexto(_hasta), style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio3),

            if (fueraDeRango.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: Dimen.espacio3),
                padding: const EdgeInsets.all(Dimen.espacio3),
                decoration: BoxDecoration(
                  color: Colores.advertencia.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimen.radioCampo),
                ),
                child: Text(
                  fueraDeRango.length == 1
                      ? 'Hay 1 pedido pendiente de esas rutas fuera de esas fechas. '
                            'No sube al camión; amplía las fechas si debe ir.'
                      : 'Hay ${fueraDeRango.length} pedidos pendientes de esas rutas fuera de '
                            'esas fechas. No suben al camión; amplía las fechas si deben ir.',
                  style: const TextStyle(fontSize: 12.5, color: Colores.advertencia),
                ),
              ),

            if (_rutaIds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                child: Center(
                  child: Text(
                    'Elige primero las rutas para ver sus pedidos.',
                    style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                  ),
                ),
              )
            else if (disponiblesAsync != null && disponiblesAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (disponibles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                child: Center(
                  child: Text(
                    'No hay pedidos pendientes para esas rutas. Puede que ya estén '
                    'en otro camión.',
                    style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                  ),
                ),
              )
            else if (visibles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                child: Center(
                  child: Text(
                    'No hay pedidos de esas rutas entre esas fechas.',
                    style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                  ),
                ),
              )
            else ...[
              CheckboxListTile(
                value: todosMarcados,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  todosMarcados ? 'Quitar todos' : 'Marcar todos (${visibles.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onChanged: (_) => setState(() {
                  if (todosMarcados) {
                    // Lo ya entregado no se puede bajar del camión.
                    _elegidos.removeWhere(
                      (id) => visibles.any((p) => p.pedidoId == id && !p.entregado),
                    );
                  } else {
                    _elegidos.addAll(visibles.map((p) => p.pedidoId));
                  }
                }),
              ),
              for (final p in visibles)
                Container(
                  margin: const EdgeInsets.only(bottom: Dimen.espacio2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colores.linea),
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                  ),
                  child: CheckboxListTile(
                    value: _elegidos.contains(p.pedidoId),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: p.entregado
                        ? null
                        : (v) => setState(() {
                            if (v ?? false) {
                              _elegidos.add(p.pedidoId);
                            } else {
                              _elegidos.remove(p.pedidoId);
                            }
                          }),
                    title: Row(
                      children: [
                        Text(
                          p.numero,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.cliente,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          'S/ ${p.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      [
                            if (p.entregado) 'Ya entregado (${p.notaVentaNumero})',
                            // Con varias rutas en el camión, dice de cuál es cada cliente.
                            if (p.rutaCliente != null) 'Ruta ${p.rutaCliente}',
                            [p.mercado, p.direccion].where((s) => s != null && s.isNotEmpty).join(' — '),
                            if (p.telefono != null) p.telefono!,
                          ]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: p.entregado ? Colores.exito : Colores.tintaSuave,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Dimen.espacio3),
              decoration: BoxDecoration(
                color: Colores.fondo,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Carga del camión', style: TextStyle(fontSize: 12, color: Colores.tintaSuave)),
                  Text(
                    '${_elegidos.length} pedido${_elegidos.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'S/ ${totalElegido.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: Colores.tinta),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(
              texto: _esNuevo ? 'Armar despacho' : 'Guardar cambios',
              cargando: _guardando,
              onPressed: _guardar,
            ),
            const SizedBox(height: Dimen.espacio3),
            AppBoton(
              texto: 'Cancelar',
              variante: BotonVariante.secundario,
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}
