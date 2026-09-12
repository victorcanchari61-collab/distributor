import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/arqueo.dart';
import '../estado/arqueo_controlador.dart';
import 'cuadre_pagina.dart';
import 'deudas_arqueo_pagina.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Cómo se pinta cada estado del cuadre.
///
/// Vive junto a la pantalla porque es decisión de presentación; el estado lo
/// decide el backend.
EtiquetaTono tonoEstadoCuadre(String estado) => switch (estado) {
  EstadoCuadre.cuadrado => EtiquetaTono.exito,
  EstadoCuadre.conDiferencia => EtiquetaTono.peligro,
  EstadoCuadre.pendiente => EtiquetaTono.aviso,
  _ => EtiquetaTono.neutral,
};

String fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// El cuadre del reparto: una fila por día y por persona.
///
/// Lo que se mira no es el total del día sino quién falta por cuadrar y a quién
/// le falta dinero: por eso la lista trae también a los que todavía no han
/// declarado nada.
class ArqueoPagina extends ConsumerWidget {
  const ArqueoPagina({super.key});

  static const ruta = '/finanzas/arqueo';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final rango = ref.watch(rangoCuadresProvider);
    final todos =
        ref.watch(cuadresProvider).valueOrNull ?? const <CuadrePendiente>[];

    final pendientes = todos
        .where((c) => c.estado == EstadoCuadre.pendiente)
        .length;
    final efectivo = todos.fold<double>(0, (n, c) => n + c.efectivo);
    final bancos = todos.fold<double>(0, (n, c) => n + c.bancos);
    final faltante = todos
        .where((c) => !c.faltanteSaldado)
        .fold<double>(0, (n, c) => n + c.faltante);

    return AppListaPagina<CuadrePendiente>(
      titulo: 'Arqueo diario',
      ruta: ruta,
      estado: ref.watch(cuadresProvider),
      visibles: ref.watch(cuadresFiltradosProvider),
      busqueda: ref.watch(busquedaCuadresProvider),
      onBuscar: (t) => ref.read(busquedaCuadresProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por persona o estado',
      onRecargar: () => ref.read(cuadresProvider.notifier).recargar(),
      iconoVacio: Icons.calculate_outlined,
      singular: 'cuadre',
      plural: 'cuadres',
      tituloVacio: 'Sin cobros en el rango',
      detalleVacio:
          'Nadie cobró entre esas fechas, así que no hay nada que cuadrar.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Por cuadrar',
          valor: '$pendientes',
          icono: Icons.pending_actions_outlined,
          tono: pendientes > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Efectivo',
          valor: formatoSoles(efectivo),
          icono: Icons.payments_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Bancos',
          valor: formatoSoles(bancos),
          icono: Icons.account_balance_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Faltante',
          valor: formatoSoles(faltante),
          icono: Icons.trending_down,
          tono: faltante > 0 ? DatoTono.peligro : DatoTono.exito,
        ),
      ],
      encabezado: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        child: Row(
          children: [
            Expanded(
              child: _SelectorRango(
                rango: rango,
                onCambio: (r) =>
                    ref.read(rangoCuadresProvider.notifier).state = r,
              ),
            ),
            const SizedBox(width: Dimen.espacio2),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeudasArqueoPagina()),
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text('Deudas'),
            ),
          ],
        ),
      ),
      fila: (context, cuadre) => _TarjetaCuadre(
        cuadre: cuadre,
        color: color,
        onCuadrar: () => _abrirCuadre(context, cuadre),
        onAnular: () => _anular(context, ref, cuadre),
      ),
    );
  }

  Future<void> _abrirCuadre(BuildContext context, CuadrePendiente cuadre) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CuadrePagina(fecha: cuadre.fecha, usuarioId: cuadre.usuarioId),
      ),
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    CuadrePendiente cuadre,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular el cuadre',
      mensaje:
          'El cuadre de ${cuadre.usuario} del ${fechaCorta(cuadre.fecha)} deja de contar '
          'y su faltante deja de cobrarse. El día vuelve a quedar pendiente.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(cuadresProvider.notifier).anular(cuadre.arqueoId!);
      mensajero.mostrar('Cuadre anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

/// El rango de días que se está revisando.
class _SelectorRango extends StatelessWidget {
  const _SelectorRango({required this.rango, required this.onCambio});

  final DateTimeRange rango;
  final ValueChanged<DateTimeRange> onCambio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final hoy = DateTime.now();
        final elegido = await showDateRangePicker(
          context: context,
          initialDateRange: rango,
          firstDate: DateTime(hoy.year - 2),
          lastDate: DateTime(hoy.year, hoy.month, hoy.day),
        );
        if (elegido != null) onCambio(elegido);
      },
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        height: Dimen.campoMd,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.date_range_outlined,
              size: 18,
              color: Colores.tintaSuave,
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: Text(
                '${fechaCorta(rango.start)} — ${fechaCorta(rango.end)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colores.tinta),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Acento.de(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCuadre extends StatelessWidget {
  const _TarjetaCuadre({
    required this.cuadre,
    required this.color,
    required this.onCuadrar,
    required this.onAnular,
  });

  final CuadrePendiente cuadre;
  final Color color;
  final VoidCallback onCuadrar;
  final VoidCallback onAnular;

  @override
  Widget build(BuildContext context) {
    final diferencia = cuadre.diferenciaEfectivo;

    return AppTarjetaRegistro(
      icono: Icons.person_outline,
      color: color,
      titulo: cuadre.usuario,
      insignia: AppEtiqueta(
        EstadoCuadre.etiqueta(cuadre.estado),
        tono: tonoEstadoCuadre(cuadre.estado),
      ),
      campos: [
        CampoDetalle('Fecha', fechaCorta(cuadre.fecha)),
        CampoDetalle('Efectivo', formatoSoles(cuadre.efectivo)),
        CampoDetalle('Bancos', formatoSoles(cuadre.bancos)),
        CampoDetalle(
          'Total',
          formatoSoles(cuadre.total),
          widget: Text(
            formatoSoles(cuadre.total),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        if (diferencia != null)
          CampoDetalle(
            'Diferencia',
            formatoSoles(diferencia),
            widget: Text(
              formatoSoles(diferencia),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: diferencia == 0
                    ? Colores.exito
                    : diferencia < 0
                    ? Colores.peligro
                    : Colores.advertencia,
              ),
            ),
          ),
        if (cuadre.faltante > 0)
          CampoDetalle(
            'Faltante',
            formatoSoles(cuadre.faltante),
            widget: AppEtiqueta(
              cuadre.faltanteSaldado
                  ? 'Saldado ${formatoSoles(cuadre.faltante)}'
                  : 'Debe ${formatoSoles(cuadre.faltante)}',
              tono: cuadre.faltanteSaldado
                  ? EtiquetaTono.neutral
                  : EtiquetaTono.peligro,
            ),
          ),
      ],
      onTap: onCuadrar,
      acciones: [
        IconButton(
          onPressed: onCuadrar,
          tooltip: cuadre.cuadrado ? 'Corregir' : 'Cuadrar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            cuadre.cuadrado ? Icons.edit_outlined : Icons.fact_check_outlined,
            size: 18,
            color: color,
          ),
        ),
        if (cuadre.cuadrado)
          IconButton(
            onPressed: onAnular,
            tooltip: 'Anular',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.block, size: 18, color: Colores.peligro),
          ),
      ],
    );
  }
}
