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
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/prestamo.dart';
import '../estado/inventario_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

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
  final List<LineaDocumento> _lineas = [];

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
      _errorContraparte = _contraparte.text.trim().isEmpty
          ? 'Ingresa a quién.'
          : null;
      _errorAlmacen = _almacenId == null ? 'Elige el almacén.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorContraparte == null &&
        _errorAlmacen == null &&
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
      'tipo': _tipo,
      'contraparte': _contraparte.text.trim(),
      'almacenId': _almacenId,
      'observacion': _observacion.text.trim().isEmpty
          ? null
          : _observacion.text.trim(),
      'detalle': [
        for (final f in _lineas)
          {
            'productoId': f.productoId,
            // 0 es la unidad base, que no es ninguna presentacion concreta.
            'presentacionId': f.presentacionId == 0 ? null : f.presentacionId,
            'cantidad': f.cantidad,
            'costoPresentacion': _esRecibido ? f.importe : null,
          },
      ],
    };

    try {
      await ref.read(prestamosProvider.notifier).crear(cuerpo);
      navegador.pop();
      mensajero.mostrar('Préstamo registrado');
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
            'Nuevo préstamo',
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
              opciones: [
                for (final a in almacenes) Opcion<int>(a.id, a.nombre),
              ],
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
              // Lo prestado que ENTRA hay que valorizarlo: no tiene capa
              // de la que sacar el costo. Lo que sale, si.
              mostrarImporte: _esRecibido,
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
