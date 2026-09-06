import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_campo_cliente.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../facturacion/datos/lista_precio.dart';
import '../../facturacion/estado/facturacion_controlador.dart';
import '../../inventario/datos/almacen.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../maestros/datos/cliente.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';

/// Alta y edicion de un pedido. Solo se edita mientras esta Pendiente.
class PedidoFormulario extends ConsumerStatefulWidget {
  const PedidoFormulario({super.key, this.pedido});

  final Pedido? pedido;

  @override
  ConsumerState<PedidoFormulario> createState() => _PedidoFormularioState();
}

class _PedidoFormularioState extends ConsumerState<PedidoFormulario> {
  late final _observacion = TextEditingController(text: widget.pedido?.observacion ?? '');

  late int? _clienteId = widget.pedido?.clienteId;
  late String? _clienteNombre = widget.pedido?.cliente;
  late int? _listaPrecioId = widget.pedido?.listaPrecioId;
  late bool _reservaStock = widget.pedido?.reservaStock ?? false;
  late int? _almacenReservaId = widget.pedido?.almacenId;

  final List<LineaDocumento> _lineas = [];

  /// Las lineas de un pedido que ya existe, una vez cargado el catalogo.
  ///
  /// Necesitan las presentaciones del producto para poder cambiar de unidad, y
  /// esas vienen del catalogo, que llega por red: armarlas en initState las
  /// dejaria sin unidades que ofrecer.
  bool _lineasPuestas = false;

  void _ponerLineasExistentes(List<Producto> catalogo) {
    final detalle = widget.pedido?.detalle ?? const <LineaVenta>[];
    if (_lineasPuestas || detalle.isEmpty || catalogo.isEmpty) return;
    _lineasPuestas = true;

    final porId = {for (final p in catalogo) p.id: p};
    final nuevas = [
      for (final l in detalle)
        LineaDocumento(
          productoId: l.productoId,
          producto: l.producto,
          codigo: porId[l.productoId]?.codigo ?? '',
          unidadBase: l.unidadBase,
          presentaciones: _presentacionesDe(porId[l.productoId], true),
          presentacionId: l.presentacionId ?? 0,
          cantidad: l.cantidadPresentacion,
          importe: l.precioUnitario,
        ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lineas.addAll(nuevas));
    });
  }

  bool _guardando = false;
  String? _error;
  String? _errorCliente;
  String? _errorLineas;
  String? _errorAlmacen;

  bool get _esNuevo => widget.pedido == null;

  double get _total => _lineas.fold<double>(0, (n, f) => n + f.subtotal);

  /// Las presentaciones que valen para este documento.
  static List<Presentacion> _presentacionesDe(Producto? p, bool venta) =>
      (p?.presentaciones ?? const <Presentacion>[])
          .where((pr) => pr.activo && (venta ? pr.esVenta : pr.esCompra))
          .toList();

  /// El almacén principal (marcado en Almacenes); si no hubiera, el más antiguo.
  int? _primerAlmacenId(List<Almacen> almacenes) {
    if (almacenes.isEmpty) return null;
    for (final a in almacenes) {
      if (a.esPrincipal) return a.id;
    }
    return almacenes.map((a) => a.id).reduce((a, b) => a < b ? a : b);
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
    if (_almacenReservaId != null) return;

    final principal = _primerAlmacenId(almacenes);
    if (principal == null) return;

    // En el build no se puede llamar a setState; se agenda para el cuadro
    // siguiente, que llega antes de que la pantalla se pinte.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _almacenReservaId = principal);
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
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
      _errorAlmacen = _reservaStock && _almacenReservaId == null ? 'Elige el almacén.' : null;
    });
    return _errorCliente == null && _errorLineas == null && _errorAlmacen == null;
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
      'listaPrecioId': _listaPrecioId,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'reservaStock': _reservaStock,
      'almacenId': _reservaStock ? _almacenReservaId : null,
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
      if (_esNuevo) {
        await ref.read(pedidosProvider.notifier).crear(cuerpo);
      } else {
        await ref.read(pedidosProvider.notifier).actualizar(widget.pedido!.id, cuerpo);
      }

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Pedido creado' : 'Pedido actualizado')),
      );
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

  @override
  Widget build(BuildContext context) {
    final listas = ref.watch(listasPrecioProvider).valueOrNull ?? const <ListaPrecio>[];
    final almacenes = ref.watch(almacenesActivosProvider);
    _ponerAlmacenPorDefecto(almacenes);
    _ponerLineasExistentes(ref.watch(productosProvider).valueOrNull ?? const <Producto>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esNuevo ? 'Nuevo pedido' : 'Editar pedido',
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
          const SizedBox(height: Dimen.espacio4),

          AppSelector<int>(
            valor: _almacenReservaId,
            etiqueta: 'Almacén',
            icono: Icons.warehouse_outlined,
            error: _errorAlmacen,
            opciones: [
              for (final a in almacenes)
                Opcion<int>(a.id, a.esPrincipal ? '${a.nombre} (principal)' : a.nombre),
            ],
            onCambio: (v) => setState(() => _almacenReservaId = v),
          ),
          const SizedBox(height: Dimen.espacio2),

          CheckboxListTile(
            value: _reservaStock,
            onChanged: (v) => setState(() => _reservaStock = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Reservar stock',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colores.tinta),
            ),
            subtitle: const Text(
              'Aparta el stock de ese almacén mientras el pedido esté pendiente, para que '
              'no se pueda prometer dos veces. Se libera al confirmar o anular.',
              style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
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
            stock: ref.watch(stockDisponibleProvider(_almacenReservaId)).valueOrNull,
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
            disponible: ref.watch(stockDisponibleProvider(_almacenReservaId)).valueOrNull,
            onCambio: () => setState(() {}),
            onEliminar: (l) => setState(() => _lineas.remove(l)),
          ),
          const SizedBox(height: Dimen.espacio4),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: S/ ${_total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.marca),
            ),
          ),
          const SizedBox(height: Dimen.espacio6),

          AppBoton(
            texto: _esNuevo ? 'Crear pedido' : 'Guardar cambios',
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
