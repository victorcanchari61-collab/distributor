import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../estado/inventario_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Mueve mercaderia entre dos almacenes propios. Sin costo: viaja con la
/// mercaderia, al costo que ya tenia en el almacen de origen.
class TransferenciaFormulario extends ConsumerStatefulWidget {
  const TransferenciaFormulario({super.key});

  @override
  ConsumerState<TransferenciaFormulario> createState() =>
      _TransferenciaFormularioState();
}

class _TransferenciaFormularioState
    extends ConsumerState<TransferenciaFormulario> {
  final _observacion = TextEditingController();

  int? _origenId;
  int? _destinoId;
  final List<LineaDocumento> _lineas = [];

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
          : (_destinoId == _origenId
                ? 'Debe ser distinto del de origen.'
                : null);
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorOrigen == null &&
        _errorDestino == null &&
        _errorLineas == null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    final cuerpo = <String, dynamic>{
      'almacenOrigenId': _origenId,
      'almacenDestinoId': _destinoId,
      'observacion': _observacion.text.trim().isEmpty
          ? null
          : _observacion.text.trim(),
      'detalle': [
        for (final f in _lineas)
          {
            'productoId': f.productoId,
            'presentacionId': f.presentacionId == 0 ? null : f.presentacionId,
            'cantidad': f.cantidad,
          },
      ],
    };

    try {
      await ref.read(transferenciasProvider.notifier).crear(cuerpo);
      navegador.pop();
      mensajero.mostrar('Transferencia registrada');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  static List<Presentacion> _presentacionesDe(Producto p) =>
      p.presentaciones.where((pr) => pr.activo && pr.esCompra).toList();

  /*
   * Lo ultimo agregado va arriba, igual que en compras y ventas.
   *
   * Lo que se acaba de poner es lo que hay que revisar, y al final de una
   * lista larga queda fuera de pantalla.
   */
  void _agregarLineas(List<LineaElegida> elegidas) {
    setState(() {
      _lineas.insertAll(0, [
        for (final e in elegidas)
          LineaDocumento(
            productoId: e.producto.id,
            producto: e.producto.nombre,
            codigo: e.producto.codigo,
            unidadBase: e.producto.unidadBase,
            presentaciones: _presentacionesDe(e.producto),
            presentacionId: e.presentacionId,
            cantidad: e.cantidad,
            importe: e.importe,
          ),
      ]);
      _errorLineas = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'inv',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Nueva transferencia',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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

            AppSelector<int>(
              valor: _origenId,
              etiqueta: 'Almacén de origen',
              icono: Icons.warehouse_outlined,
              error: _errorOrigen,
              opciones: [
                for (final a in almacenes) Opcion<int>(a.id, a.nombre),
              ],
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

            AppPanelProducto(
              productos:
                  (ref.watch(productosProvider).valueOrNull ??
                          const <Producto>[])
                      .where((p) => p.activo && p.controlaStock)
                      .toList(),
              cargando: ref.watch(productosProvider).isLoading,
              paraVenta: false,
              habilitado: !_guardando,
              onAgregar: _agregarLineas,
            ),
            const SizedBox(height: Dimen.espacio5),

            AppLineasProducto(
              lineas: _lineas,
              error: _errorLineas,
              etiquetaImporte: 'Costo S/',
              habilitado: !_guardando,
              // Mover de almacen no cambia el costo: la capa viaja con la
              // mercaderia, asi que no hay ningun importe que teclear.
              mostrarImporte: false,
              onCambio: () => setState(() {}),
              onEliminar: (l) => setState(() => _lineas.remove(l)),
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBotonesFormulario(
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _guardar,
              cargando: _guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}
