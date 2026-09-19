import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../finanzas/estado/finanzas_controlador.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../tms/datos/novedad.dart';
import '../../tms/estado/novedades_controlador.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';
import 'pago_entrega.dart';

double _redondear(double n) => (n * 10000).round() / 10000;

double _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

String _texto(double n) {
  final r = _redondear(n);
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

const _teclado = TextInputType.numberWithOptions(decimal: true);

/// Abre la hoja de conversión en venta. Devuelve el mensaje de éxito —que dice
/// qué pasó con el cobro— si el pedido se convirtió, o null si se cerró sin convertir.
Future<String?> mostrarEntregaPedido(BuildContext context, Pedido pedido) {
  return showModalBottomSheet<String>(
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

/// Convertir un pedido en venta, con lo que de verdad se entregó y se cobró.
///
/// Dos pestañas. En "Entrega": por defecto sale todo lo pedido; si el cliente
/// recibió menos —una caja de menos, unas unidades sueltas, un producto que no
/// estaba— se corrige aquí la línea y se pide el motivo: la venta lleva y cobra
/// solo lo entregado, y lo que quedó corto queda registrado como novedad.
///
/// En "Pago": lo que el cliente pagó al recibir. La condición de pago del pedido
/// es solo lo acordado; manda lo cobrado. Si cubre el total la venta es al
/// contado, y si no queda a crédito con ese adelanto.
class EntregaPedidoHoja extends ConsumerStatefulWidget {
  const EntregaPedidoHoja({super.key, required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<EntregaPedidoHoja> createState() => _EntregaPedidoHojaState();
}

class _EntregaPedidoHojaState extends ConsumerState<EntregaPedidoHoja>
    with SingleTickerProviderStateMixin {
  static const _pestanaEntrega = 0;
  static const _pestanaPago = 1;

  late final _tabs = TabController(length: 2, vsync: this);

  late final List<_EntregaLinea> _lineas = [
    for (final l in widget.pedido.detalle)
      if (!l.anulado) _EntregaLinea(l),
  ];

  /// Lo cobrado al recibir. Vive aquí y no en la pestaña porque también hace
  /// falta al convertir, y la pestaña se reconstruye al cambiar de una a otra.
  final List<FilaPagoEntrega> _pagos = [];

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
    _tabs.dispose();
    for (final l in _lineas) {
      l.dispose();
    }
    for (final p in _pagos) {
      p.dispose();
    }
    super.dispose();
  }

  /// Lo que se cobra: solo lo entregado.
  double get _total => _lineas.fold<double>(0, (suma, l) => suma + l.subtotal);

  /// Un fallo de validación: se muestra arriba y se lleva a la pestaña donde se arregla.
  void _fallar(String mensaje, int pestana) {
    setState(() => _error = mensaje);
    _tabs.animateTo(pestana);
  }

  /// Qué pasó con el cobro, para el aviso con el que se cierra la hoja.
  static String _mensajeHecho(ResumenPago cobro, double total) {
    if (cobro.completo) {
      return 'Pedido convertido: venta al contado, cobrada (${formatoSoles(cobro.pagado)}).';
    }
    if (cobro.pagado > 0) {
      return 'Pedido convertido: cobrado ${formatoSoles(cobro.pagado)}, quedan '
          '${formatoSoles(cobro.saldo)} a crédito.';
    }
    return 'Pedido convertido: venta a crédito por ${formatoSoles(total)}.';
  }

  Future<void> _convertir() async {
    if (!_conReserva && _almacenId == null) {
      return _fallar('Elige el almacén.', _pestanaEntrega);
    }

    for (final l in _lineas) {
      if (l.excede) {
        return _fallar(
          '${l.linea.producto}: no se puede entregar más de lo pedido.',
          _pestanaEntrega,
        );
      }
      if (l.reducida && l.motivoId == null) {
        return _fallar(
          'Elige el motivo por el que ${l.linea.producto} se entrega en menos.',
          _pestanaEntrega,
        );
      }
    }

    if (_lineas.every((l) => l.entregada <= 0)) {
      return _fallar(
        'No queda nada por entregar. Si el cliente no recibió nada, márcalo como "No entregado".',
        _pestanaEntrega,
      );
    }

    // La entrega se valida primero; recién después el cobro.
    final total = _total;
    final cobro = ResumenPago(_pagos, total);
    if (cobro.pendiente) {
      return _fallar(
        'Hay un pago sin guardar: guárdalo con el visto o cancélalo antes de convertir.',
        _pestanaPago,
      );
    }
    if (cobro.sobra) {
      return _fallar(
        'Lo cobrado (${formatoSoles(cobro.pagado)}) supera el total de la venta '
        '(${formatoSoles(total)}).',
        _pestanaPago,
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
      // Sin ningún pago va vacío y la venta queda a crédito: es el backend
      // quien deriva la forma de pago de lo cobrado.
      'pagos': [
        for (final p in cobro.usadas) {'metodoPagoId': p.metodoPagoId, 'monto': p.valor},
      ],
    };

    // Antes del await: al cerrar la hoja este estado ya no está para calcularlo.
    final mensaje = _mensajeHecho(cobro, total);
    final navegador = Navigator.of(context);
    try {
      await ref.read(pedidosProvider.notifier).confirmar(widget.pedido.id, cuerpo);
      navegador.pop(mensaje);
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
    // Se pide al abrir la hoja, no al entrar en Pago: así ya está al llegar.
    final metodos = ref.watch(metodosPagoOpcionesProvider);
    final opcionesMotivo = motivos.valueOrNull ?? const <MotivoNovedad>[];
    final hayRecortes = _lineas.any((l) => l.reducida);
    final total = _total;
    final cobro = ResumenPago(_pagos, total);
    final color = Acento.de(context);

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
            const SizedBox(height: Dimen.espacio2),
            TabBar(
              controller: _tabs,
              labelColor: color,
              unselectedLabelColor: Colores.tintaSuave,
              indicatorColor: color,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              // Se suelta el teclado al cambiar: el campo que tenía el foco se va
              // con su pestaña y el teclado se quedaba abierto sin campo.
              onTap: (_) => FocusScope.of(context).unfocus(),
              tabs: [
                const Tab(text: 'Entrega'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pago'),
                      // Cuántos pagos hay guardados: sin él, quien no entra a la
                      // pestaña no ve que ya se registró un cobro.
                      if (cobro.usadas.isNotEmpty) ...[
                        const SizedBox(width: Dimen.espacio2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${cobro.usadas.length}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: Dimen.espacio3),

            // Encima de las pestañas: el error de una se arregla en la otra.
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio3)],

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  ListView(
                    children: [
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
                        'El cobro se registra en la pestaña Pago. Si no se cobra nada, la venta queda '
                        'a crédito.',
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

                  // En Pago el total ya está en la tarjeta "A cobrar": repetirlo sobra.
                  PagoEntrega(
                    condicionPago: widget.pedido.condicionPago,
                    metodos: metodos,
                    filas: _pagos,
                    total: total,
                    onCambio: () => setState(() => _error = null),
                  ),
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
