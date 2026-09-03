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
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/prestamo.dart';
import '../estado/inventario_controlador.dart';

class _FilaLineaPrestamo {
  _FilaLineaPrestamo({
    required this.productoId,
    required this.producto,
    this.presentacionId,
    required this.presentacion,
    required this.cantidad,
    this.costoPresentacion,
  });

  final int productoId;
  final String producto;
  final int? presentacionId;
  final String presentacion;
  final double cantidad;
  final double? costoPresentacion;

  Map<String, dynamic> aCuerpo() => {
    'productoId': productoId,
    'presentacionId': presentacionId,
    'cantidad': cantidad,
    'costoPresentacion': costoPresentacion,
  };
}

/// Alta de un prestamo: mercaderia que sale o entra desde fuera de la
/// empresa, y se espera de vuelta.
class PrestamoFormulario extends ConsumerStatefulWidget {
  const PrestamoFormulario({super.key});

  @override
  ConsumerState<PrestamoFormulario> createState() => _PrestamoFormularioState();
}

class _PrestamoFormularioState extends ConsumerState<PrestamoFormulario> {
  final _contraparte = TextEditingController();
  final _observacion = TextEditingController();

  String _tipo = TipoPrestamo.dado;
  int? _almacenId;
  final List<_FilaLineaPrestamo> _lineas = [];

  bool _guardando = false;
  String? _error;
  String? _errorContraparte;
  String? _errorAlmacen;
  String? _errorLineas;

  bool get _esRecibido => _tipo == TipoPrestamo.recibido;

  @override
  void dispose() {
    _contraparte.dispose();
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorContraparte = _contraparte.text.trim().isEmpty ? 'Ingresa a quién.' : null;
      _errorAlmacen = _almacenId == null ? 'Elige el almacén.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorContraparte == null && _errorAlmacen == null && _errorLineas == null;
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
      'tipo': _tipo,
      'contraparte': _contraparte.text.trim(),
      'almacenId': _almacenId,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'detalle': [for (final f in _lineas) f.aCuerpo()],
    };

    try {
      await ref.read(prestamosProvider.notifier).crear(cuerpo);
      navegador.pop();
      mensajero.showSnackBar(const SnackBar(content: Text('Préstamo registrado')));
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
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

    final presentaciones = producto.presentaciones.where((p) => p.esCompra).toList();
    final cantidadCtrl = TextEditingController();
    int? presentacionId = presentaciones.length == 1 ? presentaciones.first.id : null;
    Presentacion? presentacionInicial;
    for (final p in presentaciones) {
      if (p.id == presentacionId) presentacionInicial = p;
    }
    final costoCtrl = TextEditingController(
      text: _esRecibido && producto.costoReferencia != null && presentacionInicial != null
          ? formatoNumero(producto.costoReferencia! * presentacionInicial.factor)
          : '',
    );
    String? errorCantidad;

    final fila = await showModalBottomSheet<_FilaLineaPrestamo>(
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
              setSheetState(() {
                errorCantidad = cantidad == null || cantidad <= 0 ? 'Debe ser mayor que cero.' : null;
              });
              if (errorCantidad != null) return;

              final costo = double.tryParse(costoCtrl.text.trim().replaceAll(',', '.'));
              Presentacion? presentacion;
              for (final p in presentaciones) {
                if (p.id == presentacionId) presentacion = p;
              }
              Navigator.of(context).pop(
                _FilaLineaPrestamo(
                  productoId: producto.id,
                  producto: producto.nombre,
                  presentacionId: presentacionId,
                  presentacion: presentacion?.nombre ?? producto.unidadBase,
                  cantidad: cantidad!,
                  costoPresentacion: _esRecibido ? costo : null,
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
                  if (_esRecibido) ...[
                    const SizedBox(height: Dimen.espacio4),
                    AppCampo(
                      controlador: costoCtrl,
                      etiqueta: 'Costo de la presentación',
                      pista: 'En blanco usa el costo de referencia del producto',
                      icono: Icons.payments_outlined,
                      opcional: true,
                      tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                  const SizedBox(height: Dimen.espacio4),
                  AppBoton(texto: 'Agregar', onPressed: guardar),
                ],
              ),
            );
          },
        );
      },
    );
    if (fila != null) setState(() => _lineas.add(fila));
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo préstamo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Dimen.espacio4),
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio4),
          ],

          AppSelector<String>(
            valor: _tipo,
            etiqueta: 'Tipo',
            icono: Icons.handshake_outlined,
            opciones: const [
              Opcion(TipoPrestamo.dado, 'Dado (sale mercadería propia)'),
              Opcion(TipoPrestamo.recibido, 'Recibido (entra de un tercero)'),
            ],
            onCambio: (v) => setState(() => _tipo = v ?? TipoPrestamo.dado),
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _contraparte,
            etiqueta: 'Contraparte',
            pista: 'A quién, o de quién',
            icono: Icons.person_outline,
            error: _errorContraparte,
            habilitado: !_guardando,
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

          AppCampo(
            controlador: _observacion,
            etiqueta: 'Observación',
            icono: Icons.notes_outlined,
            opcional: true,
            maxLargo: 250,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio5),

          const Text(
            'Productos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
          ),
          if (_errorLineas != null) ...[
            const SizedBox(height: Dimen.espacio1),
            Text(_errorLineas!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
          ],
          const SizedBox(height: Dimen.espacio3),

          for (final fila in _lineas) ...[
            Container(
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
                          '${formatoNumero(fila.cantidad)} ${fila.presentacion}',
                          style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _lineas.remove(fila)),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
                  ),
                ],
              ),
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

          AppBoton(texto: 'Registrar préstamo', cargando: _guardando, onPressed: _guardar),
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
