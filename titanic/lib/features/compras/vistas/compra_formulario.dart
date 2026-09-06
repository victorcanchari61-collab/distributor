import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../finanzas/datos/metodo_pago.dart';
import '../../finanzas/estado/finanzas_controlador.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/datos/proveedor.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/compra.dart';
import '../estado/compras_controlador.dart';

class _FilaLinea {
  _FilaLinea({
    required this.productoId,
    required this.producto,
    this.presentacionId,
    required this.presentacion,
    required this.cantidad,
    required this.costoPresentacion,
  });

  final int productoId;
  final String producto;
  final int? presentacionId;
  final String presentacion;
  double cantidad;
  double costoPresentacion;

  double get subtotal => cantidad * costoPresentacion;

  Map<String, dynamic> aCuerpo() => {
    'productoId': productoId,
    'presentacionId': presentacionId,
    'cantidad': cantidad,
    'costoPresentacion': costoPresentacion,
  };
}

class _FilaPago {
  _FilaPago({required this.metodoPagoId, required this.metodoPago, required this.monto});

  final int metodoPagoId;
  final String metodoPago;
  final double monto;

  Map<String, dynamic> aCuerpo() => {'metodoPagoId': metodoPagoId, 'monto': monto};
}

/// Alta y edicion de una compra directa, sin orden previa.
///
/// Solo se edita mientras sigue Pendiente (nada recibido): en cuanto entra
/// mercaderia contra ella, solo se puede anular o seguir recibiendo.
class CompraFormulario extends ConsumerStatefulWidget {
  const CompraFormulario({super.key, this.compra});

  /// Null cuando es una compra nueva.
  final Compra? compra;

  @override
  ConsumerState<CompraFormulario> createState() => _CompraFormularioState();
}

class _CompraFormularioState extends ConsumerState<CompraFormulario> {
  late final _serie = TextEditingController(text: widget.compra?.serieComprobante ?? '');
  late final _numero = TextEditingController(text: widget.compra?.numeroComprobante ?? '');
  late final _observacion = TextEditingController(text: widget.compra?.observacion ?? '');

  late int? _proveedorId = widget.compra?.proveedorId;
  late String? _proveedorNombre = widget.compra?.proveedor;
  late String _tipoComprobante = widget.compra?.tipoComprobante ?? TipoComprobanteCompra.factura;
  late String _formaPago = widget.compra?.formaPago ?? FormaPagoCompra.contado;

  late final List<_FilaLinea> _lineas = [
    for (final l in widget.compra?.detalle ?? const [])
      _FilaLinea(
        productoId: l.productoId,
        producto: l.producto,
        presentacionId: l.presentacionId,
        presentacion: l.presentacion ?? l.unidadBase,
        cantidad: l.cantidadPresentacion,
        // El costo se guarda por unidad base; aqui se edita por presentacion.
        costoPresentacion: l.cantidadPresentacion == 0 ? 0 : l.costoTotal / l.cantidadPresentacion,
      ),
  ];
  late final List<_FilaPago> _pagos = [
    for (final p in widget.compra?.pagos ?? const [])
      _FilaPago(metodoPagoId: p.metodoPagoId, metodoPago: p.metodoPago, monto: p.monto),
  ];

  bool get _esNuevo => widget.compra == null;

  bool _guardando = false;
  String? _error;
  String? _errorProveedor;
  String? _errorLineas;
  String? _errorPagos;

  double get _total => _lineas.fold<double>(0, (n, f) => n + f.subtotal);
  double get _totalPagado => _pagos.fold<double>(0, (n, p) => n + p.monto);

  @override
  void dispose() {
    for (final c in [_serie, _numero, _observacion]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorProveedor = _proveedorId == null ? 'Elige el proveedor.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
      _errorPagos =
          _formaPago == FormaPagoCompra.contado && _totalPagado > _total + 0.001
          ? 'Lo pagado (S/ ${_totalPagado.toStringAsFixed(2)}) no puede superar el total.'
          : null;
    });
    return _errorProveedor == null && _errorLineas == null && _errorPagos == null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    final cuerpo = <String, dynamic>{
      'proveedorId': _proveedorId,
      'tipoComprobante': _tipoComprobante,
      'serieComprobante': _serie.text.trim().isEmpty ? null : _serie.text.trim(),
      'numeroComprobante': _numero.text.trim().isEmpty ? null : _numero.text.trim(),
      'formaPago': _formaPago,
      'pagos': _formaPago == FormaPagoCompra.contado
          ? [for (final p in _pagos) p.aCuerpo()]
          : const [],
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'detalle': [for (final f in _lineas) f.aCuerpo()],
    };

