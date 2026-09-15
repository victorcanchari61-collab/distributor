import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartido/widgets/app_aviso.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/permisos/solicitud_api.dart';
import '../../config/datos/config_modelos.dart' as cfg;
import '../../config/estado/config_controlador.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';

/// Cómo se lee cada acción cuando va sola, sin la pantalla al lado.
const _etiquetaAccion = {
  Accion.ver: 'Entrar',
  Accion.crear: 'Crear',
  Accion.editar: 'Editar',
  Accion.anular: 'Anular',
  Accion.eliminar: 'Eliminar',
  Accion.exportar: 'Exportar',
  Accion.importar: 'Importar',
  Accion.confirmar: 'Confirmar',
  Accion.cobrar: 'Cobrar',
};

/// Las solicitudes que esta persona dejó pedidas y siguen sin respuesta.
///
/// Sin esto, el botón de pedir no tiene forma de saber que ya se pidió: se
/// volvería a tocar y el backend devolvería la misma solicitud abierta, sin
/// que en pantalla cambiara nada.
final _misPendientesProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(solicitudApiProvider).misPendientes(),
);

/// Todo lo que se puede hacer dentro de un módulo, y en qué está cada cosa.
///
/// Antes, tocar un módulo en Inicio saltaba a su primera vista. Servía de
/// atajo, pero escondía lo importante: quien no puede abrir esa vista se
/// estrellaba contra el candado sin saber qué más había dentro ni cómo
/// pedirlo. Aquí están sus pantallas y sus acciones, lo concedido en verde,
/// lo ya pedido en ámbar y el resto con candado, que al tocarlo se pide.
Future<void> mostrarModulo(BuildContext context, MenuGrupo grupo) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    // La hoja cuelga del Navigator y no ve el acento de la pantalla que la
    // abrió: aquí lleva el del módulo, que es de lo que trata.
    builder: (_) => Acento(color: grupo.color, child: _HojaModulo(grupo: grupo)),
  );
}

class _HojaModulo extends ConsumerWidget {
  const _HojaModulo({required this.grupo});

  final MenuGrupo grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefijado: 'SubmoduloCatalogo' existe dos veces —en permisos y en los
    // modelos de config— y sin decir cual, la lista sale como List<Object>.
    final List<cfg.SubmoduloCatalogo> catalogo =
        ref.watch(catalogoPermisosProvider).valueOrNull ?? const [];
    final pendientes = ref.watch(_misPendientesProvider).valueOrNull ?? const <String>{};

    final acciones = <String, List<String>>{
      for (final c in catalogo) c.submodulo: c.acciones,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio4,
              0,
              Dimen.espacio4,
              Dimen.espacio3,
            ),
            child: Row(
              children: [
                Icon(grupo.icono, size: 20, color: grupo.color),
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grupo.titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colores.tinta,
                        ),
                      ),
                      const Text(
                        'Lo que puedes hacer aquí. Lo que no, se pide.',
                        style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio3,
                Dimen.espacio4,
                Dimen.espacio5,
              ),
              itemCount: grupo.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Dimen.espacio3),
              itemBuilder: (context, i) => _Vista(
                item: grupo.items[i],
                acciones: acciones[grupo.items[i].id] ?? const [],
                pendientes: pendientes,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vista extends ConsumerWidget {
  const _Vista({
    required this.item,
    required this.acciones,
    required this.pendientes,
  });

  final MenuItem item;
  final List<String> acciones;
  final Set<String> pendientes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entra = puedeVer(ref, item.id);

    return Container(
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
              Icon(item.icono, size: 16, color: Acento.de(context)),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: Text(
                  item.titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: entra ? Colores.tinta : Colores.tintaSuave,
                  ),
                ),
              ),

              // Se entra desde aquí si se puede: tener la lista delante y
              // mandar a buscar la misma pantalla en el menú sobra.
              if (entra && !item.pendiente)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(item.ruta);
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Abrir',
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Acento.de(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),

          if (acciones.isEmpty)
            const Text(
              'Todavía no se puede pedir: esta pantalla aún no existe.',
              style: TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
            )
          else
            Wrap(
              spacing: Dimen.espacio2,
              runSpacing: Dimen.espacio2,
              children: [
                for (final accion in acciones)
                  _Chip(
                    submodulo: item.id,
                    accion: accion,
                    pedida: pendientes.contains('${item.id}:$accion'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Chip extends ConsumerStatefulWidget {
  const _Chip({
    required this.submodulo,
    required this.accion,
    required this.pedida,
  });

  final String submodulo;
  final String accion;
  final bool pedida;

  @override
  ConsumerState<_Chip> createState() => _ChipState();
}

class _ChipState extends ConsumerState<_Chip> {
  bool _enviando = false;
  bool _recienPedida = false;

  Future<void> _pedir() async {
    setState(() => _enviando = true);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(solicitudApiProvider).solicitar(
        submodulo: widget.submodulo,
        accion: widget.accion,
      );
      setState(() => _recienPedida = true);
      mensajero.mostrar('Pedido. Un administrador lo verá en su bandeja.');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiene = puede(ref, widget.submodulo, widget.accion);
    final pedida = widget.pedida || _recienPedida;

    final (Color fondo, Color tinta, IconData icono) = tiene
        ? (Colores.exitoSuave, Colores.exito, Icons.check_rounded)
        : pedida
        ? (const Color(0xFFFFFBEB), Colores.advertencia, Icons.schedule_rounded)
        : (Colores.fondo, Colores.tintaSuave, Icons.lock_outline_rounded);

    return GestureDetector(
      onTap: tiene || pedida || _enviando ? null : _pedir,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: tiene || pedida ? fondo : Colores.linea),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_enviando)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icono, size: 13, color: tinta),
            const SizedBox(width: 4),
            Text(
              _etiquetaAccion[widget.accion] ?? widget.accion,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tinta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
