import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_campo_cliente.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../facturacion/datos/lista_precio.dart';
import '../../facturacion/estado/facturacion_controlador.dart';
import '../../finanzas/datos/metodo_pago.dart';
import '../../finanzas/estado/finanzas_controlador.dart';
import '../../inventario/datos/almacen.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../maestros/datos/cliente.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/nota_venta.dart';
import '../estado/ventas_controlador.dart';

class _FilaPago {
  _FilaPago({required this.metodoPagoId, required this.metodoPago, required this.monto});

  final int metodoPagoId;
  final String metodoPago;
  final double monto;

  Map<String, dynamic> aCuerpo() => {'metodoPagoId': metodoPagoId, 'monto': monto};
}

/// Alta de una venta directa, sin pedido previo: el stock sale al momento.
class NotaVentaFormulario extends ConsumerStatefulWidget {
  const NotaVentaFormulario({super.key});

  @override
  ConsumerState<NotaVentaFormulario> createState() => _NotaVentaFormularioState();
}

class _NotaVentaFormularioState extends ConsumerState<NotaVentaFormulario> {
  final _observacion = TextEditingController();

  int? _clienteId;
  String? _clienteNombre;
  int? _almacenId;
  int? _listaPrecioId;
  String _formaPago = FormaPagoVenta.contado;

  final List<LineaDocumento> _lineas = [];
  final List<_FilaPago> _pagos = [];

  /// Las presentaciones que valen para este documento.
  static List<Presentacion> _presentacionesDe(Producto? p, bool venta) =>
      (p?.presentaciones ?? const <Presentacion>[])
          .where((pr) => pr.activo && (venta ? pr.esVenta : pr.esCompra))
          .toList();

  bool _guardando = false;
  String? _error;
  String? _errorCliente;
  String? _errorAlmacen;
  String? _errorLineas;
  String? _errorPagos;

  double get _total => _lineas.fold<double>(0, (n, f) => n + f.subtotal);
  double get _totalPagado => _pagos.fold<double>(0, (n, p) => n + p.monto);

  @override
  void initState() {
    super.initState();
  }

  /*
   * El principal por defecto: quien tiene un solo depósito nunca lo elige.
   *
   * NO se hace en initState: los almacenes llegan por red y en ese momento la
   * lista casi siempre está vacía todavía, así que el campo se quedaba en
   * blanco para siempre. Se resuelve en el build, la primera vez que la lista
   * trae algo — y solo esa vez, para no pisar lo que la persona elija después.
   */
  bool _almacenPuesto = false;

