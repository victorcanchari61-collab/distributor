import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/despacho.dart';
import '../estado/despachos_controlador.dart';

/// Filtros del reporte de carga: qué productos hay que subir al camión.
///
/// Se recorta por mercado y por unidad de medida (solo las bolsas, solo un
/// mercado), y se puede separar en un bloque por mercado. Sin marcar nada
/// sale el camión completo — es lo mismo que ofrece el panel web.
Future<void> mostrarReporteCarga(
  BuildContext context, {
  required int despachoId,
  required String numero,
}) {
  final acento = Acento.de(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (hoja) => Acento(
      color: acento,
      child: _HojaReporteCarga(despachoId: despachoId, numero: numero),
    ),
  );
}

class _HojaReporteCarga extends ConsumerStatefulWidget {
  const _HojaReporteCarga({required this.despachoId, required this.numero});

  final int despachoId;
  final String numero;

  @override
  ConsumerState<_HojaReporteCarga> createState() => _HojaReporteCargaState();
}

class _HojaReporteCargaState extends ConsumerState<_HojaReporteCarga> {
  final Set<int> _mercados = {};
  final Set<String> _unidades = {};
  bool _porMercado = false;
  bool _generando = false;
  String? _error;

  Future<void> _generar(OpcionesCarga opciones) async {
    setState(() {
      _generando = true;
      _error = null;
    });

    final query = [
      if (_mercados.isNotEmpty) 'mercados=${_mercados.join(',')}',
      if (_unidades.isNotEmpty) 'unidades=${_unidades.map(Uri.encodeComponent).join(',')}',
      if (_porMercado) 'porMercado=true',
    ].join('&');

    try {
      final bytes = await ref.read(despachoApiProvider).pdfCarga(widget.despachoId, query);
      final limpio = widget.numero.replaceAll(RegExp(r'[^A-Za-z0-9]'), '-');
      final carpeta = await getTemporaryDirectory();
      final archivo = File('${carpeta.path}/carga-$limpio.pdf');
      await archivo.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context).pop();
      await OpenFilex.open(archivo.path);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.texto);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos generar el reporte.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opcionesAsync = ref.watch(opcionesCargaProvider(widget.despachoId));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Dimen.espacio4,
          0,
          Dimen.espacio4,
          Dimen.espacio4 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reporte de carga',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Elige qué entra. Sin marcar nada sale todo el camión.',
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Dimen.espacio3),
                decoration: BoxDecoration(
                  color: Colores.peligroSuave,
                  borderRadius: BorderRadius.circular(Dimen.radioCampo),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colores.peligro)),
              ),
              const SizedBox(height: Dimen.espacio3),
            ],

            Flexible(
              child: opcionesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimen.espacio5),
                  child: Text(
                    e is ApiExcepcion ? e.texto : 'No pudimos cargar los filtros.',
                    style: const TextStyle(fontSize: 13, color: Colores.peligro),
                  ),
                ),
                data: (opciones) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (opciones.mercados.isNotEmpty) ...[
                        const Text('Mercados', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        for (final m in opciones.mercados)
                          CheckboxListTile(
                            value: _mercados.contains(m.id),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Mercado ${m.nombre} (${m.pedidos} ${m.pedidos == 1 ? 'pedido' : 'pedidos'})',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _mercados.add(m.id);
                              } else {
                                _mercados.remove(m.id);
                              }
                            }),
                          ),
                        const SizedBox(height: Dimen.espacio3),
                      ],
                      if (opciones.unidades.isNotEmpty) ...[
                        const Text('Unidades de medida', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        for (final u in opciones.unidades)
                          CheckboxListTile(
                            value: _unidades.contains(u.codigo),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${u.nombre} (${u.productos} ${u.productos == 1 ? 'producto' : 'productos'})',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _unidades.add(u.codigo);
                              } else {
                                _unidades.remove(u.codigo);
                              }
                            }),
                          ),
                        const SizedBox(height: Dimen.espacio3),
                      ],
                      CheckboxListTile(
                        value: _porMercado,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Separar por mercado (un bloque por cada uno)',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        onChanged: (v) => setState(() => _porMercado = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppBoton(
              texto: 'Generar',
              expandido: true,
              cargando: _generando,
              onPressed: opcionesAsync.valueOrNull == null
                  ? null
                  : () => _generar(opcionesAsync.value!),
            ),
          ],
        ),
      ),
    );
  }
}
