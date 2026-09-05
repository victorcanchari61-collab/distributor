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
import '../../facturacion/datos/lista_precio.dart';
import '../../facturacion/estado/facturacion_controlador.dart';
import '../../inventario/datos/almacen.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../maestros/datos/cliente.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';

class _FilaLinea {
  _FilaLinea({
    required this.productoId,
    required this.producto,
    this.presentacionId,
    required this.presentacion,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int productoId;
  final String producto;
  final int? presentacionId;
  final String presentacion;
  double cantidad;
  double precioUnitario;

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> aCuerpo() => {
    'productoId': productoId,
    'presentacionId': presentacionId,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
  };
}

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

  late final List<_FilaLinea> _lineas = [
    for (final l in widget.pedido?.detalle ?? const <LineaVenta>[])
      _FilaLinea(
        productoId: l.productoId,
        producto: l.producto,
        presentacionId: l.presentacionId,
        presentacion: l.presentacion ?? l.unidadBase,
        cantidad: l.cantidadPresentacion,
        precioUnitario: l.precioUnitario,
      ),
  ];

  bool _guardando = false;
  String? _error;
  String? _errorCliente;
  String? _errorLineas;
  String? _errorAlmacen;

  bool get _esNuevo => widget.pedido == null;

  double get _total => _lineas.fold<double>(0, (n, f) => n + f.subtotal);

  /// El primero que se creó, no el primero de la lista (que viene ordenada
  /// por nombre): es el que tiene el id más chico.
  int? _primerAlmacenId(List<Almacen> almacenes) {
    if (almacenes.isEmpty) return null;
    return almacenes.map((a) => a.id).reduce((a, b) => a < b ? a : b);
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
      'detalle': [for (final f in _lineas) f.aCuerpo()],
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

  Future<void> _elegirCliente() async {
    final clientes = ref.read(clientesProvider).valueOrNull ?? const <Cliente>[];
    final activos = clientes.where((c) => c.activo).toList();
    final elegido = await mostrarSelectorBuscable<Cliente>(
      context: context,
      titulo: 'Elige el cliente',
      items: activos,
      buscable: (c) => c.buscable,
      pistaBusqueda: 'Buscar por nombre o documento',
      fila: (c) => Text(c.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    if (elegido != null) {
      setState(() {
        _clienteId = elegido.id;
        _clienteNombre = elegido.nombre;
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

  Future<_FilaLinea?> _mostrarHojaLinea({
    required Producto producto,
    _FilaLinea? existente,
  }) {
    final presentaciones = producto.presentaciones.where((p) => p.esVenta).toList();
    final cantidadCtrl = TextEditingController(
      text: existente == null ? '' : formatoNumero(existente.cantidad),
    );
    final precioCtrl = TextEditingController(
      text: existente == null ? '' : formatoNumero(existente.precioUnitario),
    );
    int? presentacionId =
        existente?.presentacionId ?? (presentaciones.length == 1 ? presentaciones.first.id : null);
    String? errorCantidad;
    String? errorPrecio;

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
              final precio = double.tryParse(precioCtrl.text.trim().replaceAll(',', '.'));

              setSheetState(() {
                errorCantidad = cantidad == null || cantidad <= 0 ? 'Debe ser mayor que cero.' : null;
                errorPrecio = precio == null || precio <= 0 ? 'Debe ser mayor que cero.' : null;
              });
              if (errorCantidad != null || errorPrecio != null) return;

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
                  precioUnitario: precio!,
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
                    controlador: precioCtrl,
                    etiqueta: 'Precio de venta',
                    icono: Icons.payments_outlined,
                    tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                    error: errorPrecio,
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

  @override
  Widget build(BuildContext context) {
    final listas = ref.watch(listasPrecioProvider).valueOrNull ?? const <ListaPrecio>[];
    final almacenes = ref.watch(almacenesActivosProvider);

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

          InkWell(
            onTap: _elegirCliente,
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Cliente',
                errorText: _errorCliente,
                prefixIcon: const Icon(Icons.contacts_outlined, size: 19, color: Colores.tintaTenue),
                suffixIcon: const Icon(Icons.search, size: 18, color: Colores.tintaTenue),
                constraints: const BoxConstraints(minHeight: Dimen.campoLg),
              ),
              child: Text(
                _clienteNombre ?? 'Toca para elegir',
                style: TextStyle(
                  fontSize: 15,
                  color: _clienteNombre == null ? Colores.tintaTenue : Colores.tinta,
                ),
              ),
            ),
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
          const Divider(height: 1),
          const SizedBox(height: Dimen.espacio2),

          CheckboxListTile(
            value: _reservaStock,
            onChanged: (v) => setState(() {
              _reservaStock = v ?? false;
              _almacenReservaId ??= _primerAlmacenId(almacenes);
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Reservar stock',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colores.tinta),
            ),
            subtitle: const Text(
              'Aparta el stock de un almacén mientras el pedido esté pendiente, para que '
              'no se pueda prometer dos veces. Se libera al confirmar o anular.',
              style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ),
          if (_reservaStock) ...[
            const SizedBox(height: Dimen.espacio2),
            AppSelector<int>(
              valor: _almacenReservaId,
              etiqueta: 'Almacén',
              icono: Icons.warehouse_outlined,
              error: _errorAlmacen,
              opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
              onCambio: (v) => setState(() => _almacenReservaId = v),
            ),
          ],
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
            _TarjetaLinea(
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

class _TarjetaLinea extends StatelessWidget {
  const _TarjetaLinea({required this.fila, required this.onEditar, required this.onEliminar});

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
                  'S/ ${fila.precioUnitario.toStringAsFixed(2)} c/u',
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
