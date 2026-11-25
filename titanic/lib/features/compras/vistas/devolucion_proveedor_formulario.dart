import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/catalogo_listo.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../datos/compra.dart';
import '../datos/devolucion_proveedor.dart';
import '../estado/compras_controlador.dart';

/// Motivos de siempre, para no escribirlos cada vez.
const _motivos = [
  'Llegó en mal estado',
  'Vencido o por vencer',
  'No es lo que se pidió',
  'Llegó de más',
  'No lo trajo',
];

/// Una linea de la compra en el formulario: cuanto de lo que llego se devuelve,
/// cuanto de lo que no llego se da por no recibido, y que da el proveedor.
class _FilaDevolucion {
  _FilaDevolucion(this.detalle);

  final CompraDetalle detalle;
  final devolverCtrl = TextEditingController();
  final rechazarCtrl = TextEditingController();
  String resolucion = ResolucionDevolucion.descuento;

  /// Cuantas unidades base es la presentacion en que se compro.
  double get factor => detalle.cantidadPresentacion > 0
      ? detalle.cantidad / detalle.cantidadPresentacion
      : 1;

  String get unidad => detalle.presentacion ?? detalle.unidadBase;

  /// Un numero en unidad base, dicho en la presentacion de la compra.
  double enCompra(double base) =>
      double.parse((base / factor).toStringAsFixed(4));

  static double _leer(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  /// En unidad base, que es como la compra y el almacen llevan las cantidades.
  double get devolverBase => _leer(devolverCtrl) * factor;
  double get rechazarBase => _leer(rechazarCtrl) * factor;
  double get importe => (devolverBase + rechazarBase) * detalle.costoUnitario;
  bool get conAlgo => devolverBase > 0 || rechazarBase > 0;

  void dispose() {
    devolverCtrl.dispose();
    rechazarCtrl.dispose();
  }
}

/// Devolverle al proveedor parte de una compra: lo que llego mal o no llego.
///
/// Igual que en el panel web: por cada producto se dice cuanto se devuelve y
/// que da el proveedor a cambio. Reposicion: lo trae otro dia y vuelve a
/// quedar por recibir. Descuento: la compra baja; si ya estaba pagada, queda
/// saldo a favor con el proveedor.
class DevolucionProveedorFormulario extends ConsumerStatefulWidget {
  const DevolucionProveedorFormulario({super.key, this.compraFija});

  /// Si viene de "Devolver" en Mis compras, la compra ya esta elegida.
  final Compra? compraFija;

