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
import '../../maestros/datos/producto.dart';
import '../../maestros/datos/proveedor.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/orden_compra.dart';
import '../estado/compras_controlador.dart';

/// Una linea en edicion. Local al formulario: solo se convierte al formato
/// del backend al guardar.
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

/// Alta y edicion de una orden de compra. Solo se edita mientras esta
/// Pendiente.
class OrdenCompraFormulario extends ConsumerStatefulWidget {
  const OrdenCompraFormulario({super.key, this.orden});

  final OrdenCompra? orden;

  @override
  ConsumerState<OrdenCompraFormulario> createState() => _OrdenCompraFormularioState();
}

class _OrdenCompraFormularioState extends ConsumerState<OrdenCompraFormulario> {
  late final _observacion = TextEditingController(text: widget.orden?.observacion ?? '');

  late int? _proveedorId = widget.orden?.proveedorId;
  late String? _proveedorNombre = widget.orden?.proveedor;
  late DateTime? _fechaEsperada = widget.orden?.fechaEsperada;

  late final List<_FilaLinea> _lineas = [
    for (final l in widget.orden?.detalle ?? const <LineaCompra>[])
      _FilaLinea(
        productoId: l.productoId,
        producto: l.producto,
        presentacionId: l.presentacionId,
        presentacion: l.presentacion ?? l.unidadBase,
        cantidad: l.cantidad,
        costoPresentacion: l.costoUnitario * l.cantidadPresentacion,
      ),
  ];

  bool _guardando = false;
  String? _error;
  String? _errorProveedor;
  String? _errorLineas;

  bool get _esNuevo => widget.orden == null;

  double get _total => _lineas.fold<double>(0, (n, f) => n + f.subtotal);

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorProveedor = _proveedorId == null ? 'Elige el proveedor.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorProveedor == null && _errorLineas == null;
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
      'fechaEsperada': _fechaEsperada?.toIso8601String(),
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'detalle': [for (final f in _lineas) f.aCuerpo()],
    };

    try {
      if (_esNuevo) {
        await ref.read(ordenesCompraProvider.notifier).crear(cuerpo);
      } else {
        await ref.read(ordenesCompraProvider.notifier).actualizar(widget.orden!.id, cuerpo);
      }

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Orden creada' : 'Orden actualizada')),
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

  Future<void> _elegirFechaEsperada() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaEsperada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fechaEsperada = elegida);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esNuevo ? 'Nueva orden de compra' : 'Editar orden de compra',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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

          InkWell(
            onTap: _elegirFechaEsperada,
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            child: InputDecorator(
              decoration: const InputDecoration(
                label: Text.rich(
                  TextSpan(
                    text: 'Fecha esperada',
                    children: [TextSpan(text: ' (opcional)', style: TextStyle(color: Colores.tintaTenue))],
                  ),
                ),
                prefixIcon: Icon(Icons.event_outlined, size: 19, color: Colores.tintaTenue),
                constraints: BoxConstraints(minHeight: Dimen.campoLg),
              ),
              child: Text(
                _fechaEsperada == null ? 'Sin definir' : _fechaTexto(_fechaEsperada!),
                style: TextStyle(
                  fontSize: 15,
                  color: _fechaEsperada == null ? Colores.tintaTenue : Colores.tinta,
                ),
              ),
            ),
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
            texto: _esNuevo ? 'Crear orden' : 'Guardar cambios',
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

String _fechaTexto(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

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