  void _ponerAlmacenPorDefecto(List<Almacen> almacenes) {
    if (_almacenPuesto || almacenes.isEmpty) return;
    _almacenPuesto = true;
    if (_almacenId != null) return;

    var elegido = almacenes.first.id;
    for (final a in almacenes) {
      if (a.esPrincipal) elegido = a.id;
    }

    // En el build no se puede llamar a setState; se agenda para el cuadro
    // siguiente, que llega antes de que la pantalla se pinte.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _almacenId = elegido);
    });
  }

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorCliente = _clienteId == null ? 'Elige el cliente.' : null;
      _errorAlmacen = _almacenId == null ? 'Elige el almacén.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
      _errorPagos = _formaPago == FormaPagoVenta.contado && _totalPagado > _total + 0.001
          ? 'Lo pagado (S/ ${_totalPagado.toStringAsFixed(2)}) no puede superar el total.'
          : null;
    });
    return _errorCliente == null &&
        _errorAlmacen == null &&
        _errorLineas == null &&
        _errorPagos == null;
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
      'clienteId': _clienteId,
      'almacenId': _almacenId,
      'listaPrecioId': _listaPrecioId,
      'formaPago': _formaPago,
      'pagos': _formaPago == FormaPagoVenta.contado
          ? [for (final p in _pagos) p.aCuerpo()]
          : const [],
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'detalle': [
        for (final f in _lineas)
          {
            'productoId': f.productoId,
            'presentacionId': f.presentacionId == 0 ? null : f.presentacionId,
            'cantidad': f.cantidad,
            'precioUnitario': f.importe,
          },
      ],
    };

    try {
      await ref.read(notasVentaProvider.notifier).crear(cuerpo);

      navegador.pop();
      mensajero.showSnackBar(const SnackBar(content: Text('Venta registrada')));
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
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
            presentaciones: _presentacionesDe(e.producto, true),
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
                      'más que el total de la venta (S/ ${_total.toStringAsFixed(2)}).',
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
                      AppBoton(texto: 'Agregar', expandido: false, onPressed: agregar),
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
                        expandido: false,
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
    final almacenes = ref.watch(almacenesActivosProvider);
    _ponerAlmacenPorDefecto(almacenes);
    final listas = ref.watch(listasPrecioProvider).valueOrNull ?? const <ListaPrecio>[];

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'fact',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Nueva venta',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            campoCliente(
              clientes: ref.watch(clientesProvider).valueOrNull ?? const <Cliente>[],
              elegido: _clienteNombre,
              error: _errorCliente,
              habilitado: !_guardando,
              onElegir: (c) => setState(() {
                _clienteId = c.id;
                _clienteNombre = c.nombre;
                _errorCliente = null;
              }),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: _almacenId,
              etiqueta: 'Almacén',
              icono: Icons.warehouse_outlined,
              error: _errorAlmacen,
              opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
              onCambio: (v) => setState(() => _almacenId = v),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int?>(
              valor: _listaPrecioId,
              etiqueta: 'Lista de precios',
              icono: Icons.sell_outlined,
              opciones: [
                const Opcion<int?>(null, 'Predeterminada'),
                for (final l in listas) Opcion<int?>(l.id, l.nombre),
              ],
              onCambio: (v) => setState(() => _listaPrecioId = v),
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

            /*
           * El stock que se ofrece es el del almacen desde donde se despacha
           * (por defecto el principal), no el total de la empresa: prometerle
           * a un cliente algo que esta en otro deposito es prometer lo que no
           * hay.
           */
            AppPanelProducto(
              productos: (ref.watch(productosProvider).valueOrNull ?? const <Producto>[])
                  .where((p) => p.activo && p.controlaStock)
                  .toList(),
              paraVenta: true,
              stock: ref.watch(stockDisponibleProvider(_almacenId)).valueOrNull,
              habilitado: !_guardando,
              onAgregar: _agregarLineas,
            ),
            const SizedBox(height: Dimen.espacio5),

            // Lo agregado va DEBAJO del buscador: se lee como lo que acaba de
            // caer ahi, y el buscador no se aleja segun crece el documento.
            AppLineasProducto(
              lineas: _lineas,
              error: _errorLineas,
              habilitado: !_guardando,
              disponible: ref.watch(stockDisponibleProvider(_almacenId)).valueOrNull,
              onCambio: () => setState(() {}),
              onEliminar: (l) => setState(() => _lineas.remove(l)),
            ),
            const SizedBox(height: Dimen.espacio4),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: S/ ${_total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Acento.de(context),
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio5),

            /*
           * El pago va al final, despues de los productos: hasta que no hay
           * lineas no se sabe cuanto se debe cobrar, y pedirlo antes obligaba a
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
                Opcion(FormaPagoVenta.contado, 'Contado'),
                Opcion(FormaPagoVenta.credito, 'Crédito'),
              ],
              onCambio: (v) => setState(() {
                _formaPago = v ?? FormaPagoVenta.contado;
                if (_formaPago == FormaPagoVenta.credito) _pagos.clear();
              }),
            ),
            const SizedBox(height: Dimen.espacio4),

            if (_formaPago == FormaPagoVenta.contado) ...[
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
                'Al crédito no se registra un pago ahora: queda pendiente de cobro.',
                style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
              ),
            const SizedBox(height: Dimen.espacio4),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(texto: 'Registrar venta', cargando: _guardando, onPressed: _guardar),
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