    try {
      if (_esNuevo) {
        await ref.read(comprasProvider.notifier).crear(cuerpo);
      } else {
        await ref.read(comprasProvider.notifier).actualizar(widget.compra!.id, cuerpo);
      }

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Compra registrada' : 'Compra actualizada')),
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  Future<void> _elegirProveedor() async {
    final proveedores = ref.read(proveedoresProvider).valueOrNull ?? const <Proveedor>[];
    final activos = proveedores.where((p) => p.activo).toList();
    final elegido = await mostrarSelectorBuscable<Proveedor>(
      context: context,
      titulo: 'Elige el proveedor',
      items: activos,
      buscable: (p) => p.buscable,
      pistaBusqueda: 'Buscar por nombre o documento',
      fila: (p) => Text(p.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    if (elegido != null) {
      setState(() {
        _proveedorId = elegido.id;
        _proveedorNombre = elegido.nombre;
      });
    }
  }

  Future<void> _agregarLinea() async {
    final productos = ref.read(productosProvider).valueOrNull ?? const <Producto>[];
    final activos = productos.where((p) => p.activo).toList();
    final producto = await mostrarSelectorBuscable<Producto>(
      context: context,
      titulo: 'Elige el producto',
      items: activos,
      buscable: (p) => p.buscable,
      pistaBusqueda: 'Buscar por código o nombre',
      fila: (p) => Text('${p.codigo} · ${p.nombre}', style: const TextStyle(fontSize: 14)),
    );
    if (producto == null || !mounted) return;

    final fila = await _mostrarHojaLinea(producto: producto);
    if (fila != null) setState(() => _lineas.add(fila));
  }

  Future<void> _editarLinea(_FilaLinea original) async {
    final productos = ref.read(productosProvider).valueOrNull ?? const <Producto>[];
    final producto = productos.firstWhere(
      (p) => p.id == original.productoId,
      orElse: () => Producto(
        id: original.productoId,
        codigo: '',
        nombre: original.producto,
        unidadBaseId: 0,
        unidadBase: '',
        controlaStock: false,
        stockMinimo: 0,
        activo: true,
        presentaciones: const [],
      ),
    );
    final fila = await _mostrarHojaLinea(producto: producto, existente: original);
    if (fila != null) {
      setState(() {
        final i = _lineas.indexOf(original);
        _lineas[i] = fila;
      });
    }
  }

  Future<_FilaLinea?> _mostrarHojaLinea({required Producto producto, _FilaLinea? existente}) {
    final presentaciones = producto.presentaciones.where((p) => p.esCompra).toList();
    final cantidadCtrl = TextEditingController(
      text: existente == null ? '' : formatoNumero(existente.cantidad),
    );
    final costoCtrl = TextEditingController(
      text: existente == null ? '' : formatoNumero(existente.costoPresentacion),
    );
    int? presentacionId =
        existente?.presentacionId ?? (presentaciones.length == 1 ? presentaciones.first.id : null);
    String? errorCantidad;
    String? errorCosto;
    String? errorPresentacion;

    return showModalBottomSheet<_FilaLinea>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void guardar() {
              final cantidad = double.tryParse(cantidadCtrl.text.trim().replaceAll(',', '.'));
              final costo = double.tryParse(costoCtrl.text.trim().replaceAll(',', '.'));

              setSheetState(() {
                errorPresentacion = presentaciones.isNotEmpty && presentacionId == null
                    ? 'Elige la presentación.'
                    : null;
                errorCantidad = cantidad == null || cantidad <= 0
                    ? 'Debe ser mayor que cero.'
                    : null;
                errorCosto = costo == null || costo <= 0 ? 'Debe ser mayor que cero.' : null;
              });
              if (errorPresentacion != null || errorCantidad != null || errorCosto != null) {
                return;
              }

              Presentacion? presentacion;
              for (final p in presentaciones) {
                if (p.id == presentacionId) presentacion = p;
              }
              Navigator.of(context).pop(
                _FilaLinea(
                  productoId: producto.id,
                  producto: producto.nombre,
                  presentacionId: presentacionId,
                  presentacion: presentacion?.nombre ?? producto.unidadBase,
                  cantidad: cantidad!,
                  costoPresentacion: costo!,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: Dimen.espacio4,
                right: Dimen.espacio4,
                top: Dimen.espacio2,
                bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  if (presentaciones.isNotEmpty) ...[
                    AppSelector<int>(
                      valor: presentacionId,
                      etiqueta: 'Presentación',
                      icono: Icons.inventory_2_outlined,
                      error: errorPresentacion,
                      opciones: [
                        for (final p in presentaciones)
                          Opcion(p.id, '${p.nombre} (${formatoNumero(p.factor)} ${producto.unidadBase})'),
                      ],
                      onCambio: (v) => setSheetState(() => presentacionId = v),
                    ),
                    const SizedBox(height: Dimen.espacio4),
                  ],
                  AppCampo(
                    controlador: cantidadCtrl,
                    etiqueta: 'Cantidad',
                    icono: Icons.numbers_outlined,
                    tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                    error: errorCantidad,
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  AppCampo(
                    controlador: costoCtrl,
                    etiqueta: 'Costo de la presentación',
                    pista: 'Lo que vale la presentación completa',
                    icono: Icons.payments_outlined,
                    tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                    error: errorCosto,
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  AppBoton(
                    texto: existente == null ? 'Agregar' : 'Guardar cambios',
                    onPressed: guardar,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _gestionarPagos() async {
    final metodos = ref.read(metodosPagoActivosProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (context) {
        String? tipo;
        int? metodoId;
        final montoCtrl = TextEditingController();
        String? errorAgregar;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final metodosDelTipo = metodos.where((m) => m.tipo == tipo).toList();
            final totalPagado = _pagos.fold<double>(0, (n, p) => n + p.monto);
            final excedido = totalPagado > _total + 0.001;

            void agregar() {
              final monto = double.tryParse(montoCtrl.text.trim().replaceAll(',', '.'));
              if (metodoId == null) {
                setSheetState(() => errorAgregar = 'Elige el método de pago.');
                return;
              }
              if (monto == null || monto <= 0) {
                setSheetState(() => errorAgregar = 'Ingresa un monto válido.');
                return;
              }
              if (totalPagado + monto > _total + 0.001) {
                setSheetState(
                  () => errorAgregar =
                      'Ese pago deja lo pagado en S/ ${(totalPagado + monto).toStringAsFixed(2)}, '
                      'más que el total de la compra (S/ ${_total.toStringAsFixed(2)}).',
                );
                return;
              }

              String metodoNombre = '';
              for (final m in metodos) {
                if (m.id == metodoId) metodoNombre = m.nombre;
              }
              setSheetState(() {
                _pagos.add(_FilaPago(metodoPagoId: metodoId!, metodoPago: metodoNombre, monto: monto));
                tipo = null;
                metodoId = null;
                montoCtrl.clear();
                errorAgregar = null;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: Dimen.espacio4,
                right: Dimen.espacio4,
                top: Dimen.espacio2,
                bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pagos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                  ),
                  const SizedBox(height: Dimen.espacio4),

                  for (final pago in _pagos) ...[
                    Container(
                      padding: const EdgeInsets.all(Dimen.espacio3),
                      decoration: BoxDecoration(
                        color: Colores.fondo,
                        borderRadius: BorderRadius.circular(Dimen.radioCampo),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              pago.metodoPago,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            'S/ ${pago.monto.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setSheetState(() => _pagos.remove(pago)),
                            icon: const Icon(Icons.close, size: 16, color: Colores.peligro),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Dimen.espacio2),
                  ],

                  if (errorAgregar != null) ...[
                    AppAlerta(errorAgregar!),
                    const SizedBox(height: Dimen.espacio3),
                  ],

                  AppSelector<String>(
                    valor: tipo,
                    etiqueta: 'Tipo',
                    icono: Icons.category_outlined,
                    opciones: [for (final t in TipoMetodoPago.todos) Opcion(t, TipoMetodoPago.etiqueta(t))],
                    onCambio: (v) => setSheetState(() {
                      tipo = v;
                      metodoId = null;
                    }),
                  ),
                  const SizedBox(height: Dimen.espacio3),

                  AppSelector<int>(
                    valor: metodoId,
                    etiqueta: 'Método',
                    icono: Icons.payments_outlined,
                    habilitado: tipo != null,
                    opciones: [for (final m in metodosDelTipo) Opcion(m.id, m.nombre)],
                    onCambio: (v) => setSheetState(() => metodoId = v),
                  ),
                  const SizedBox(height: Dimen.espacio3),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppCampo(
                          controlador: montoCtrl,
                          etiqueta: 'Monto',
                          icono: Icons.attach_money,
                          tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: Dimen.espacio3),
                      AppBoton(texto: 'Agregar', onPressed: agregar),
                    ],
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  const Divider(height: 1),
                  const SizedBox(height: Dimen.espacio3),

                  Row(
                    children: [
                      Text(
                        'Pagado: S/ ${totalPagado.toStringAsFixed(2)} de S/ ${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: excedido ? Colores.peligro : Colores.tinta,
                        ),
                      ),
                      const Spacer(),
                      AppBoton(
                        texto: 'Listo',
                        variante: BotonVariante.secundario,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esNuevo ? 'Nueva compra' : 'Editar ${widget.compra!.numero}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Dimen.espacio4),
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio4),
          ],

          InkWell(
            onTap: _elegirProveedor,
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Proveedor',
                errorText: _errorProveedor,
                prefixIcon: const Icon(Icons.business_outlined, size: 19, color: Colores.tintaTenue),
                suffixIcon: const Icon(Icons.search, size: 18, color: Colores.tintaTenue),
                constraints: const BoxConstraints(minHeight: Dimen.campoLg),
              ),
              child: Text(
                _proveedorNombre ?? 'Toca para elegir',
                style: TextStyle(
                  fontSize: 15,
                  color: _proveedorNombre == null ? Colores.tintaTenue : Colores.tinta,
                ),
              ),
            ),
          ),
          const SizedBox(height: Dimen.espacio4),

          AppSelector<String>(
            valor: _tipoComprobante,
            etiqueta: 'Tipo de comprobante',
            icono: Icons.receipt_long_outlined,
            opciones: [
              for (final t in TipoComprobanteCompra.todos)
                Opcion(t, TipoComprobanteCompra.etiqueta(t)),
            ],
            onCambio: (v) => setState(() => _tipoComprobante = v ?? TipoComprobanteCompra.factura),
          ),
          const SizedBox(height: Dimen.espacio4),

          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _serie,
                  etiqueta: 'Serie',
                  opcional: true,
                  pista: 'F001',
                  habilitado: !_guardando,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                flex: 2,
                child: AppCampo(
                  controlador: _numero,
                  etiqueta: 'Número',
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio4),

          AppSelector<String>(
            valor: _formaPago,
            etiqueta: 'Forma de pago',
            icono: Icons.wallet_outlined,
            opciones: const [
              Opcion(FormaPagoCompra.contado, 'Contado'),
              Opcion(FormaPagoCompra.credito, 'Crédito'),
            ],
            onCambio: (v) => setState(() {
              _formaPago = v ?? FormaPagoCompra.contado;
              if (_formaPago == FormaPagoCompra.credito) _pagos.clear();
            }),
          ),
          const SizedBox(height: Dimen.espacio4),

          if (_formaPago == FormaPagoCompra.contado) ...[
            Container(
              padding: const EdgeInsets.all(Dimen.espacio3),
              decoration: BoxDecoration(
                color: Colores.fondo,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
                border: _errorPagos != null ? Border.all(color: Colores.peligro) : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pagos.isEmpty
                          ? 'Sin pagos registrados'
                          : 'Pagado: S/ ${_totalPagado.toStringAsFixed(2)} de S/ ${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _errorPagos != null ? Colores.peligro : Colores.tinta,
                      ),
                    ),
                  ),
                  AppBoton(
                    texto: _pagos.isEmpty ? 'Agregar pago' : 'Gestionar pagos',
                    variante: BotonVariante.secundario,
                    expandido: false,
                    onPressed: _gestionarPagos,
                  ),
                ],
              ),
            ),
            if (_errorPagos != null) ...[
              const SizedBox(height: Dimen.espacio1),
              Text(_errorPagos!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
            ],
          ] else
            const Text(
              'Al crédito no se registra un pago ahora: queda pendiente para Cuentas por pagar.',
              style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _observacion,
            etiqueta: 'Observación',
            icono: Icons.notes_outlined,
            opcional: true,
            maxLargo: 250,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio5),

          Row(
            children: [
              const Text(
                'Productos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
              ),
              const Spacer(),
              Text(
                'Total: S/ ${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colores.marca),
              ),
            ],
          ),
          if (_errorLineas != null) ...[
            const SizedBox(height: Dimen.espacio1),
            Text(_errorLineas!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
          ],
          const SizedBox(height: Dimen.espacio3),

          for (final fila in _lineas) ...[
            _TarjetaLineaCompra(
              fila: fila,
              onEditar: () => _editarLinea(fila),
              onEliminar: () => setState(() => _lineas.remove(fila)),
            ),
            const SizedBox(height: Dimen.espacio2),
          ],
          if (_lineas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
              child: Text(
                'Todavía no agregaste productos.',
                style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
              ),
            ),
          const SizedBox(height: Dimen.espacio2),

          AppBoton(
            texto: 'Agregar producto',
            variante: BotonVariante.secundario,
            icono: Icons.add,
            onPressed: _guardando ? null : _agregarLinea,
          ),
          const SizedBox(height: Dimen.espacio6),

          AppBoton(
            texto: _esNuevo ? 'Registrar compra' : 'Guardar cambios',
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
    );
  }
}

class _TarjetaLineaCompra extends StatelessWidget {
  const _TarjetaLineaCompra({required this.fila, required this.onEditar, required this.onEliminar});

  final _FilaLinea fila;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fila.producto,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatoNumero(fila.cantidad)} ${fila.presentacion} · '
                  'S/ ${fila.costoPresentacion.toStringAsFixed(2)} c/u',
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ],
            ),
          ),
          Text(
            'S/ ${fila.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colores.tinta),
          ),
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
          ),
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
          ),
        ],
      ),
    );
  }
}
