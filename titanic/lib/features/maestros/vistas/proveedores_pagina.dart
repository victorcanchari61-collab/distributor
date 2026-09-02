import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
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
                          onEditar: () =>
                              _abrirFormulario(context, visibles[i]),
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
    // Igual que en el panel web: desactivar nunca ocurre de un toque, primero
    // se avisa que pasa con el registro.
    final ok = await confirmarAccion(
      context,
      titulo:
          '${proveedor.activo ? 'Desactivar' : 'Activar'} ${proveedor.nombre}',
      mensaje: proveedor.activo
          ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: proveedor.activo ? 'Desactivar' : 'Activar',
      tono: proveedor.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

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
    required this.onEditar,
    required this.onEstado,
  });

  final Proveedor proveedor;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  /// Mismo criterio que en clientes: en la tarjeta solo lo que sirve para
  /// reconocer al proveedor; el resto vive en la ficha de detalle.
  List<CampoDetalle> get _campos => [
    CampoDetalle('Razon social', proveedor.nombre),
    CampoDetalle(
      'Nombre comercial',
      proveedor.nombreComercial,
      enTarjeta: false,
    ),
    CampoDetalle(
      'Rubro',
      proveedor.rubro,
      widget: proveedor.rubro == null
          ? null
          : AppEtiqueta(
              proveedor.rubro!,
              tono: EtiquetaTono.modulo,
              color: color,
            ),
    ),
    CampoDetalle('Direccion', proveedor.direccion, enTarjeta: false),
    CampoDetalle('Distrito', proveedor.distrito, enTarjeta: false),
    CampoDetalle('Telefono', proveedor.telefono),
    CampoDetalle('Correo', proveedor.email, enTarjeta: false),
    CampoDetalle(
      'Estado',
      proveedor.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        proveedor.activo ? 'Activo' : 'Inactivo',
        tono: proveedor.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.business_outlined,
      color: color,
      titulo: proveedor.documento,
      insignia: AppEtiqueta(proveedor.tipoDoc),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: proveedor.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            proveedor.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: proveedor.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.business_outlined,
      color: color,
      titulo: proveedor.nombreComercial?.isNotEmpty == true
          ? proveedor.nombreComercial!
          : proveedor.nombre,
      subtitulo: '${proveedor.tipoDoc} ${proveedor.documento}',
      insignia: proveedor.activo
          ? null
          : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        AppBoton(
          texto: proveedor.activo ? 'Desactivar' : 'Activar',
          variante: BotonVariante.secundario,
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEstado();
          },
        ),
        AppBoton(
          texto: 'Editar',
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEditar();
          },
        ),
      ],
    );
  }
}
