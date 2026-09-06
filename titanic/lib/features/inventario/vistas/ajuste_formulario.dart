import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_buscable.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';

class _FilaLineaAjuste {
  _FilaLineaAjuste({
    required this.productoId,
    required this.producto,
    this.presentacionId,
    required this.presentacion,
    required this.cantidad,
    this.costoPresentacion,
    this.lote,
    this.vencimiento,
  });

  final int productoId;
  final String producto;
  final int? presentacionId;
  final String presentacion;
  double cantidad;
  double? costoPresentacion;
  String? lote;
  DateTime? vencimiento;

  Map<String, dynamic> aCuerpo() => {
    'productoId': productoId,
    'presentacionId': presentacionId,
    'cantidad': cantidad,
    'costoPresentacion': costoPresentacion,
    'lote': lote,
    'fechaVencimiento': vencimiento?.toIso8601String(),
  };
}

/// Alta de un ajuste de inventario: entra o sale mercaderia fuera del flujo
/// normal de compras y ventas, con un motivo declarado.
class AjusteFormulario extends ConsumerStatefulWidget {
  const AjusteFormulario({super.key});

  @override
  ConsumerState<AjusteFormulario> createState() => _AjusteFormularioState();
}

class _AjusteFormularioState extends ConsumerState<AjusteFormulario> {
  final _observacion = TextEditingController();
  final _flete = TextEditingController();

  int? _almacenId;
  int? _motivoId;
  final List<_FilaLineaAjuste> _lineas = [];

  bool _guardando = false;
  String? _error;
  String? _errorAlmacen;
  String? _errorMotivo;
  String? _errorLineas;

  Motivo? get _motivo {
    final motivos = ref.read(motivosDisponiblesProvider);
    for (final m in motivos) {
      if (m.id == _motivoId) return m;
    }
    return null;
  }

  @override
  void dispose() {
    _observacion.dispose();
    _flete.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorAlmacen = _almacenId == null ? 'Elige el almacén.' : null;
      _errorMotivo = _motivoId == null ? 'Elige el motivo.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorAlmacen == null && _errorMotivo == null && _errorLineas == null;
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
    final flete = double.tryParse(_flete.text.trim().replaceAll(',', '.')) ?? 0;

    final cuerpo = <String, dynamic>{
      'almacenId': _almacenId,
      'motivoId': _motivoId,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'flete': flete,
      'detalle': [for (final f in _lineas) f.aCuerpo()],
    };

    try {
      await ref.read(ajustesProvider.notifier).crear(cuerpo);
      navegador.pop();
      mensajero.showSnackBar(const SnackBar(content: Text('Ajuste registrado')));
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

    final fila = await _mostrarHojaLinea(producto);
    if (fila != null) setState(() => _lineas.add(fila));
  }

  Future<_FilaLineaAjuste?> _mostrarHojaLinea(Producto producto) {
    final pideCosto = _motivo?.pideCosto ?? false;
    final presentaciones = producto.presentaciones.where((p) => p.esCompra).toList();
    final cantidadCtrl = TextEditingController();
    final costoCtrl = TextEditingController();
    final loteCtrl = TextEditingController();
    int? presentacionId = presentaciones.length == 1 ? presentaciones.first.id : null;
    DateTime? vencimiento;
    String? errorCantidad;
    String? errorCosto;

    return showModalBottomSheet<_FilaLineaAjuste>(
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
                errorCantidad = cantidad == null || cantidad <= 0
                    ? 'Debe ser mayor que cero.'
                    : null;
                errorCosto = pideCosto && (costo == null || costo <= 0)
                    ? 'Debe ser mayor que cero.'
                    : null;
              });
              if (errorCantidad != null || errorCosto != null) return;

              Presentacion? presentacion;
              for (final p in presentaciones) {
                if (p.id == presentacionId) presentacion = p;
              }
              Navigator.of(context).pop(
                _FilaLineaAjuste(
                  productoId: producto.id,
                  producto: producto.nombre,
                  presentacionId: presentacionId,
                  presentacion: presentacion?.nombre ?? producto.unidadBase,
                  cantidad: cantidad!,
                  costoPresentacion: pideCosto ? costo : null,
                  lote: pideCosto && loteCtrl.text.trim().isNotEmpty ? loteCtrl.text.trim() : null,
                  vencimiento: pideCosto ? vencimiento : null,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colores.tinta,
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  if (presentaciones.isNotEmpty) ...[
                    AppSelector<int>(
                      valor: presentacionId,
                      etiqueta: 'Presentación',
                      icono: Icons.inventory_2_outlined,
                      opciones: [
                        for (final p in presentaciones)
                          Opcion(
                            p.id,
                            '${p.nombre} (${formatoNumero(p.factor)} ${producto.unidadBase})',
                          ),
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
                  if (pideCosto) ...[
                    const SizedBox(height: Dimen.espacio4),
                    AppCampo(
                      controlador: costoCtrl,
                      etiqueta: 'Costo de la presentación',
                      icono: Icons.payments_outlined,
                      tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                      error: errorCosto,
                    ),
                    const SizedBox(height: Dimen.espacio4),
                    AppCampo(controlador: loteCtrl, etiqueta: 'Lote', opcional: true),
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
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);
    final motivos = ref.watch(motivosDisponiblesProvider);
    final pideCosto = _motivo?.pideCosto ?? false;

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'inv',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Nuevo ajuste',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            AppSelector<int>(
              valor: _almacenId,
              etiqueta: 'Almacén',
              icono: Icons.warehouse_outlined,
              error: _errorAlmacen,
              opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
              onCambio: (v) => setState(() => _almacenId = v),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: _motivoId,
              etiqueta: 'Motivo',
              icono: Icons.fact_check_outlined,
              error: _errorMotivo,
              opciones: [
                for (final m in motivos)
                  Opcion<int>(m.id, '${m.nombre} (${m.esEntrada ? 'Entrada' : 'Salida'})'),
              ],
              onCambio: (v) => setState(() => _motivoId = v),
            ),
            if (motivos.isEmpty) ...[
              const SizedBox(height: Dimen.espacio1),
              const Text(
                'No hay motivos manuales. Créalos en la pestaña Motivos.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ],
            const SizedBox(height: Dimen.espacio4),

            if (pideCosto) ...[
              AppCampo(
                controlador: _flete,
                etiqueta: 'Flete',
                pista: 'Gastos de la entrada, repartidos entre las líneas',
                icono: Icons.local_shipping_outlined,
                opcional: true,
                tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                habilitado: !_guardando,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colores.tinta,
                            ),
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
              onPressed: _motivoId == null || _guardando ? null : _agregarLinea,
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(texto: 'Registrar ajuste', cargando: _guardando, onPressed: _guardar),
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
