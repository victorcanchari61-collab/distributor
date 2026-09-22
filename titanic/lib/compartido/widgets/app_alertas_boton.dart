import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navegacion/menu.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/alertas/datos/alerta.dart';
import '../../features/alertas/estado/alertas_controlador.dart';

/// Como se lee la accion pedida, sin la pantalla al lado.
const _accionPedida = {
  'ver': 'entrar',
  'crear': 'crear',
  'editar': 'editar',
  'anular': 'anular',
  'eliminar': 'eliminar',
  'exportar': 'exportar',
  'importar': 'importar',
  'confirmar': 'confirmar',
  'cobrar': 'cobrar',
};

/// Campana de alertas del AppBar: cuenta lo pendiente sin leer y abre una
/// hoja con el detalle. El color avisa la urgencia antes de abrirla — rojo si
/// hay algo critico, ambar si hay advertencias, verde si solo hay buenas
/// noticias.
class AppAlertasBoton extends ConsumerWidget {
  const AppAlertasBoton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasProvider).valueOrNull ?? const <Alerta>[];
    final leidas = ref.watch(alertasLeidasProvider).valueOrNull ?? const {};
    final sinLeer = alertas.where((a) => !leidas.containsKey(a.id)).toList();

    final criticas = sinLeer
        .where((a) => a.severidad == SeveridadAlerta.critica)
        .length;
    final advertencias = sinLeer
        .where((a) => a.severidad == SeveridadAlerta.advertencia)
        .length;
    final color = criticas > 0
        ? Colores.peligro
        : advertencias > 0
        ? Colores.advertencia
        : Colores.exito;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => _abrirHoja(context, ref),
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Alertas',
        ),
        if (sinLeer.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sinLeer.length > 9 ? '9+' : '${sinLeer.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _abrirHoja(BuildContext context, WidgetRef ref) {
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
      builder: (context) => const _HojaAlertas(),
    );
  }
}

class _HojaAlertas extends ConsumerStatefulWidget {
  const _HojaAlertas();

  @override
  ConsumerState<_HojaAlertas> createState() => _HojaAlertasState();
}

class _HojaAlertasState extends ConsumerState<_HojaAlertas> {
  // Las leidas no desaparecen del todo: se pueden volver a ver, para no
  // perder el rastro de que existieron.
  bool _verLeidas = false;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(alertasProvider);
    final alertas = estado.valueOrNull ?? const <Alerta>[];
    final leidas = ref.watch(alertasLeidasProvider).valueOrNull ?? const {};
    final sinLeer = alertas.where((a) => !leidas.containsKey(a.id)).toList();
    final visibles = _verLeidas ? alertas : sinLeer;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alertas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colores.tinta,
                          ),
                        ),
                        const SizedBox(height: Dimen.espacio1),
                        Text(
                          alertas.isEmpty
                              ? 'Todo en orden'
                              : sinLeer.isEmpty
                              ? 'Ya revisaste todo'
                              : '${sinLeer.length} para revisar',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colores.tintaSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sinLeer.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(alertasLeidasProvider.notifier)
                          .marcarTodas([for (final a in sinLeer) a.id]),
                      icon: const Icon(Icons.done_all, size: 15),
                      label: const Text(
                        'Marcar todas',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimen.espacio2,
                        ),
                        foregroundColor: Colores.tintaSuave,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Dimen.espacio2),

              Flexible(
                child: estado.isLoading && alertas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: Dimen.espacio6),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : visibles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimen.espacio6,
                        ),
                        child: Center(
                          child: Text(
                            alertas.isEmpty
                                ? 'No hay nada pendiente.'
                                : 'No queda nada sin leer.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colores.tintaSuave,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibles.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _FilaAlerta(
                          alerta: visibles[i],
                          leida: leidas.containsKey(visibles[i].id),
                        ),
                      ),
              ),

              if (alertas.isNotEmpty && alertas.length != sinLeer.length)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => _verLeidas = !_verLeidas),
                      child: Text(
                        _verLeidas
                            ? 'Ocultar las leídas'
                            : 'Ver también las leídas (${alertas.length - sinLeer.length})',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: Dimen.espacio3),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaAlerta extends ConsumerWidget {
  const _FilaAlerta({required this.alerta, required this.leida});

  final Alerta alerta;
  final bool leida;

  Color get _color => switch (alerta.severidad) {
    SeveridadAlerta.critica => Colores.peligro,
    SeveridadAlerta.advertencia => Colores.advertencia,
    _ => Colores.exito,
  };

  /*
   * El acceso pedido llega con los ids del backend —"fact.precios · ver"—,
   * que es lo unico que el servidor conoce: los nombres de las pantallas
   * viven en el menu, aqui. Se traducen al leerlos y no antes.
   */
  String get _detalle {
    if (alerta.tipo != TipoAlerta.solicitudAcceso) return alerta.detalle;

    final partes = alerta.detalle.split(' · ');
    if (partes.length < 2) return alerta.detalle;

    final pantalla = vistaPorId(partes[0])?.titulo ?? partes[0];
    return [
      pantalla,
      _accionPedida[partes[1]] ?? partes[1],
      ...partes.skip(2),
    ].join(' · ');
  }

  IconData get _icono => switch (alerta.tipo) {
    TipoAlerta.stockRepuesto => Icons.inventory_2_outlined,
    TipoAlerta.lotePorVencer => Icons.event_busy_outlined,
    TipoAlerta.solicitudAcceso => Icons.lock_person_outlined,
    TipoAlerta.documentoVehiculo => Icons.description_outlined,
    TipoAlerta.licenciaConductor => Icons.badge_outlined,
    _ => Icons.warning_amber_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: leida ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: alerta.ruta == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        context.go('/${alerta.ruta!.split('.').join('/')}');
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimen.espacio1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icono, size: 15, color: _color),
                      ),
                      const SizedBox(width: Dimen.espacio3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alerta.titulo,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colores.tinta,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _detalle,
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
              ),
            ),
            // Marcar como leida sin navegar: por eso va fuera del InkWell que abre la alerta.
            if (!leida)
              IconButton(
                onPressed: () =>
                    ref.read(alertasLeidasProvider.notifier).marcar(alerta.id),
                icon: const Icon(Icons.check, size: 17),
                tooltip: 'Marcar como leída',
                color: Colores.tintaSuave,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
