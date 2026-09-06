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
import '../../inventario/estado/inventario_controlador.dart';
import '../datos/compra.dart';
import '../estado/compras_controlador.dart';

class _FilaRecepcion {
  _FilaRecepcion({required this.detalle})
    : cantidadCtrl = TextEditingController(text: formatoNumero(detalle.cantidadPendiente)),
      loteCtrl = TextEditingController();

  final CompraDetalle detalle;
  final TextEditingController cantidadCtrl;
  final TextEditingController loteCtrl;
  DateTime? vencimiento;

  double get cantidad => double.tryParse(cantidadCtrl.text.trim().replaceAll(',', '.')) ?? 0;
}

/// Registra que llego mercaderia de una compra, total o parcialmente.
class RecepcionFormulario extends ConsumerStatefulWidget {
  const RecepcionFormulario({super.key, this.compraFija});

  /// Si viene de "Recibir" en Mis compras, la compra ya esta elegida.
  final Compra? compraFija;

  @override
  ConsumerState<RecepcionFormulario> createState() => _RecepcionFormularioState();
}

class _RecepcionFormularioState extends ConsumerState<RecepcionFormulario> {
  final _observacion = TextEditingController();

  late Compra? _compra = widget.compraFija;
  int? _almacenId;
  late List<_FilaRecepcion> _filas = _construirFilas(widget.compraFija);

  bool _guardando = false;
  String? _error;
  String? _errorCompra;
  String? _errorAlmacen;

  @override
  void dispose() {
    _observacion.dispose();
    for (final f in _filas) {
      f.cantidadCtrl.dispose();
      f.loteCtrl.dispose();
    }
    super.dispose();
  }

  List<_FilaRecepcion> _construirFilas(Compra? compra) {
    if (compra == null) return [];
    return [
      for (final d in compra.detalle)
        if (d.cantidadPendiente > 0) _FilaRecepcion(detalle: d),
    ];
  }

  Future<void> _elegirCompra() async {
    final compras = ref.read(comprasConPendienteProvider);
    final elegida = await mostrarSelectorBuscable<Compra>(
      context: context,
      titulo: 'Elige la compra',
      items: compras,
      buscable: (c) => c.buscable,
      pistaBusqueda: 'Buscar por número o proveedor',
      fila: (c) => Text(
        '${c.numero} · ${c.proveedor}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
    if (elegida != null) {
      setState(() {
        _compra = elegida;
        _filas = _construirFilas(elegida);
      });
    }
  }

  Future<void> _elegirVencimiento(_FilaRecepcion fila) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: fila.vencimiento ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (elegida != null) setState(() => fila.vencimiento = elegida);
  }

  bool _validar() {
    setState(() {
      _errorCompra = _compra == null ? 'Elige la compra.' : null;
      _errorAlmacen = _almacenId == null ? 'Elige el almacén.' : null;
    });
    return _errorCompra == null && _errorAlmacen == null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    final lineas = _filas.where((f) => f.cantidad > 0).toList();
    if (lineas.isEmpty) {
      setState(() => _error = 'Ingresa cuánto llegó de al menos un producto.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    final cuerpo = <String, dynamic>{
      'compraId': _compra!.id,
      'almacenId': _almacenId,
      'observacion': _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
      'detalle': [
        for (final f in lineas)
          {
            'compraDetalleId': f.detalle.id,
            'cantidad': f.cantidad,
            'lote': f.loteCtrl.text.trim().isEmpty ? null : f.loteCtrl.text.trim(),
            'fechaVencimiento': f.vencimiento?.toIso8601String(),
          },
      ],
    };

    try {
      await ref.read(recepcionesProvider.notifier).crear(cuerpo);

      navegador.pop();
      mensajero.showSnackBar(const SnackBar(content: Text('Recepción registrada')));
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'compras',
      Scaffold(
        appBar: AppBar(
          title: const Text(
            'Nueva recepción',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            if (widget.compraFija == null)
              InkWell(
                onTap: _elegirCompra,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Compra',
                    errorText: _errorCompra,
                    prefixIcon: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 19,
                      color: Colores.tintaTenue,
                    ),
                    suffixIcon: const Icon(Icons.search, size: 18, color: Colores.tintaTenue),
                    constraints: const BoxConstraints(minHeight: Dimen.campoLg),
                  ),
                  child: Text(
                    _compra == null
                        ? 'Toca para elegir'
                        : '${_compra!.numero} · ${_compra!.proveedor}',
                    style: TextStyle(
                      fontSize: 15,
                      color: _compra == null ? Colores.tintaTenue : Colores.tinta,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(Dimen.espacio3),
                decoration: BoxDecoration(
                  color: Colores.fondo,
                  borderRadius: BorderRadius.circular(Dimen.radioCampo),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 18, color: Colores.tintaSuave),
                    const SizedBox(width: Dimen.espacio2),
                    Text(
                      '${_compra!.numero} · ${_compra!.proveedor}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colores.tinta,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: _almacenId,
              etiqueta: 'Almacén destino',
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

            if (_compra != null) ...[
              const Text(
                'Productos pendientes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
              ),
              const SizedBox(height: Dimen.espacio3),

              if (_filas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
                  child: Text(
                    'Esta compra ya no tiene nada pendiente por recibir.',
                    style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
                  ),
                ),

              for (final fila in _filas) ...[
                _TarjetaFilaRecepcion(fila: fila, onVencimiento: () => _elegirVencimiento(fila)),
                const SizedBox(height: Dimen.espacio3),
              ],
            ],

            const SizedBox(height: Dimen.espacio4),
            AppBoton(texto: 'Registrar recepción', cargando: _guardando, onPressed: _guardar),
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

class _TarjetaFilaRecepcion extends StatelessWidget {
  const _TarjetaFilaRecepcion({required this.fila, required this.onVencimiento});

  final _FilaRecepcion fila;
  final VoidCallback onVencimiento;

  @override
  Widget build(BuildContext context) {
    final d = fila.detalle;
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.producto,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
          ),
          const SizedBox(height: 2),
          Text(
            'Pendiente: ${formatoNumero(d.cantidadPendiente)} ${d.unidadBase}',
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: fila.cantidadCtrl,
                  etiqueta: 'Llegó (${d.unidadBase})',
                  tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(controlador: fila.loteCtrl, etiqueta: 'Lote', opcional: true),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),
          InkWell(
            onTap: onVencimiento,
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            child: InputDecorator(
              decoration: const InputDecoration(
                label: Text.rich(
                  TextSpan(
                    text: 'Vencimiento',
                    children: [
                      TextSpan(
                        text: ' (opcional)',
                        style: TextStyle(color: Colores.tintaTenue),
                      ),
                    ],
                  ),
                ),
                prefixIcon: Icon(Icons.event_outlined, size: 18, color: Colores.tintaTenue),
                constraints: BoxConstraints(minHeight: Dimen.campoMd),
                contentPadding: EdgeInsets.symmetric(horizontal: Dimen.espacio3),
              ),
              child: Text(
                fila.vencimiento == null ? 'Sin definir' : _fecha(fila.vencimiento!),
                style: TextStyle(
                  fontSize: 13,
                  color: fila.vencimiento == null ? Colores.tintaTenue : Colores.tinta,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
