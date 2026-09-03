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
import '../estado/inventario_controlador.dart';

class _FilaLineaTransferencia {
  _FilaLineaTransferencia({
    required this.productoId,
    required this.producto,
    this.presentacionId,
    required this.presentacion,
    required this.cantidad,
  });

  final int productoId;
  final String producto;
  final int? presentacionId;
  final String presentacion;
  final double cantidad;

  Map<String, dynamic> aCuerpo() => {
    'productoId': productoId,
    'presentacionId': presentacionId,
    'cantidad': cantidad,
  };
}

/// Mueve mercaderia entre dos almacenes propios. Sin costo: viaja con la
/// mercaderia, al costo que ya tenia en el almacen de origen.
class TransferenciaFormulario extends ConsumerStatefulWidget {
  const TransferenciaFormulario({super.key});

  @override
  ConsumerState<TransferenciaFormulario> createState() => _TransferenciaFormularioState();
}

class _TransferenciaFormularioState extends ConsumerState<TransferenciaFormulario> {
  final _observacion = TextEditingController();

  int? _origenId;
  int? _destinoId;
  final List<_FilaLineaTransferencia> _lineas = [];

  bool _guardando = false;
  String? _error;
  String? _errorOrigen;
  String? _errorDestino;
  String? _errorLineas;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorOrigen = _origenId == null ? 'Elige el almacén de origen.' : null;
      _errorDestino = _destinoId == null
          ? 'Elige el almacén de destino.'
          : (_destinoId == _origenId ? 'Debe ser distinto del de origen.' : null);
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorOrigen == null && _errorDestino == null && _errorLineas == null;
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
      'almacenOrigenId': _origenId,
      'almacenDestinoId': _destinoId,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'detalle': [for (final f in _lineas) f.aCuerpo()],
    };

    try {
      await ref.read(transferenciasProvider.notifier).crear(cuerpo);
      navegador.pop();
      mensajero.showSnackBar(const SnackBar(content: Text('Transferencia registrada')));
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
    String? errorCantidad;

    final fila = await showModalBottomSheet<_FilaLineaTransferencia>(
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

              Presentacion? presentacion;
              for (final p in presentaciones) {
                if (p.id == presentacionId) presentacion = p;
              }
              Navigator.of(context).pop(
                _FilaLineaTransferencia(
                  productoId: producto.id,
                  producto: producto.nombre,
                  presentacionId: presentacionId,
                  presentacion: presentacion?.nombre ?? producto.unidadBase,
                  cantidad: cantidad!,
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
        title: const Text('Nueva transferencia', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Dimen.espacio4),
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio4),
          ],

          AppSelector<int>(
            valor: _origenId,
            etiqueta: 'Almacén de origen',
            icono: Icons.warehouse_outlined,
            error: _errorOrigen,
            opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
            onCambio: (v) => setState(() => _origenId = v),
          ),
          const SizedBox(height: Dimen.espacio4),

          AppSelector<int>(
            valor: _destinoId,
            etiqueta: 'Almacén de destino',
            icono: Icons.warehouse_outlined,
            error: _errorDestino,
            opciones: [
              for (final a in almacenes)
                if (a.id != _origenId) Opcion<int>(a.id, a.nombre),
            ],
            onCambio: (v) => setState(() => _destinoId = v),
          ),
          if (almacenes.length < 2) ...[
            const SizedBox(height: Dimen.espacio1),
            const Text(
              'Necesitas al menos dos almacenes activos para transferir.',
              style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
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
            onPressed: (_origenId == null || _guardando) ? null : _agregarLinea,
          ),
          const SizedBox(height: Dimen.espacio6),

          AppBoton(texto: 'Registrar transferencia', cargando: _guardando, onPressed: _guardar),
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
