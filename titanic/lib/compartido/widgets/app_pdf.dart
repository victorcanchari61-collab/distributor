import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/red/cliente_api.dart';
import '../../core/red/excepciones.dart';
import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Los documentos que se pueden imprimir, con la ruta que los sirve.
enum DocumentoPdf {
  pedido('pedido', 'Pedido'),
  notaVenta('notaventa', 'Nota de venta'),
  ordenCompra('ordencompra', 'Orden de compra'),
  compra('compra', 'Compra'),

  // Los de inventario cuelgan de /inventario: comparten tabla y numeracion de
  // id, asi que cada tipo necesita su ruta para que el backend sepa que
  // permiso exigir antes de leer el documento.
  ajuste('inventario/ajustes', 'Ajuste'),
  transferencia('inventario/transferencias', 'Transferencia'),
  recepcion('inventario/recepciones', 'Recepción'),
  prestamo('inventario/prestamos', 'Préstamo');

  const DocumentoPdf(this.ruta, this.nombre);

  final String ruta;
  final String nombre;
}

/// Pregunta el formato y abre el PDF en el visor del telefono.
///
/// El archivo se guarda en la carpeta temporal y se abre con el visor del
/// sistema: desde ahi el telefono ya ofrece imprimir y compartir por WhatsApp,
/// que es como de verdad le llega el documento al cliente. Escribir un visor
/// propio seria rehacer algo que el telefono ya hace mejor.
///
/// Los dos formatos estan porque los dos se usan: la hoja A4 para archivar y
/// mandar al proveedor, y el ticket de 80 mm para el rollo de la camioneta.
Future<void> mostrarOpcionesPdf(
  BuildContext context, {
  required DocumentoPdf documento,
  required int id,
  required String numero,
  ClienteApi? api,
}) {
  final acento = Acento.de(context);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (hoja) => _HojaPdf(
      documento: documento,
      id: id,
      numero: numero,
      acento: acento,
      api: api ?? ClienteApi(),
    ),
  );
}

class _HojaPdf extends StatefulWidget {
  const _HojaPdf({
    required this.documento,
    required this.id,
    required this.numero,
    required this.acento,
    required this.api,
  });

  final DocumentoPdf documento;
  final int id;
  final String numero;
  final Color acento;
  final ClienteApi api;

  @override
  State<_HojaPdf> createState() => _HojaPdfState();
}

class _HojaPdfState extends State<_HojaPdf> {
  String? _bajando;
  String? _error;

  Future<void> _bajar(String formato) async {
    setState(() {
      _bajando = formato;
      _error = null;
    });

    try {
      final query = formato == 'ticket' ? '?formato=ticket' : '';
      final bytes = await widget.api.archivo(
        '/${widget.documento.ruta}/${widget.id}/pdf$query',
      );

      // El nombre lleva el numero del documento: en la carpeta del telefono
      // van a convivir muchos, y "documento.pdf" no se distingue de otro.
      final limpio = widget.numero.replaceAll(RegExp(r'[^A-Za-z0-9]'), '-');
      final sufijo = formato == 'ticket' ? '-ticket' : '';
      final carpeta = await getTemporaryDirectory();
      final tipo = widget.documento.ruta.split('/').last;
      final archivo = File('${carpeta.path}/$tipo-$limpio$sufijo.pdf');
      await archivo.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context).pop();
      await OpenFilex.open(archivo.path);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos abrir el PDF.');
    } finally {
      if (mounted) setState(() => _bajando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        Dimen.espacio5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imprimir ${widget.numero}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Elige el papel en el que se va a imprimir.',
            style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),

          if (_error != null) ...[
            const SizedBox(height: Dimen.espacio3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Dimen.espacio3),
              decoration: BoxDecoration(
                color: Colores.peligro.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: Colores.peligro),
              ),
            ),
          ],

          const SizedBox(height: Dimen.espacio4),
          _Opcion(
            icono: Icons.print_outlined,
            titulo: 'Hoja A4',
            nota: 'Impresora de oficina. Lleva el detalle completo y espacio '
                'para firmar.',
            acento: widget.acento,
            cargando: _bajando == 'a4',
            onTap: _bajando == null ? () => _bajar('a4') : null,
          ),
          const SizedBox(height: Dimen.espacio3),
          _Opcion(
            icono: Icons.receipt_long_outlined,
            titulo: 'Ticket 80 mm',
            nota: 'Rollo termico del reparto. Mas corto, pensado para entregar '
                'en mano.',
            acento: widget.acento,
            cargando: _bajando == 'ticket',
            onTap: _bajando == null ? () => _bajar('ticket') : null,
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.nota,
    required this.acento,
    required this.cargando,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String nota;
  final Color acento;
  final bool cargando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        padding: const EdgeInsets.all(Dimen.espacio3),
        decoration: BoxDecoration(
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: cargando
                  ? CircularProgressIndicator(strokeWidth: 2, color: acento)
                  : Icon(icono, size: 22, color: acento),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nota,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
