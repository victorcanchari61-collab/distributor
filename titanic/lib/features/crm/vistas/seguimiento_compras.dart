import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../estado/crm_controlador.dart';
import 'crm_comun.dart';

Widget _cargando() => const Padding(
  padding: EdgeInsets.all(Dimen.espacio6),
  child: Center(child: CircularProgressIndicator()),
);

Widget _error(Object e) => AppAlerta(
  e is ApiExcepcion ? e.mensaje : 'No pudimos cargar la información.',
);

Widget _titulo(String texto) => Padding(
  padding: const EdgeInsets.only(bottom: Dimen.espacio2),
  child: Text(
    texto,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  ),
);

Widget _vacio(String texto) => Padding(
  padding: const EdgeInsets.symmetric(vertical: Dimen.espacio3),
  child: Text(texto, style: const TextStyle(color: Colores.tintaSuave)),
);

EtiquetaTono _tono(String estado) => switch (estado) {
  'CONFIRMADO' || 'APROBADA' || 'PAGADO' => EtiquetaTono.exito,
  'ANULADO' || 'RECHAZADA' => EtiquetaTono.peligro,
  _ => EtiquetaTono.aviso,
};

String _capital(String t) =>
    t.isEmpty ? t : t[0] + t.substring(1).toLowerCase();

/// La pestaña Compras: las ventas del cliente y qué productos compra más o
/// menos que el año anterior.
class TabCompras extends ConsumerWidget {
  const TabCompras({super.key, required this.clienteId});

  final int clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(comprasClienteProvider(clienteId))
        .when(
          loading: _cargando,
          error: (e, _) => _error(e),
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titulo('Productos'),
              ListaProductosSituacion(productos: d.productos),
              const SizedBox(height: Dimen.espacio4),
              _titulo('Ventas'),
              if (d.ventas.isEmpty) _vacio('Sin ventas en el período.'),
              for (final v in d.ventas)
                Container(
                  margin: const EdgeInsets.only(bottom: Dimen.espacio2),
                  padding: const EdgeInsets.all(Dimen.espacio3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colores.linea),
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            v.numero,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: Dimen.espacio2),
                          AppEtiqueta(
                            _capital(v.estado),
                            tono: _tono(v.estado),
                          ),
                          const Spacer(),
                          Text(
                            soles(v.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fechaDia(v.fecha)} · '
                        '${v.formaPago == 'CREDITO' ? 'Crédito' : 'Contado'}'
                        '${v.vendedor == null ? '' : ' · ${v.vendedor}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colores.tintaSuave,
                        ),
                      ),
                      if (v.saldo > 0)
                        Text(
                          'Debe ${soles(v.saldo)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colores.peligro,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
  }
}

/// La pestaña Documentos: los pedidos y las devoluciones del cliente.
class TabDocumentos extends ConsumerWidget {
  const TabDocumentos({super.key, required this.clienteId});

  final int clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(documentosClienteProvider(clienteId))
        .when(
          loading: _cargando,
          error: (e, _) => _error(e),
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titulo('Pedidos'),
              if (d.pedidos.isEmpty) _vacio('Sin pedidos.'),
              for (final p in d.pedidos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p.numero,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${fechaDia(p.fecha)} · '
                    '${p.condicionPago == 'CREDITO' ? 'Crédito' : 'Contado'}',
                  ),
                  trailing: AppEtiqueta(
                    _capital(p.estado),
                    tono: _tono(p.estado),
                  ),
                ),
              const Divider(),
              _titulo('Devoluciones'),
              if (d.devoluciones.isEmpty) _vacio('Sin devoluciones.'),
              for (final v in d.devoluciones)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    v.numero,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${fechaDia(v.fecha)} · de ${v.notaVenta}'
                    '${v.motivo == null ? '' : ' · ${v.motivo}'}',
                  ),
                  trailing: AppEtiqueta(
                    _capital(v.estado),
                    tono: _tono(v.estado),
                  ),
                ),
            ],
          ),
        );
  }
}
