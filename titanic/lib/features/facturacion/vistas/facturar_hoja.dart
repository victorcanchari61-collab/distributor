import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../ventas/datos/nota_venta.dart';
import '../../ventas/estado/ventas_controlador.dart';
import '../datos/comprobante.dart';
import '../estado/comprobantes_controlador.dart';

/// "Facturar": emite la factura o la boleta de una nota de venta que ya existe. La firma, la manda a SUNAT y muestra lo
/// que respondió.
Future<void> abrirFacturar(BuildContext context, NotaVenta nota) =>
    abrirHoja<void>(context, (_) => FacturarHoja(nota: nota));

class FacturarHoja extends ConsumerStatefulWidget {
  const FacturarHoja({super.key, required this.nota});

  final NotaVenta nota;

  @override
  ConsumerState<FacturarHoja> createState() => _FacturarHojaState();
}

class _FacturarHojaState extends ConsumerState<FacturarHoja> {
  late String _tipo = puede(ref, 'fact.boletas', Accion.crear)
      ? TipoCpe.boleta
      : TipoCpe.factura;
  bool _emitiendo = false;
  String? _error;

  Future<void> _emitir() async {
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final c = await ref
          .read(comprobantesApiProvider)
          .emitir(widget.nota.id, _tipo);
      ref.invalidate(comprobantesProvider(_tipo));
      await ref.read(notasVentaProvider.notifier).recargar();

      navegador.pop();
      if (c.aceptado) {
        mensajero.mostrar('${c.numeroCompleto} aceptado por SUNAT');
      } else {
        mensajero.error(
          '${c.numeroCompleto}: ${c.mensajeSunat ?? EstadoCpe.etiqueta(c.estado)}',
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
    final nota = widget.nota;

    return HojaBase(
      titulo: 'Facturar ${nota.numero}',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          Container(
            padding: const EdgeInsets.all(Dimen.espacio3),
            decoration: BoxDecoration(
              color: Colores.fondo,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nota.cliente,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${nota.numero} · S/ ${nota.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.espacio4),
          AppSelector<String>(
            valor: _tipo,
            etiqueta: 'Comprobante',
            icono: Icons.receipt_long_outlined,
            opciones: [
              if (puede(ref, 'fact.boletas', Accion.crear))
                const Opcion<String>(TipoCpe.boleta, 'Boleta electrónica'),
              if (puede(ref, 'fact.facturas', Accion.crear))
                const Opcion<String>(TipoCpe.factura, 'Factura electrónica'),
            ],
            onCambio: (v) => setState(() => _tipo = v ?? _tipo),
          ),
          const SizedBox(height: Dimen.espacio2),
          Text(
            _tipo == TipoCpe.factura
                ? 'La factura pide que el cliente tenga RUC. Se firma y se envía a SUNAT en el momento.'
                : 'La boleta acepta DNI o RUC; desde S/ 700 exige el documento del cliente. Se firma y se envía a SUNAT en el momento.',
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
        ],
      ),
      pie: AppBotonesFormulario(
        textoGuardar: 'Emitir',
        cargando: _emitiendo,
        onCancelar: () => Navigator.of(context).pop(),
        onGuardar: _emitir,
      ),
    );
  }
}
