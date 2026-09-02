import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/proveedor.dart';
import '../estado/maestros_controlador.dart';
import 'proveedor_formulario.dart';

/// Listado de proveedores.
class ProveedoresPagina extends ConsumerWidget {
  const ProveedoresPagina({super.key});

  static const ruta = '/maestros/proveedores';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupo = resolverRuta(ruta).grupo;
    final color = grupo?.color ?? Colores.marca;
    final estado = ref.watch(proveedoresProvider);
    final visibles = ref.watch(proveedoresFiltradosProvider);
    final inactivos = ref.watch(verInactivosProvider);
    final busqueda = ref.watch(busquedaProveedoresProvider);

    return AppShell(
      titulo: 'Proveedores',
      subtitulo: grupo?.titulo,
      acentado: color,
      rutaActual: ruta,
      accionFlotante: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, null),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio4),
            child: Column(
              children: [
                AppBuscador(
                  valor: busqueda,
                  onCambio: (t) =>
                      ref.read(busquedaProveedoresProvider.notifier).state = t,
                  pista: 'Buscar por razón social, documento o rubro',
                ),
                const SizedBox(height: Dimen.espacio3),
                Row(
                  children: [
                    // Flexible: el conteo cede espacio antes que empujar al
                    // interruptor fuera de la fila.
                    Flexible(
                      child: Text(
                        '${visibles.length} ${visibles.length == 1 ? 'proveedor' : 'proveedores'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Desactivados',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: inactivos
                            ? Colores.advertencia
                            : Colores.tintaSuave,
                        fontWeight: inactivos
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    Switch(
                      value: inactivos,
                      onChanged: (v) =>
                          ref.read(verInactivosProvider.notifier).state = v,
                      activeThumbColor: Colores.advertencia,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: estado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, pila) => AppVacio(
                icono: Icons.wifi_off_outlined,
                titulo: 'No se pudo cargar',
                detalle: e is ApiExcepcion
                    ? e.texto
                    : 'No pudimos cargar los proveedores.',
                accion: FilledButton.icon(
                  onPressed: () =>
                      ref.read(proveedoresProvider.notifier).recargar(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ),
              data: (lista) => visibles.isEmpty
                  ? AppVacio(
                      icono: Icons.business_outlined,
                      titulo: inactivos
                          ? 'No hay proveedores desactivados'
                          : 'Sin proveedores',
                      detalle: busqueda.isEmpty
                          ? 'Registra el primero con el botón de abajo.'
                          : 'Ninguno coincide con lo que buscaste.',
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(proveedoresProvider.notifier).recargar(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Dimen.espacio4,
                          0,
                          Dimen.espacio4,
                          Dimen.espacio6 * 2,
                        ),
                        itemCount: visibles.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: Dimen.espacio2),
                        itemBuilder: (context, i) => _TarjetaProveedor(
                          proveedor: visibles[i],
                          color: color,
                          onTap: () => _abrirFormulario(context, visibles[i]),
                          onEstado: () =>
                              _cambiarEstado(context, ref, visibles[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Proveedor? proveedor) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProveedorFormulario(proveedor: proveedor),
      ),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Proveedor proveedor,
  ) async {
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(proveedoresProvider.notifier).cambiarEstado(proveedor);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            proveedor.activo
                ? '${proveedor.nombre} desactivado'
                : '${proveedor.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaProveedor extends StatelessWidget {
  const _TarjetaProveedor({
    required this.proveedor,
    required this.color,
    required this.onTap,
    required this.onEstado,
  });

  final Proveedor proveedor;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onEstado;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioPanel),
      child: Container(
        padding: const EdgeInsets.all(Dimen.espacio3),
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioPanel),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Icon(Icons.business_outlined, size: 19, color: color),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proveedor.nombreComercial?.isNotEmpty == true
                        ? proveedor.nombreComercial!
                        : proveedor.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (proveedor.nombreComercial?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      proveedor.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colores.tintaSuave,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    proveedor.telefono ?? proveedor.direccion ?? 'Sin contacto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colores.tintaSuave,
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppEtiqueta(
                        '${proveedor.tipoDoc} ${proveedor.documento}',
                      ),
                      if (proveedor.rubro != null)
                        AppEtiqueta(
                          proveedor.rubro!,
                          tono: EtiquetaTono.modulo,
                          color: color,
                        ),
                      if (!proveedor.activo)
                        const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEstado,
              tooltip: proveedor.activo ? 'Desactivar' : 'Activar',
              icon: Icon(
                proveedor.activo ? Icons.block : Icons.check_circle_outline,
                size: 19,
                color: proveedor.activo ? Colores.advertencia : Colores.exito,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
