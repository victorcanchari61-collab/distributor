import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../tms/datos/novedad.dart';
import '../../tms/estado/novedades_controlador.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';

double _redondear(double n) => (n * 10000).round() / 10000;

double _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

String _texto(double n) {
  final r = _redondear(n);
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

const _teclado = TextInputType.numberWithOptions(decimal: true);

/// Abre la hoja de conversión en venta. Devuelve true si el pedido se convirtió.
Future<bool?> mostrarEntregaPedido(BuildContext context, Pedido pedido) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) => EntregaPedidoHoja(pedido: pedido),
  );
}

/// Abre la hoja de "no entregado". Devuelve true si quedó marcado.
Future<bool?> mostrarNoEntregado(BuildContext context, Pedido pedido) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) => NoEntregadoHoja(pedido: pedido),
  );
}

/// Lo tecleado para una línea del pedido.
class _EntregaLinea {
  _EntregaLinea(this.linea) : factor = linea.factor {
    if (factor <= 1) {
      pres.text = _texto(linea.cantidad);
      sueltas.text = '0';
    } else {
      final cajas = (linea.cantidadPresentacion + 1e-6).floor();
      pres.text = '$cajas';
      sueltas.text = _texto(linea.cantidad - cajas * factor);
    }
  }

  final LineaVenta linea;
  final double factor;

  /// Cajas (o la unidad misma cuando la presentación es la base).
  final pres = TextEditingController();

  /// Unidades sueltas sobre las cajas, en unidad base.
  final sueltas = TextEditingController();
  final observacion = TextEditingController();
  int? motivoId;

  bool get conSueltas => factor > 1;

  /// Lo entregado, en unidad base.
  double get entregada =>
      _redondear(conSueltas ? _numero(pres.text) * factor + _numero(sueltas.text) : _numero(pres.text));

  bool get reducida => entregada < linea.cantidad - 1e-6;
  bool get excede => entregada > linea.cantidad + 1e-6;
  double get subtotal => (entregada / factor) * linea.precioPresentacion;

  void dispose() {
    pres.dispose();
    sueltas.dispose();
    observacion.dispose();
  }
}

