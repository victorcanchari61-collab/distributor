import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_selector.dart';
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
///
/// El corte de horario recorta por CUÁNDO se registró cada pedido: el camión se
/// carga en tandas y cada corte trae solo lo que cambió. Se combina con los
/// demás filtros, no los reemplaza.
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
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
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

  /// 0 es todo el camión; 1, 2 y 3 son los cortes de horario.
  int _corte = 0;
  bool _generando = false;
  String? _error;

  Future<void> _generar(OpcionesCarga opciones) async {
    setState(() {
      _generando = true;
      _error = null;
    });

    final query = [
      if (_mercados.isNotEmpty) 'mercados=${_mercados.join(',')}',
      if (_unidades.isNotEmpty)
        'unidades=${_unidades.map(Uri.encodeComponent).join(',')}',
      if (_porMercado) 'porMercado=true',
      // "Todos" no se manda: sin corte el backend saca el camión completo.
      if (_corte != 0) 'corte=$_corte',
    ].join('&');

    try {
      final bytes = await ref
          .read(despachoApiProvider)
          .pdfCarga(widget.despachoId, query);
      final limpio = widget.numero.replaceAll(RegExp(r'[^A-Za-z0-9]'), '-');
      final carpeta = await getTemporaryDirectory();
      // El corte va en el nombre, como lo nombra el backend: cada tanda es un
      // papel distinto y en el teléfono no deben pisarse ni confundirse.
      final sufijo = _corte != 0 ? '-corte$_corte' : '';
      final archivo = File('${carpeta.path}/carga-$limpio$sufijo.pdf');
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: Colores.peligro),
                ),
              ),
              const SizedBox(height: Dimen.espacio3),
            ],

            Flexible(
              child: opcionesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimen.espacio5),
                  child: Text(
                    e is ApiExcepcion
                        ? e.texto
                        : 'No pudimos cargar los filtros.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colores.peligro,
                    ),
                  ),
                ),
                data: (opciones) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Solo si el servidor ofrece cortes: uno más antiguo no
                      // los conoce y el reporte sale del camión completo.
                      if (opciones.cortes.isNotEmpty) ...[
                        AppSelector<int>(
                          valor: _corte,
                          etiqueta: 'Corte de horario',
                          icono: Icons.schedule_outlined,
                          // Los nombres traen las horas al final: en una sola
                          // línea se cortaban justo ahí.
                          lineasOpcion: 2,
                          opciones: [
                            for (final c in opciones.cortes)
                              Opcion(c.codigo, c.nombre),
                          ],
                          onCambio: (v) => setState(() => _corte = v ?? 0),
                        ),
                        if (_corte == 1)
                          const _NotaCorte(
                            'La carga base: los pedidos como quedaron hasta las 15:00, '
                            'incluido lo registrado en días anteriores.',
                          ),
                        if (_corte > 1)
                          const _NotaCorte(
                            'Aumentos: sale solo lo que se agregó en esa franja —lo que subió de '
                            'cantidad, los productos y los pedidos nuevos—, para sumarlo a lo que '
                            'ya se cargó. Lo que bajó sale en negativo.',
                          ),
                        const SizedBox(height: Dimen.espacio4),
                      ],
                      if (opciones.mercados.isNotEmpty) ...[
                        const Text(
                          'Mercados',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                        const Text(
                          'Unidades de medida',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                        onChanged: (v) =>
                            setState(() => _porMercado = v ?? false),
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

/// Qué trae el corte elegido: el nombre solo no dice que los aumentos salen
/// aparte de lo que ya subió al camión.
class _NotaCorte extends StatelessWidget {
  const _NotaCorte(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Dimen.espacio2),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
      ),
    );
  }
}
