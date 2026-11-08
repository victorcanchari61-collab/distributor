import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/comprobante.dart';
import '../estado/comprobantes_controlador.dart';
import '../../ventas/estado/ventas_controlador.dart';

/// Nota de crédito o débito sobre un comprobante aceptado. La de crédito arranca con las líneas del comprobante
/// (anulación o devolución total) y se puede editar para corregir solo una parte; la de débito pide el cargo.
///
/// [tiposPermitidos] son las notas que el usuario puede emitir (tiene permiso de crear en su submódulo).
Future<void> abrirEmitirNota(
  BuildContext context,
  Comprobante comprobante,
  List<String> tiposPermitidos,
) => abrirHoja<void>(
  context,
  (_) => EmitirNotaHoja(
    comprobante: comprobante,
    tiposPermitidos: tiposPermitidos,
  ),
);

class _Linea {
  _Linea({String descripcion = '', String cantidad = '1', String precio = ''})
    : descripcion = TextEditingController(text: descripcion),
      cantidad = TextEditingController(text: cantidad),
      precio = TextEditingController(text: precio);

  factory _Linea.de(LineaComprobante l) => _Linea(
    descripcion: l.descripcion,
    cantidad: _num(l.cantidad),
    precio: _num(l.precio),
  ).._afecto = l.afectoIgv;

  final TextEditingController descripcion;
  final TextEditingController cantidad;
  final TextEditingController precio;
  bool _afecto = true;

  double get _cant => double.tryParse(cantidad.text.trim()) ?? 0;
  double get _prec => double.tryParse(precio.text.trim()) ?? 0;
  double get importe => _cant * _prec;
  bool get llena => descripcion.text.trim().isNotEmpty || _prec > 0;

  Map<String, dynamic> aCuerpo() => {
    'descripcion': descripcion.text.trim(),
    'cantidad': _cant,
    'precio': _prec,
    'afectoIgv': _afecto,
  };

  void liberar() {
    descripcion.dispose();
    cantidad.dispose();
    precio.dispose();
  }
}

String _num(double v) =>
    v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();

class EmitirNotaHoja extends ConsumerStatefulWidget {
  const EmitirNotaHoja({
    super.key,
    required this.comprobante,
    required this.tiposPermitidos,
  });

  final Comprobante comprobante;
  final List<String> tiposPermitidos;

  @override
  ConsumerState<EmitirNotaHoja> createState() => _EmitirNotaHojaState();
}

class _EmitirNotaHojaState extends ConsumerState<EmitirNotaHoja> {
  late String _tipo = widget.tiposPermitidos.first;
  late String _motivo = MotivosNota.de(_tipo).first.codigo;
  final _desMotivo = TextEditingController();
  late List<_Linea> _lineas = _lineasIniciales(_tipo);

  bool _emitiendo = false;
  String? _error;

  List<_Linea> _lineasIniciales(String tipo) => tipo == TipoCpe.notaCredito
      ? [for (final l in widget.comprobante.lineas) _Linea.de(l)]
      : [_Linea()];

  double get _total => _lineas.fold<double>(0, (n, l) => n + l.importe);

  @override
  void dispose() {
    _desMotivo.dispose();
    for (final l in _lineas) {
      l.liberar();
    }
    super.dispose();
  }

  void _cambiarTipo(String tipo) {
    for (final l in _lineas) {
      l.liberar();
    }
    setState(() {
      _tipo = tipo;
      _motivo = MotivosNota.de(tipo).first.codigo;
      _lineas = _lineasIniciales(tipo);
    });
  }

  Future<void> _emitir() async {
    FocusScope.of(context).unfocus();
    if (_desMotivo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el motivo de la nota.');
      return;
    }
    final validas = _lineas.where((l) => l.llena).toList();
    if (validas.isEmpty) {
      setState(() => _error = 'Agrega al menos una línea.');
      return;
    }
    if (validas.any(
      (l) => l.descripcion.text.trim().isEmpty || l._cant <= 0 || l._prec <= 0,
    )) {
      setState(
        () => _error =
            'Cada línea necesita descripción, cantidad y precio mayores que cero.',
      );
      return;
    }

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);
    final afectado = widget.comprobante;

    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final nota = await ref
          .read(comprobantesApiProvider)
          .emitirNota(
            afectado.id,
            tipo: _tipo,
            codMotivo: _motivo,
            desMotivo: _desMotivo.text.trim(),
            lineas: [for (final l in validas) l.aCuerpo()],
          );
      // Cambian la lista de la nota nueva y la del comprobante corregido (sus notas).
      ref.invalidate(comprobantesProvider(nota.tipo));
      ref.invalidate(comprobantesProvider(afectado.tipo));
      // Una nota que cubre todo lo facturado anula la venta: su lista se pone al día.
      ref.invalidate(notasVentaProvider);