/// Convertir un pedido en venta, con lo que de verdad se entregó.
///
/// Por defecto sale todo lo pedido. Si el cliente recibió menos —una caja de
/// menos, unas unidades sueltas, un producto que no estaba— se corrige aquí la
/// línea y se pide el motivo: la venta lleva y cobra solo lo entregado, y lo que
/// quedó corto queda registrado como novedad.
class EntregaPedidoHoja extends ConsumerStatefulWidget {
  const EntregaPedidoHoja({super.key, required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<EntregaPedidoHoja> createState() => _EntregaPedidoHojaState();
}

class _EntregaPedidoHojaState extends ConsumerState<EntregaPedidoHoja> {
  late final List<_EntregaLinea> _lineas = [
    for (final l in widget.pedido.detalle)
      if (!l.anulado) _EntregaLinea(l),
  ];

  int? _almacenId;
  bool _guardando = false;
  String? _error;

  /// Con reserva el stock ya está apartado en un almacén: de ahí sale, y
  /// preguntarlo otra vez invita a elegir otro y dejar la reserva colgada.
  bool get _conReserva => widget.pedido.reservaStock && widget.pedido.almacenId != null;

  @override
  void initState() {
    super.initState();
    final almacenes = ref.read(almacenesActivosProvider);
    _almacenId = _conReserva
        ? widget.pedido.almacenId
        : (almacenes.length == 1 ? almacenes.first.id : null);

    for (final l in _lineas) {
      l.pres.addListener(_recalcular);
      l.sueltas.addListener(_recalcular);
    }
  }

  void _recalcular() => setState(() => _error = null);

  @override
  void dispose() {
    for (final l in _lineas) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _convertir() async {
    if (!_conReserva && _almacenId == null) {
      return setState(() => _error = 'Elige el almacén.');
    }

    for (final l in _lineas) {
      if (l.excede) {
        return setState(() => _error = '${l.linea.producto}: no se puede entregar más de lo pedido.');
      }
      if (l.reducida && l.motivoId == null) {
        return setState(
          () => _error = 'Elige el motivo por el que ${l.linea.producto} se entrega en menos.',
        );
      }
    }

    if (_lineas.every((l) => l.entregada <= 0)) {
      return setState(
        () => _error =
            'No queda nada por entregar. Si el cliente no recibió nada, márcalo como "No entregado".',
      );
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final cuerpo = <String, dynamic>{
      'almacenId': _conReserva ? null : _almacenId,
      'lineas': [
        for (final l in _lineas)
          if (l.reducida)
            {
              'pedidoDetalleId': l.linea.id,
              'cantidad': l.entregada,
              'motivoId': l.motivoId,
              'observacion': l.observacion.text.trim().isEmpty ? null : l.observacion.text.trim(),
            },
      ],
    };

    final navegador = Navigator.of(context);
    try {
      await ref.read(pedidosProvider.notifier).confirmar(widget.pedido.id, cuerpo);
      navegador.pop(true);
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);
    final motivos = ref.watch(opcionesMotivoProvider);
    final opcionesMotivo = motivos.valueOrNull ?? const <MotivoNovedad>[];
    final hayRecortes = _lineas.any((l) => l.reducida);
    final total = _lineas.fold<double>(0, (suma, l) => suma + l.subtotal);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Padding(
        padding: EdgeInsets.only(
          left: Dimen.espacio4,
          right: Dimen.espacio4,
          top: Dimen.espacio2,
          bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Convertir ${widget.pedido.numero} en venta',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
            ),
            const SizedBox(height: 2),
            Text(
              widget.pedido.cliente,
              style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio3),
            Expanded(
              child: ListView(
                children: [
                  if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio3)],

                  if (_conReserva)
                    Container(
                      padding: const EdgeInsets.all(Dimen.espacio3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colores.linea),
                        borderRadius: BorderRadius.circular(Dimen.radioCampo),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warehouse_outlined, size: 18, color: Colores.tintaTenue),
                          const SizedBox(width: Dimen.espacio2),
                          Expanded(
                            child: Text(
                              widget.pedido.almacen ?? 'Almacén de la reserva',
                              style: const TextStyle(fontSize: 14, color: Colores.tinta),
                            ),
                          ),
                          const AppEtiqueta('stock reservado', tono: EtiquetaTono.modulo),
                        ],
                      ),
                    )
                  else
                    AppSelector<int>(
                      valor: _almacenId,
                      etiqueta: 'Almacén',
                      icono: Icons.warehouse_outlined,
                      opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
                      onCambio: (v) => setState(() {
                        _almacenId = v;
                        _error = null;
                      }),
                    ),

                  const SizedBox(height: Dimen.espacio4),
                  const Text(
                    'Lo que se entregó',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colores.tinta),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Por defecto sale todo lo pedido. Si el cliente recibió menos, corrige la '
                    'cantidad y elige el motivo: la venta cobra solo lo entregado.',
                    style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                  ),
                  const SizedBox(height: Dimen.espacio3),

                  for (final l in _lineas) ...[
                    _TarjetaEntrega(
                      linea: l,
                      motivos: opcionesMotivo,
                      cargandoMotivos: motivos.isLoading,
                      onCambio: () => setState(() => _error = null),
                    ),
                    const SizedBox(height: Dimen.espacio3),
                  ],

                  if (hayRecortes && !motivos.isLoading && opcionesMotivo.isEmpty)
                    const AppAlerta(
                      'Todavía no hay motivos de novedad. Pídele a quien administra que los cree en '
                      'TMS → Motivos de novedad.',
                      tono: AlertaTono.aviso,
                    ),

                  const Text(
                    'La nota de venta que nace queda a crédito, pendiente de cobro — un pedido no '
                    'registra pagos.',
                    style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                  ),
                  const SizedBox(height: Dimen.espacio3),
                  const Divider(height: 1),
                  const SizedBox(height: Dimen.espacio2),
                  if (hayRecortes)
                    _FilaTotal('Total del pedido', widget.pedido.total, suave: true),
                  _FilaTotal(hayRecortes ? 'Total a cobrar' : 'Total', total),
                  const SizedBox(height: Dimen.espacio2),
                ],
              ),
            ),
            const SizedBox(height: Dimen.espacio2),
            AppBoton(texto: 'Convertir en venta', cargando: _guardando, onPressed: _convertir),
          ],
        ),
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal(this.etiqueta, this.valor, {this.suave = false});

  final String etiqueta;
  final double valor;
  final bool suave;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: suave ? 13 : 15,
      fontWeight: suave ? FontWeight.w500 : FontWeight.w700,
      color: suave ? Colores.tintaSuave : Colores.tinta,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text('S/ ${valor.toStringAsFixed(2)}', style: estilo),
        ],
      ),
    );
  }
}

/// Una línea del pedido con lo que se entregó de ella.
class _TarjetaEntrega extends StatelessWidget {
  const _TarjetaEntrega({
    required this.linea,
    required this.motivos,
    required this.cargandoMotivos,
    required this.onCambio,
  });

