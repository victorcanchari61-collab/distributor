import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/datos/proveedor.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/orden_compra.dart';
import '../estado/compras_controlador.dart';

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

  final List<LineaDocumento> _lineas = [];

  /// Las lineas de una orden que ya existe, una vez cargado el catalogo.
  ///
  /// Necesitan las presentaciones del producto para poder cambiar de unidad, y
  /// esas vienen del catalogo, que llega por red: armarlas en initState las
  /// dejaria sin unidades que ofrecer.
  bool _lineasPuestas = false;

  void _ponerLineasExistentes(List<Producto> catalogo) {
    final detalle = widget.orden?.detalle ?? const <LineaCompra>[];
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
          /*
           * Las dos cifras van en la MISMA unidad: la presentacion.
           *
           * Antes se mezclaban — la cantidad venia en unidad base y el costo se
           * sacaba multiplicando el costo por unidad base por el numero de
           * presentaciones. Con 2 sacos de 50 kg a S/ 100 el saco, la orden se
           * abria mostrando 100 de cantidad y S/ 4 de costo. Se notaba poco
           * porque la linea casi no se tocaba; ahora que se edita en el sitio,
           * abrir una orden y guardarla la dejaria con otros numeros.
           */
          cantidad: l.cantidadPresentacion,
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

  Future<void> _elegirFechaEsperada() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaEsperada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fechaEsperada = elegida);
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

  @override
  Widget build(BuildContext context) {
    _ponerLineasExistentes(ref.watch(productosProvider).valueOrNull ?? const <Producto>[]);

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'compras',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nueva orden de compra' : 'Editar orden de compra',
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

            InkWell(
              onTap: _elegirFechaEsperada,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
              child: InputDecorator(
                decoration: const InputDecoration(
                  label: Text.rich(
                    TextSpan(
                      text: 'Fecha esperada',
                      children: [
                        TextSpan(
                          text: ' (opcional)',
                          style: TextStyle(color: Colores.tintaTenue),
                        ),
                      ],
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Acento.de(context),
                ),
              ),
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
      ),
    );
  }
}

String _fechaTexto(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
