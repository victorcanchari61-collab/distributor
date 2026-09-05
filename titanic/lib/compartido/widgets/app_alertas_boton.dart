import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/alertas/datos/alerta.dart';
import '../../features/alertas/estado/alertas_controlador.dart';

/// Campana de alertas del AppBar: cuenta lo pendiente y abre una hoja con el
/// detalle. El color avisa la urgencia antes de abrirla — rojo si hay algo
/// critico, ambar si hay advertencias, verde si solo hay buenas noticias.
class AppAlertasBoton extends ConsumerWidget {
  const AppAlertasBoton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasProvider).valueOrNull ?? const <Alerta>[];
    final criticas = alertas.where((a) => a.severidad == SeveridadAlerta.critica).length;
    final advertencias = alertas.where((a) => a.severidad == SeveridadAlerta.advertencia).length;
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
        if (alertas.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text(
                alertas.length > 9 ? '9+' : '${alertas.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (context) => const _HojaAlertas(),
    );
  }
}

class _HojaAlertas extends ConsumerWidget {
  const _HojaAlertas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(alertasProvider);
    final alertas = estado.valueOrNull ?? const <Alerta>[];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alertas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
              ),
              const SizedBox(height: Dimen.espacio1),
              Text(
                alertas.isEmpty ? 'Todo en orden' : '${alertas.length} para revisar',
                style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
              ),
              const SizedBox(height: Dimen.espacio3),

              Flexible(
                child: estado.isLoading && alertas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: Dimen.espacio6),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : alertas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: Dimen.espacio6),
                        child: Center(
                          child: Text(
                            'No hay nada pendiente.',
                            style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: alertas.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _FilaAlerta(alerta: alertas[i]),
                      ),
              ),
              const SizedBox(height: Dimen.espacio3),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaAlerta extends StatelessWidget {
  const _FilaAlerta({required this.alerta});

  final Alerta alerta;

  Color get _color => switch (alerta.severidad) {
    SeveridadAlerta.critica => Colores.peligro,
    SeveridadAlerta.advertencia => Colores.advertencia,
    _ => Colores.exito,
  };

  IconData get _icono => switch (alerta.tipo) {
    TipoAlerta.stockRepuesto => Icons.inventory_2_outlined,
    TipoAlerta.lotePorVencer => Icons.event_busy_outlined,
    _ => Icons.warning_amber_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alerta.ruta == null
          ? null
          : () {
              Navigator.of(context).pop();
              context.go('/${alerta.ruta!.split('.').join('/')}');
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Dimen.espacio3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(_icono, size: 15, color: _color),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alerta.titulo,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colores.tinta),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alerta.detalle,
                    style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
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
