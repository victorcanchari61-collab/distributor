import 'package:flutter/material.dart';

import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/crm.dart';
import 'crm_comun.dart';

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'set',
  'oct',
  'nov',
  'dic',
];

/// El mes abreviado de un "YYYY-MM-DD", sin pasar por una zona horaria.
String _mesCorto(String iso) {
  final n = int.tryParse(iso.length >= 7 ? iso.substring(5, 7) : '') ?? 0;
  return n >= 1 && n <= 12 ? _meses[n - 1] : '';
}

/// La pestaña Resumen: cuánto compra el cliente, qué compra y cómo viene mes a
/// mes frente al año anterior.
class TabResumen extends StatelessWidget {
  const TabResumen({
    super.key,
    required this.ficha,
    required this.alVerSeguimiento,
  });

  final FichaCliente ficha;
  final VoidCallback alVerSeguimiento;

  @override
  Widget build(BuildContext context) {
    final p = ficha.periodo;
    final dias = ficha.diasSinComprar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DatoRecuadro(
                'Sin comprar',
                dias == null ? 'Nunca' : '$dias días',
                color: colorDeDias(dias),
                nota: ficha.ultimaCompra == null
                    ? null
                    : 'desde el ${fechaDia(ficha.ultimaCompra)}',
              ),
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: DatoRecuadro(
                'Saldo por cobrar',
                soles(ficha.saldoPorCobrar),
                color: ficha.saldoPorCobrar > 0 ? Colores.peligro : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio2),
        Row(
          children: [
            Expanded(
              child: DatoRecuadro(
                'Compró en el período',
                soles(p.ventas),
                nota: '${p.compras} compras · ${p.etiqueta}',
              ),
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: DatoRecuadro(
                'Ticket promedio',
                soles(p.ticketPromedio),
                nota: 'antes ${soles(p.ventasAnterior)}',
              ),
            ),
          ],
        ),

        if (ficha.proximaGestion != null || ficha.ultimaGestion != null) ...[
          const SizedBox(height: Dimen.espacio4),
          _TarjetaGestion(ficha: ficha, alVer: alVerSeguimiento),
        ],

        const SizedBox(height: Dimen.espacio4),
        const _Titulo('Compras mes a mes'),
        _BarrasMeses(meses: ficha.meses),

        const SizedBox(height: Dimen.espacio4),
        const _Titulo('Lo que más compra'),
        if (ficha.productosPrincipales.isEmpty)
          const Text(
            'Sin compras en el período.',
            style: TextStyle(color: Colores.tintaSuave),
          )
        else
          for (final pr in ficha.productosPrincipales)
            _BarraProducto(producto: pr),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Dimen.espacio2),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );
}

/// Lo último que se habló con el cliente y lo que queda programado.
class _TarjetaGestion extends StatelessWidget {
  const _TarjetaGestion({required this.ficha, required this.alVer});

  final FichaCliente ficha;
  final VoidCallback alVer;

  @override
  Widget build(BuildContext context) {
    final u = ficha.ultimaGestion;
    final s = ficha.proximaGestion;

    return InkWell(
      onTap: alVer,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        padding: const EdgeInsets.all(Dimen.espacio3),
        decoration: BoxDecoration(
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (u != null)
              Row(
                children: [
                  Icon(
                    u.tipoContacto?.icono ?? Icons.chat_outlined,
                    size: 17,
                    color: colorDeTono(u.tono),
                  ),
                  const SizedBox(width: Dimen.espacio2),
                  Expanded(
                    child: Text(
                      'Último contacto: ${u.resultadoEtiqueta} · ${fechaDia(u.fecha)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            if (s != null) ...[
              if (u != null) const SizedBox(height: Dimen.espacio2),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 17,
                    color: s.vencida ? Colores.peligro : Acento.de(context),
                  ),
                  const SizedBox(width: Dimen.espacio2),
                  Expanded(
                    child: Text(
                      '${s.vencida ? 'Vencido' : 'Próximo'}: '
                      '${s.proximoSeguimiento == null ? '—' : fechaHora(s.proximoSeguimiento!)}'
                      '${s.proximaAccion == null ? '' : ' · ${s.proximaAccion}'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: s.vencida ? Colores.peligro : Colores.tinta,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dos barras por mes: el año anterior en gris y el año en curso en color.
class _BarrasMeses extends StatelessWidget {
  const _BarrasMeses({required this.meses});

  final List<MesCliente> meses;

  @override
  Widget build(BuildContext context) {
    if (meses.length < 12) {
      return const Text(
        'Sin compras que mostrar.',
        style: TextStyle(color: Colores.tintaSuave),
      );
    }

    // Los últimos 12 son el año en curso; los 12 anteriores, el pasado.
    final actual = meses.sublist(meses.length - 12);
    final previo = meses.length >= 24
        ? meses.sublist(meses.length - 24, meses.length - 12)
        : List<MesCliente>.generate(12, (i) => MesCliente(actual[i].mes, 0));
    final tope = [
      ...actual,
      ...previo,
    ].map((m) => m.importe).fold<double>(1, (a, b) => b > a ? b : a);
    final acento = Acento.de(context);
    const alto = 110.0;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: alto + 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 12; i++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${_mesCorto(actual[i].mes)}: ${soles(actual[i].importe)} '
                          '(antes ${soles(previo[i].importe)})',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: alto * previo[i].importe / tope,
                                color: Colores.lineaFuerte,
                              ),
                              const SizedBox(width: 1),
                              Container(
                                width: 6,
                                height: alto * actual[i].importe / tope,
                                color: acento,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mesCorto(actual[i].mes),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colores.tintaSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.espacio2),
          Row(
            children: [
              Container(width: 10, height: 10, color: Colores.lineaFuerte),
              const SizedBox(width: 4),
              const Text(
                'Año anterior',
                style: TextStyle(fontSize: 11, color: Colores.tintaSuave),
              ),
              const SizedBox(width: Dimen.espacio3),
              Container(width: 10, height: 10, color: acento),
              const SizedBox(width: 4),
              const Text(
                'Este año',
                style: TextStyle(fontSize: 11, color: Colores.tintaSuave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarraProducto extends StatelessWidget {
  const _BarraProducto({required this.producto});

  final ProductoPrincipal producto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Dimen.espacio2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                producto.producto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            Text(
              '${soles(producto.monto)} · ${producto.porcentaje.toStringAsFixed(0)} %',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (producto.porcentaje / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colores.linea,
            color: Acento.de(context),
          ),
        ),
      ],
    ),
  );
}
