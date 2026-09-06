import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../finanzas/datos/metodo_pago.dart';
import '../../finanzas/estado/finanzas_controlador.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/datos/proveedor.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/compra.dart';
import '../estado/compras_controlador.dart';

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

  final List<LineaDocumento> _lineas = [];

  /// Las lineas de una compra que ya existe, una vez cargado el catalogo.
  ///
  /// Necesitan las presentaciones del producto para poder cambiar de unidad, y
  /// esas vienen del catalogo, que llega por red: armarlas en initState las
  /// dejaria sin unidades que ofrecer.
  bool _lineasPuestas = false;

  void _ponerLineasExistentes(List<Producto> catalogo) {
    final detalle = widget.compra?.detalle ?? const <CompraDetalle>[];
    if (_lineasPuestas || detalle.isEmpty || catalogo.isEmpty) return;
    _lineasPuestas = true;

    final porId = {for (final p in catalogo) p.id: p};
    final nuevas = [
      for (final l in detalle)
        LineaDocumento(
          productoId: l.productoId,
          producto: l.producto,
          codigo: l.codigo,
          unidadBase: l.unidadBase,
          presentaciones: _presentacionesDe(porId[l.productoId], false),
          presentacionId: l.presentacionId ?? 0,
          cantidad: l.cantidadPresentacion,
          // El costo se guarda por unidad base; aqui se edita por presentacion.
          importe: l.cantidadPresentacion == 0 ? 0 : l.costoTotal / l.cantidadPresentacion,
        ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lineas.addAll(nuevas));
    });
  }

  /// Las presentaciones que valen para este documento.
  static List<Presentacion> _presentacionesDe(Producto? p, bool venta) =>
      (p?.presentaciones ?? const <Presentacion>[])
          .where((pr) => pr.activo && (venta ? pr.esVenta : pr.esCompra))
          .toList();

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
      _errorPagos = _formaPago == FormaPagoCompra.contado && _totalPagado > _total + 0.001
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
      'detalle': [
        for (final f in _lineas)
          {
            'productoId': f.productoId,
            'presentacionId': f.presentacionId == 0 ? null : f.presentacionId,
            'cantidad': f.cantidad,
            'costoPresentacion': f.importe,
          },
      ],
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
      fila: (p) =>
          Text(p.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    if (elegido != null) {
      setState(() {
        _proveedorId = elegido.id;
        _proveedorNombre = elegido.nombre;
      });
    }
  }

  /// Agrega las lineas elegidas, vengan del panel o de la hoja multiple.
  void _agregarLineas(List<LineaElegida> elegidas) {
    setState(() {
      for (final e in elegidas) {
        _lineas.add(
          LineaDocumento(
            productoId: e.producto.id,
            producto: e.producto.nombre,
            codigo: e.producto.codigo,
            unidadBase: e.producto.unidadBase,
            presentaciones: _presentacionesDe(e.producto, false),
            presentacionId: e.presentacionId,
            cantidad: e.cantidad,
            importe: e.importe,
          ),
        );
      }
      _errorLineas = null;
    });
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
                _pagos.add(
                  _FilaPago(metodoPagoId: metodoId!, metodoPago: metodoNombre, monto: monto),
                );
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colores.tinta,
                    ),
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
                    opciones: [
                      for (final t in TipoMetodoPago.todos) Opcion(t, TipoMetodoPago.etiqueta(t)),
                    ],
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
    _ponerLineasExistentes(ref.watch(productosProvider).valueOrNull ?? const <Producto>[]);

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'compras',
      Scaffold(
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
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            InkWell(
              onTap: _elegirProveedor,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Proveedor',
                  errorText: _errorProveedor,
                  prefixIcon: const Icon(
                    Icons.business_outlined,
                    size: 19,
                    color: Colores.tintaTenue,
                  ),
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
              onCambio: (v) =>
                  setState(() => _tipoComprobante = v ?? TipoComprobanteCompra.factura),
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

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),

            AppPanelProducto(
              productos: (ref.watch(productosProvider).valueOrNull ?? const <Producto>[])
                  .where((p) => p.activo && p.controlaStock)
                  .toList(),
              paraVenta: false,
              habilitado: !_guardando,
              onAgregar: _agregarLineas,
            ),
            const SizedBox(height: Dimen.espacio5),

            // Lo agregado va DEBAJO del buscador: se lee como lo que acaba de
            // caer ahi, y el buscador no se aleja segun crece el documento.
            AppLineasProducto(
              lineas: _lineas,
              error: _errorLineas,
              etiquetaImporte: 'Costo S/',
              habilitado: !_guardando,
              onCambio: () => setState(() {}),
              onEliminar: (l) => setState(() => _lineas.remove(l)),
            ),
            const SizedBox(height: Dimen.espacio4),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: S/ ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colores.marca,
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio5),

            /*
           * El pago va al final, despues de los productos: hasta que no hay
           * lineas no se sabe cuanto se debe pagar, y pedirlo antes obligaba a
           * volver a subir para corregir el monto cada vez que se agregaba algo.
           */
            const Text(
              'Pago',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
            ),
            const SizedBox(height: Dimen.espacio3),

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
      ),
    );
  }
}