  final _EntregaLinea linea;
  final List<MotivoNovedad> motivos;
  final bool cargandoMotivos;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final l = linea.linea;
    final pedido = '${_texto(l.cantidadPresentacion)} ${l.presentacion ?? l.unidadBase}'
        '${linea.conSueltas ? ' (${_texto(l.cantidad)} ${l.unidadBase})' : ''}';

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: linea.reducida ? Colores.advertencia : Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.producto,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
                    ),
                    Text(
                      '${l.codigo} · Pedido: $pedido',
                      style: const TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
                    ),
                  ],
                ),
              ),
              Text(
                'S/ ${linea.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: linea.pres,
                  etiqueta: linea.conSueltas ? (l.presentacion ?? 'Cajas') : l.unidadBase,
                  tipoTeclado: linea.conSueltas ? TextInputType.number : _teclado,
                ),
              ),
              if (linea.conSueltas) ...[
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: AppCampo(
                    controlador: linea.sueltas,
                    etiqueta: 'Sueltas (${l.unidadBase})',
                    tipoTeclado: _teclado,
                  ),
                ),
              ],
            ],
          ),
          if (linea.excede) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              'No puede ser más de lo pedido (${_texto(l.cantidad)} ${l.unidadBase}).',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.peligro),
            ),
          ],
          if (linea.reducida && !linea.excede) ...[
            const SizedBox(height: Dimen.espacio3),
            Container(
              padding: const EdgeInsets.all(Dimen.espacio3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${linea.entregada <= 0 ? 'No se entrega este producto.' : 'Se entrega ${_texto(linea.entregada)} de ${_texto(l.cantidad)} ${l.unidadBase}.'} '
                    'Falta ${_texto(l.cantidad - linea.entregada)} ${l.unidadBase}.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.advertencia),
                  ),
                  const SizedBox(height: Dimen.espacio3),
                  AppSelector<int>(
                    valor: linea.motivoId,
                    etiqueta: 'Motivo',
                    icono: Icons.label_outline,
                    opciones: [for (final m in motivos) Opcion<int>(m.id, m.nombre)],
                    onCambio: (v) {
                      linea.motivoId = v;
                      onCambio();
                    },
                  ),
                  const SizedBox(height: Dimen.espacio3),
                  AppCampo(
                    controlador: linea.observacion,
                    etiqueta: 'Observación',
                    icono: Icons.notes_outlined,
                    opcional: true,
                    maxLargo: 250,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// El pedido entero no se entregó: no había nadie, cerró, no quiso recibirlo.
///
/// No nace ninguna venta y el pedido sigue Pendiente; queda la novedad con su
/// motivo para revisarla al volver el camión.
class NoEntregadoHoja extends ConsumerStatefulWidget {
  const NoEntregadoHoja({super.key, required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<NoEntregadoHoja> createState() => _NoEntregadoHojaState();
}

class _NoEntregadoHojaState extends ConsumerState<NoEntregadoHoja> {
  final _observacion = TextEditingController();
  int? _motivoId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_motivoId == null) {
      return setState(() => _error = 'Elige el motivo por el que no se entregó.');
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    try {
      await ref.read(pedidosProvider.notifier).marcarNoEntregado(widget.pedido.id, {
        'motivoId': _motivoId,
        'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      });
      navegador.pop(true);
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final motivos = ref.watch(opcionesMotivoProvider);
    final opciones = motivos.valueOrNull ?? const <MotivoNovedad>[];

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
              '${widget.pedido.numero} no se entregó',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
            ),
            const SizedBox(height: 2),
            Text(
              widget.pedido.cliente,
              style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio2),
            const Text(
              'No se crea ninguna venta ni sale stock. El pedido sigue pendiente: puedes '
              'intentarlo de nuevo o anularlo.',
              style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio3)],
            AppSelector<int>(
              valor: _motivoId,
              etiqueta: 'Motivo',
              icono: Icons.label_outline,
              opciones: [for (final m in opciones) Opcion<int>(m.id, m.nombre)],
              onCambio: (v) => setState(() {
                _motivoId = v;
                _error = null;
              }),
            ),
            if (!motivos.isLoading && opciones.isEmpty) ...[
              const SizedBox(height: Dimen.espacio3),
              const AppAlerta(
                'Todavía no hay motivos de novedad. Pídele a quien administra que los cree en '
                'TMS → Motivos de novedad.',
                tono: AlertaTono.aviso,
              ),
            ],
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
            ),
            const SizedBox(height: Dimen.espacio3),
            AppBoton(texto: 'Marcar como no entregado', cargando: _guardando, onPressed: _guardar),
          ],
        ),
      ),
    );
  }
}