      navegador.pop();
      if (nota.aceptado) {
        mensajero.mostrar('${nota.numeroCompleto} aceptada por SUNAT');
      } else {
        mensajero.error(
          '${nota.numeroCompleto}: ${nota.mensajeSunat ?? EstadoCpe.etiqueta(nota.estado)}',
        );
      }
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _emitiendo = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comprobante;
    // Anulación (01) o devolución total (06): si SUNAT la acepta y cubre todo, la venta se anula y el stock vuelve.
    final aviso =
        _tipo == TipoCpe.notaCredito && (_motivo == '01' || _motivo == '06')
        ? c.avisoNotaTotal
        : null;

    return HojaBase(
      titulo: 'Nota sobre ${c.numeroCompleto}',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          if (widget.tiposPermitidos.length > 1) ...[
            AppSelector<String>(
              valor: _tipo,
              etiqueta: 'Tipo de nota',
              icono: Icons.description_outlined,
              opciones: [
                for (final t in widget.tiposPermitidos)
                  Opcion<String>(
                    t,
                    t == TipoCpe.notaCredito
                        ? 'Nota de crédito (devuelve o descuenta)'
                        : 'Nota de débito (cobra de más)',
                  ),
              ],
              onCambio: (v) {
                if (v != null && v != _tipo) _cambiarTipo(v);
              },
            ),
            const SizedBox(height: Dimen.espacio4),
          ],
          AppSelector<String>(
            valor: _motivo,
            etiqueta: 'Motivo (SUNAT)',
            icono: Icons.rule_outlined,
            opciones: [
              for (final m in MotivosNota.de(_tipo))
                Opcion<String>(m.codigo, '${m.codigo} · ${m.etiqueta}'),
            ],
            onCambio: (v) => setState(() => _motivo = v ?? _motivo),
          ),
          if (aviso != null) ...[
            const SizedBox(height: Dimen.espacio3),
            AppAlerta(aviso, tono: AlertaTono.aviso),
          ],
          const SizedBox(height: Dimen.espacio4),
          AppCampo(
            controlador: _desMotivo,
            etiqueta: 'Detalle del motivo',
            icono: Icons.edit_note,
            pista: 'Explica por qué se emite la nota',
            maxLargo: 250,
          ),
          const SizedBox(height: Dimen.espacio4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Líneas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              AppBoton(
                texto: 'Agregar línea',
                variante: BotonVariante.secundario,
                expandido: false,
                onPressed: () => setState(() => _lineas.add(_Linea())),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),
          for (var i = 0; i < _lineas.length; i++) _tarjetaLinea(i),
          const SizedBox(height: Dimen.espacio2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total de la nota: S/ ${_total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      pie: AppBotonesFormulario(
        textoGuardar: 'Emitir nota',
        cargando: _emitiendo,
        onCancelar: () => Navigator.of(context).pop(),
        onGuardar: _emitir,
      ),
    );
  }

  Widget _tarjetaLinea(int i) {
    final l = _lineas[i];
    return Container(
      margin: const EdgeInsets.only(bottom: Dimen.espacio3),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        children: [
          AppCampo(
            controlador: l.descripcion,
            etiqueta: 'Descripción',
            maxLargo: 200,
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: l.cantidad,
                  etiqueta: 'Cantidad',
                  tipoTeclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  formateadores: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: l.precio,
                  etiqueta: 'Precio',
                  pista: '0.00',
                  tipoTeclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  formateadores: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
            ],
          ),
          if (_lineas.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _lineas.removeAt(i).liberar();
                }),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
                style: TextButton.styleFrom(foregroundColor: Colores.peligro),
              ),
            ),
        ],
      ),
    );
  }
}