  @override
  ConsumerState<DevolucionProveedorFormulario> createState() =>
      _DevolucionProveedorFormularioState();
}

class _DevolucionProveedorFormularioState
    extends ConsumerState<DevolucionProveedorFormulario> {
  final _motivo = TextEditingController();
  final _observacion = TextEditingController();
  final _serieNc = TextEditingController();
  final _numeroNc = TextEditingController();

  late Compra? _compra = widget.compraFija;
  late List<_FilaDevolucion> _filas = _construirFilas(widget.compraFija);
  late int? _almacenId = widget.compraFija?.almacenRecepcionId;
  DateTime? _fechaReposicion;

  bool _guardando = false;
  String? _error;
  String? _errorCompra;
  String? _errorMotivo;

  @override
  void dispose() {
    _motivo.dispose();
    _observacion.dispose();
    _serieNc.dispose();
    _numeroNc.dispose();
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  /// Solo las lineas de las que queda algo: recibido o por recibir.
  List<_FilaDevolucion> _construirFilas(Compra? compra) {
    if (compra == null) return [];
    final filas = [
      for (final d in compra.detalle)
        if (d.cantidadRecibida > 0 || d.cantidadPendiente > 0)
          _FilaDevolucion(d),
    ];
    // Las cifras de abajo y los campos que aparecen dependen de lo escrito.
    for (final f in filas) {
      f.devolverCtrl.addListener(_redibujar);
      f.rechazarCtrl.addListener(_redibujar);
    }
    return filas;
  }

  void _redibujar() => setState(() {});

  Future<void> _elegirCompra() async {
    await catalogoListo(
      context,
      ref.read(comprasProvider.future),
      queEs: 'las compras',
    );
    if (!mounted) return;
    final compras = (ref.read(comprasProvider).valueOrNull ?? const <Compra>[])
        .where(
          (c) =>
              c.estado != EstadoCompra.anulada &&
              c.detalle.any(
                (d) => d.cantidadRecibida > 0 || d.cantidadPendiente > 0,
              ),
        )
        .toList();
    final elegida = await mostrarSelectorBuscable<Compra>(
      context: context,
      titulo: 'Elige la compra',
      items: compras,
      buscable: (c) => c.buscable,
      pistaBusqueda: 'Buscar por número o proveedor',
      fila: (c) => Text(
        '${c.numero} · ${c.proveedor}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
    if (elegida != null) {
      setState(() {
        for (final f in _filas) {
          f.dispose();
        }
        _compra = elegida;
        _filas = _construirFilas(elegida);
        _almacenId = elegida.almacenRecepcionId ?? _almacenId;
      });
    }
  }

  Future<void> _elegirFechaReposicion() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaReposicion ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fechaReposicion = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final compra = _compra;
    setState(() {
      _errorCompra = compra == null ? 'Elige la compra.' : null;
      _errorMotivo = _motivo.text.trim().isEmpty
          ? 'Indica por qué se devuelve.'
          : null;
      _error = null;
    });
    if (compra == null || _errorMotivo != null) return;

    final conAlgo = _filas.where((f) => f.conAlgo).toList();
    if (conAlgo.isEmpty) {
      setState(
        () => _error = 'Indica cuánto se devuelve de al menos un producto.',
      );
      return;
    }
    final saleDelStock = conAlgo.any((f) => f.devolverBase > 0);
    if (saleDelStock && _almacenId == null) {
      setState(
        () => _error = 'Elige de qué almacén sale lo que ya había llegado.',
      );
      return;
    }
    for (final f in conAlgo) {
      if (f.devolverBase > f.detalle.cantidadRecibida + 0.0001) {
        setState(
          () => _error =
              '${f.detalle.producto}: llegaron '
              '${formatoNumero(f.enCompra(f.detalle.cantidadRecibida))} ${f.unidad}.',
        );
        return;
      }
      if (f.rechazarBase > f.detalle.cantidadPendiente + 0.0001) {
        setState(
          () => _error =
              '${f.detalle.producto}: faltan llegar '
              '${formatoNumero(f.enCompra(f.detalle.cantidadPendiente))} ${f.unidad}.',
        );
        return;
      }
    }

    final hayReposicion = conAlgo.any(
      (f) => f.resolucion == ResolucionDevolucion.reposicion,
    );
    final hayDescuento = conAlgo.any(
      (f) => f.resolucion == ResolucionDevolucion.descuento,
    );
    String? texto(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final cuerpo = <String, dynamic>{
      'compraId': compra.id,
      'motivo': _motivo.text.trim(),
      'observacion': texto(_observacion),
      'almacenId': saleDelStock ? _almacenId : null,
      'fechaReposicion': hayReposicion
          ? _fechaReposicion?.toIso8601String()
          : null,
      'serieNotaCredito': hayDescuento ? texto(_serieNc) : null,
      'numeroNotaCredito': hayDescuento ? texto(_numeroNc) : null,
      'detalle': [
        for (final f in conAlgo) ...[
          if (f.devolverBase > 0)
            {
              'compraDetalleId': f.detalle.id,
              'cantidad': f.devolverBase,
              'origen': OrigenDevolucion.recibido,
              'resolucion': f.resolucion,
            },
          if (f.rechazarBase > 0)
            {
              'compraDetalleId': f.detalle.id,
              'cantidad': f.rechazarBase,
              'origen': OrigenDevolucion.pendiente,
              'resolucion': f.resolucion,
            },
        ],
      ],
    };

    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);
    try {
      final creada = await ref
          .read(devolucionesProveedorProvider.notifier)
          .crear(cuerpo);
      navegador.pop();
      mensajero.mostrar(
        creada.saldoFavorGenerado > 0
            ? 'Devolución ${creada.numero}: el proveedor te debe '
                  'S/ ${creada.saldoFavorGenerado.toStringAsFixed(2)}'
            : 'Devolución ${creada.numero} registrada',
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);
    final compra = _compra;
    final conAlgo = _filas.where((f) => f.conAlgo).toList();
    final devuelto = conAlgo.fold<double>(0, (s, f) => s + f.importe);
    final descuento = conAlgo
        .where((f) => f.resolucion == ResolucionDevolucion.descuento)
        .fold<double>(0, (s, f) => s + f.importe);
    // Lo descontado baja primero lo que se debe; lo que pasa de eso ya estaba
    // pagado y queda a favor.
    final deuda = compra == null
        ? 0.0
        : math.max(0.0, compra.total - compra.totalPagado);
    final saldoFavor = math.max(0.0, descuento - deuda);
    final saleDelStock = conAlgo.any((f) => f.devolverBase > 0);
    final hayReposicion = conAlgo.any(
      (f) => f.resolucion == ResolucionDevolucion.reposicion,
    );

    return Acento.modulo(
      'compras',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Devolver al proveedor',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio4),
            ],
            InkWell(
              onTap: widget.compraFija == null ? _elegirCompra : null,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Compra',
                  errorText: _errorCompra,
                  prefixIcon: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 19,
                    color: Colores.tintaTenue,
                  ),
                  suffixIcon: widget.compraFija == null
                      ? const Icon(
                          Icons.search,
                          size: 18,
                          color: Colores.tintaTenue,
                        )
                      : null,
                  constraints: const BoxConstraints(minHeight: Dimen.campoLg),
                ),
                child: Text(
                  compra == null
                      ? 'Toca para elegir'
                      : '${compra.numero} · ${compra.proveedor}',
                  style: TextStyle(
                    fontSize: 15,
                    color: compra == null ? Colores.tintaTenue : Colores.tinta,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _motivo,
              etiqueta: 'Motivo',
              icono: Icons.report_outlined,
              error: _errorMotivo,
              maxLargo: 150,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _motivos)
                  ActionChip(
                    label: Text(m, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _motivo.text = m),
                  ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            if (saleDelStock) ...[
              AppSelector<int>(
                valor: _almacenId,
                etiqueta: 'Sale del almacén',
                icono: Icons.warehouse_outlined,
                opciones: [
                  for (final a in almacenes) Opcion<int>(a.id, a.nombre),
                ],
                onCambio: (v) => setState(() => _almacenId = v),
              ),
              const SizedBox(height: Dimen.espacio4),
            ],
            if (compra != null) ...[
              const Text(
                'Productos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colores.tinta,
                ),
              ),
              const SizedBox(height: Dimen.espacio3),
              if (_filas.isEmpty)
                const Text(
                  'De esta compra no queda nada por devolver.',
                  style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
                ),
              for (final fila in _filas) ...[
                _TarjetaFilaDevolucion(
                  fila: fila,
                  onResolucion: (v) => setState(() => fila.resolucion = v),
                ),
                const SizedBox(height: Dimen.espacio3),
              ],
              _Resumen(
                devuelto: devuelto,
                descuento: descuento,
                reposicion: devuelto - descuento,
                saldoFavor: saldoFavor,
                deuda: deuda,
              ),
              const SizedBox(height: Dimen.espacio4),
            ],
            if (hayReposicion) ...[
              InkWell(
                onTap: _elegirFechaReposicion,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Lo repone el (opcional)',
                    prefixIcon: Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: Colores.tintaTenue,
                    ),
                    constraints: BoxConstraints(minHeight: Dimen.campoMd),
                  ),
                  child: Text(
                    _fechaReposicion == null
                        ? 'Sin fecha'
                        : '${_fechaReposicion!.day.toString().padLeft(2, '0')}/'
                              '${_fechaReposicion!.month.toString().padLeft(2, '0')}/'
                              '${_fechaReposicion!.year}',
                    style: const TextStyle(fontSize: 14, color: Colores.tinta),
                  ),
                ),
              ),
              const SizedBox(height: Dimen.espacio4),
            ],
            if (descuento > 0) ...[
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: AppCampo(
                      controlador: _serieNc,
                      etiqueta: 'Serie NC',
                      opcional: true,
                      maxLargo: 10,
                    ),
                  ),
                  const SizedBox(width: Dimen.espacio3),
                  Expanded(
                    child: AppCampo(
                      controlador: _numeroNc,
                      etiqueta: 'Número de nota de crédito',
                      opcional: true,
                      maxLargo: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimen.espacio4),
            ],
            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBotonesFormulario(
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _guardar,
              cargando: _guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}

class _TarjetaFilaDevolucion extends StatelessWidget {
  const _TarjetaFilaDevolucion({
    required this.fila,
    required this.onResolucion,
  });

  final _FilaDevolucion fila;
  final ValueChanged<String> onResolucion;

  @override
  Widget build(BuildContext context) {
    final d = fila.detalle;
    final teclado = const TextInputType.numberWithOptions(decimal: true);
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
          Text(
            d.producto,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Llegaron ${formatoNumero(fila.enCompra(d.cantidadRecibida))} · '
            'faltan ${formatoNumero(fila.enCompra(d.cantidadPendiente))} ${fila.unidad}',
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              if (d.cantidadRecibida > 0)
                Expanded(
                  child: AppCampo(
                    controlador: fila.devolverCtrl,
                    etiqueta: 'Devolver (${fila.unidad})',
                    tipoTeclado: teclado,
                  ),
                ),
              if (d.cantidadRecibida > 0 && d.cantidadPendiente > 0)
                const SizedBox(width: Dimen.espacio3),
              if (d.cantidadPendiente > 0)
                Expanded(
                  child: AppCampo(
                    controlador: fila.rechazarCtrl,
                    etiqueta: 'No llegó (${fila.unidad})',
                    tipoTeclado: teclado,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),
          AppSelector<String>(
            valor: fila.resolucion,
            etiqueta: 'A cambio',
            icono: Icons.swap_horiz,
            opciones: const [
              Opcion(ResolucionDevolucion.descuento, 'Descuento: no lo repone'),
              Opcion(
                ResolucionDevolucion.reposicion,
                'Reposición: lo trae otro día',
              ),
            ],
            onCambio: (v) {
              if (v != null) onResolucion(v);
            },
          ),
          if (fila.importe > 0)
            Padding(
              padding: const EdgeInsets.only(top: Dimen.espacio2),
              child: Text(
                'Importe: S/ ${fila.importe.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colores.tinta,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que hara la devolucion con la plata, antes de guardarla.
class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.devuelto,
    required this.descuento,
    required this.reposicion,
    required this.saldoFavor,
    required this.deuda,
  });

  final double devuelto;
  final double descuento;
  final double reposicion;
  final double saldoFavor;
  final double deuda;

  @override
  Widget build(BuildContext context) {
    Widget fila(String etiqueta, double monto, {Color? color, String? nota}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  nota == null ? etiqueta : '$etiqueta · $nota',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colores.tintaSuave,
                  ),
                ),
              ),
              Text(
                'S/ ${monto.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color ?? Colores.tinta,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.fondo,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        children: [
          fila('Devuelto', devuelto),
          fila('Baja la compra', descuento, color: Colores.advertencia),
          fila('A reponer', reposicion),
          fila(
            'Saldo a favor',
            saldoFavor,
            color: saldoFavor > 0 ? Colores.exito : null,
            nota: saldoFavor > 0
                ? 'ya estaba pagado: te lo debe'
                : 'debías S/ ${deuda.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }
}
