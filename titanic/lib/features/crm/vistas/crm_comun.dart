import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';

/// Soles con separador de miles y sin decimales: son cifras de gestión, no de
/// caja.
String soles(double n) {
  final negativo = n < 0;
  final digitos = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) b.write(',');
    b.write(digitos[i]);
  }
  return '${negativo ? '−' : ''}S/ $b';
}

/// "−S/ 120" o "+S/ 80": para diferencias.
String solesConSigno(double n) => n > 0 ? '+${soles(n)}' : soles(n);

/// "−83.3 %" o "+12.0 %". Sin base de comparación, un guion.
String porcentaje(double? n) {
  if (n == null) return '—';
  return '${n < 0
      ? '−'
      : n > 0
      ? '+'
      : ''}${n.abs().toStringAsFixed(1)} %';
}

/// Rojo si bajó, verde si subió: el color que cualquiera espera de una
/// variación.
Color colorCambio(double n) => n < 0
    ? Colores.peligro
    : n > 0
    ? Colores.exito
    : Colores.tintaSuave;

/// El color de los días sin comprar: la misma escala de los estados.
Color colorDeDias(int? dias) {
  if (dias == null) return EstadoCaida.sinBase.color;
  if (dias >= 61) return EstadoCaida.critico.color;
  if (dias >= 31) return EstadoCaida.riesgo.color;
  if (dias >= 16) return EstadoCaida.seguimiento.color;
  return EstadoCaida.normal.color;
}

/// "20/10/2026".
String fechaDia(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "20/10/2026 10:00 a. m."
String fechaHora(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${fechaDia(d)} $h:${d.minute.toString().padLeft(2, '0')} '
      '${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// "Perú" lleva 51 delante: el número como lo pide wa.me.
String _numeroWhatsapp(String telefono) {
  final d = telefono.replaceAll(RegExp(r'\D'), '');
  return d.length == 9 ? '51$d' : d;
}

/// Abre el chat de WhatsApp con ese número, en la app del teléfono.
Future<void> abrirWhatsapp(BuildContext context, String telefono) async {
  final aviso = Aviso.de(context);
  final ok = await launchUrl(
    Uri.parse('https://wa.me/${_numeroWhatsapp(telefono)}'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok) aviso.error('No pudimos abrir WhatsApp.');
}

/// La etiqueta del estado de un cliente, con su color.
class EtiquetaEstadoCaida extends StatelessWidget {
  const EtiquetaEstadoCaida(this.estado, {super.key});

  final EstadoCaida estado;

  @override
  Widget build(BuildContext context) => AppEtiqueta(
    estado.etiqueta,
    color: estado.color,
    tono: EtiquetaTono.modulo,
  );
}

/// Una fila de tarjetas de estado que además filtran: tocar una deja solo los
/// de ese estado, tocarla otra vez quita el filtro. Es el equivalente de las
/// tarjetas Crítico / En riesgo / En seguimiento del panel web.
class TarjetasEstado extends StatelessWidget {
  const TarjetasEstado({
    super.key,
    required this.estados,
    required this.activo,
    required this.onCambio,
    this.nota,
    this.soloEstos,
  });

  final List<ResumenEstado> estados;
  final EstadoCaida? activo;
  final ValueChanged<EstadoCaida?> onCambio;

  /// El texto bajo el número de cada estado.
  final String Function(ResumenEstado)? nota;

  /// Los estados que se ofrecen (Inactivos no tiene Normal ni Sin comparación).
  final List<EstadoCaida>? soloEstos;

  @override
  Widget build(BuildContext context) {
    final mostrar = soloEstos ?? EstadoCaida.values;

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        children: [
          for (final e in mostrar) ...[
            _Tarjeta(
              estado: e,
              resumen: estados.where((r) => r.estado == e).firstOrNull,
              activa: activo == e,
              nota: nota,
              onTap: () => onCambio(activo == e ? null : e),
            ),
            const SizedBox(width: Dimen.espacio2),
          ],
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.estado,
    required this.resumen,
    required this.activa,
    required this.onTap,
    this.nota,
  });

  final EstadoCaida estado;
  final ResumenEstado? resumen;
  final bool activa;
  final VoidCallback onTap;
  final String Function(ResumenEstado)? nota;

  @override
  Widget build(BuildContext context) {
    final c = estado.color;
    final r = resumen ?? ResumenEstado(estado, 0, 0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(Dimen.espacio3),
        decoration: BoxDecoration(
          color: activa ? c.withValues(alpha: 0.08) : Colores.superficie,
          border: Border.all(
            color: activa ? c : Colores.linea,
            width: activa ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estado.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colores.tintaSuave,
              ),
            ),
            Text(
              '${r.clientes}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: c,
                height: 1.1,
              ),
            ),
            Text(
              nota?.call(r) ?? estado.rango,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colores.tintaSuave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un recuadro de datos: título y valor, para las cifras de las hojas.
class DatoRecuadro extends StatelessWidget {
  const DatoRecuadro(
    this.etiqueta,
    this.valor, {
    super.key,
    this.nota,
    this.color,
  });

  final String etiqueta;
  final String valor;
  final String? nota;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Dimen.espacio3),
    decoration: BoxDecoration(
      border: Border.all(color: Colores.linea),
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colores.tintaSuave,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color ?? Colores.tinta,
          ),
        ),
        if (nota != null)
          Text(
            nota!,
            style: const TextStyle(fontSize: 11, color: Colores.tintaSuave),
          ),
      ],
    ),
  );
}

/// La lista de productos de un cliente en los dos tramos: qué dejó de comprar,
/// qué compra más y qué es nuevo.
class ListaProductosSituacion extends StatelessWidget {
  const ListaProductosSituacion({super.key, required this.productos});

  final List<ProductoSituacion> productos;

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Dimen.espacio5),
        child: Center(
          child: Text(
            'Sin compras de productos en estos tramos.',
            style: TextStyle(color: Colores.tintaSuave),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final p in productos)
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
                    Expanded(
                      child: Text(
                        p.producto,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio2),
                    AppEtiqueta(
                      p.situacion.etiqueta,
                      color: p.situacion.color,
                      tono: EtiquetaTono.modulo,
                    ),
                  ],
                ),
                const SizedBox(height: Dimen.espacio1),
                Row(
                  children: [
                    Text(
                      'Antes ${soles(p.ventaAnterior)}  ·  Ahora ${soles(p.ventaActual)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colores.tintaSuave,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      solesConSigno(p.variacion),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colorCambio(p.variacion),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La hoja "Qué dejó de comprar": los productos del cliente en los dos tramos.
Future<void> mostrarQueDejoDeComprar(
  BuildContext context, {
  required int clienteId,
  required String cliente,
}) => abrirHoja<void>(
  context,
  (_) => _HojaQueDejo(clienteId: clienteId, cliente: cliente),
);

class _HojaQueDejo extends ConsumerWidget {
  const _HojaQueDejo({required this.clienteId, required this.cliente});

  final int clienteId;
  final String cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(queDejoDeComprarProvider(clienteId));

    return HojaBase(
      titulo: 'Qué dejó de comprar',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cliente,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimen.espacio3),
          datos.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Dimen.espacio6),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppAlerta(
              e is ApiExcepcion
                  ? e.mensaje
                  : 'No pudimos cargar los productos.',
            ),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.periodo.etiqueta} frente a ${d.periodo.etiquetaAnterior}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.tintaSuave,
                  ),
                ),
                const SizedBox(height: Dimen.espacio3),
                ListaProductosSituacion(productos: d.productos),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
