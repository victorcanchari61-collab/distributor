import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
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
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

/*
 * Una linea del ajuste: la misma que compras y ventas, con dos datos mas.
 *
 * Hereda de LineaDocumento para poder usar el mismo panel de busqueda y las
 * mismas tarjetas editables que el resto del sistema —el usuario no tiene por
 * que aprender dos formas de cargar productos—. Lo unico propio del ajuste es
 * el lote y el vencimiento, y solo cuando la mercaderia entra.
 */
class _LineaAjuste extends LineaDocumento {
  _LineaAjuste({
    required super.productoId,
    required super.producto,
    required super.codigo,
    required super.unidadBase,
    required super.presentaciones,
    required super.presentacionId,
    required super.cantidad,
    required super.importe,
  });

  final lote = TextEditingController();
  DateTime? vencimiento;

  Map<String, dynamic> aCuerpo({required bool pideCosto}) => {
    'productoId': productoId,
    // 0 es la unidad base, que no es ninguna presentacion concreta.
    'presentacionId': presentacionId == 0 ? null : presentacionId,
    'cantidad': cantidad,
    'costoPresentacion': pideCosto ? importe : null,
    'lote': pideCosto && lote.text.trim().isNotEmpty ? lote.text.trim() : null,
    'fechaVencimiento': pideCosto ? vencimiento?.toIso8601String() : null,
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

  // Primero se elige si el ajuste suma o resta; el motivo sale de ese tipo.
  // Por defecto un ingreso, igual que en la web.
  String _tipo = TipoMotivo.entrada;

  // Lo que la persona eligio a mano. Null significa "el primero de la lista
  // del tipo": los motivos llegan del servidor y pueden no estar cargados al
  // abrir el formulario, asi que el valor por defecto se resuelve al leerlo.
  int? _motivoElegido;
  final List<LineaDocumento> _lineas = [];

  bool _guardando = false;
  String? _error;
  String? _errorAlmacen;
  String? _errorMotivo;
  String? _errorLineas;

  /// Los motivos manuales y activos del tipo elegido.
  List<Motivo> get _motivosDelTipo => [
    for (final m in ref.read(motivosDisponiblesProvider))
      if (m.tipo == _tipo) m,
  ];

  Motivo? get _motivo {
    final delTipo = _motivosDelTipo;
    for (final m in delTipo) {
      if (m.id == _motivoElegido) return m;
    }
    // Nada elegido (o lo elegido ya no es de este tipo): el primero.
    return delTipo.isEmpty ? null : delTipo.first;
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
      _errorMotivo = _motivo == null ? 'Elige el motivo.' : null;
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
    final mensajero = Aviso.de(context);
    final flete = double.tryParse(_flete.text.trim().replaceAll(',', '.')) ?? 0;
    final motivo = _motivo;
    final pideCosto = motivo?.pideCosto ?? false;

    final cuerpo = <String, dynamic>{
      'almacenId': _almacenId,
      'motivoId': motivo?.id,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'flete': flete,
      'detalle': [
        for (final f in _lineas.cast<_LineaAjuste>()) f.aCuerpo(pideCosto: pideCosto),
      ],
    };

    try {
      await ref.read(ajustesProvider.notifier).crear(cuerpo);
      navegador.pop();
      mensajero.mostrar('Ajuste registrado');
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
   * Lo ultimo agregado va arriba.
   *
   * Cargando veinte productos, lo que se acaba de poner es lo que hay que
   * mirar —¿le puse bien la cantidad?—, y al final de una lista larga queda
   * fuera de pantalla. Arriba cae justo debajo del buscador, donde ya estan
   * los ojos.
   */
  void _agregarLineas(List<LineaElegida> elegidas) {
    setState(() {
      _lineas.insertAll(0, [
        for (final e in elegidas)
          _LineaAjuste(
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

  /// Lote y vencimiento: solo de lo que entra, y solo si hace falta.
  Widget _loteYVencimiento(LineaDocumento linea) {
    final fila = linea as _LineaAjuste;
    return Row(
      children: [
        Expanded(
          child: AppCampo(
            controlador: fila.lote,
            etiqueta: 'Lote',
            opcional: true,
            habilitado: !_guardando,
          ),
        ),
        const SizedBox(width: Dimen.espacio3),
        Expanded(
          child: InkWell(
            onTap: _guardando
                ? null
                : () async {
                    final hoy = DateTime.now();
                    final elegida = await showDatePicker(
                      context: context,
                      initialDate: fila.vencimiento ?? hoy,
                      firstDate: hoy.subtract(const Duration(days: 365)),
                      lastDate: hoy.add(const Duration(days: 365 * 10)),
                    );
                    if (elegida != null) setState(() => fila.vencimiento = elegida);
                  },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vence',
                constraints: BoxConstraints(minHeight: Dimen.campoLg),
              ),
              child: Text(
                fila.vencimiento == null
                    ? 'Sin fecha'
                    : '${fila.vencimiento!.day.toString().padLeft(2, '0')}/'
                          '${fila.vencimiento!.month.toString().padLeft(2, '0')}/'
                          '${fila.vencimiento!.year}',
                style: TextStyle(
                  fontSize: 14,
                  color: fila.vencimiento == null ? Colores.tintaSuave : Colores.tinta,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);
    // El watch mantiene viva la lista y redibuja cuando llegan los motivos;
    // _motivosDelTipo y _motivo la leen ya filtrada por el tipo elegido.
    ref.watch(motivosDisponiblesProvider);
    final motivosDelTipo = _motivosDelTipo;
    final motivo = _motivo;
    final pideCosto = motivo?.pideCosto ?? false;

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

            AppSelector<String>(
              valor: _tipo,
              etiqueta: 'Tipo',
              icono: Icons.swap_vert_rounded,
              opciones: const [
                Opcion<String>(TipoMotivo.entrada, 'Ingreso (suma stock)'),
                Opcion<String>(TipoMotivo.salida, 'Salida (resta stock)'),
              ],
              onCambio: (v) {
                if (v == null || v == _tipo) return;
                // El motivo elegido puede no existir en el otro tipo: se
                // reinicia y vuelve a ser el primero de la nueva lista.
                setState(() {
                  _tipo = v;
                  _motivoElegido = null;
                  _errorMotivo = null;
                });
              },
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: motivo?.id,
              etiqueta: 'Motivo',
              icono: Icons.fact_check_outlined,
              error: _errorMotivo,
              opciones: [for (final m in motivosDelTipo) Opcion<int>(m.id, m.nombre)],
              onCambio: (v) => setState(() => _motivoElegido = v),
            ),
            if (motivosDelTipo.isEmpty) ...[
              const SizedBox(height: Dimen.espacio1),
              Text(
                'No hay motivos de ${_tipo == TipoMotivo.entrada ? 'ingreso' : 'salida'}. '
                'Créalos en la pestaña Motivos.',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
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

            AppPanelProducto(
              productos: (ref.watch(productosProvider).valueOrNull ?? const <Producto>[])
                  .where((p) => p.activo && p.controlaStock)
                  .toList(),
              cargando: ref.watch(productosProvider).isLoading,
              paraVenta: false,
              habilitado: !_guardando && motivo != null,
              onAgregar: _agregarLineas,
            ),
            if (motivo == null) ...[
              const SizedBox(height: Dimen.espacio2),
              const Text(
                'Elige primero el motivo: de él depende si se pide costo, lote y vencimiento.',
                style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
              ),
            ],
            const SizedBox(height: Dimen.espacio5),

            AppLineasProducto(
              lineas: _lineas,
              error: _errorLineas,
              etiquetaImporte: 'Costo S/',
              habilitado: !_guardando,
              // Una salida no lleva costo: lo pone la capa que se consume.
              mostrarImporte: pideCosto,
              extra: pideCosto ? _loteYVencimiento : null,
              onCambio: () => setState(() {}),
              onEliminar: (l) => setState(() => _lineas.remove(l)),
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
