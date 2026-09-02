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
import '../datos/cliente.dart';
import '../estado/maestros_controlador.dart';
import 'cliente_formulario.dart';

/// Listado de clientes.
class ClientesPagina extends ConsumerWidget {
  const ClientesPagina({super.key});

  static const ruta = '/maestros/clientes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupo = resolverRuta(ruta).grupo;
    final estado = ref.watch(clientesProvider);
    final visibles = ref.watch(clientesFiltradosProvider);
    final inactivos = ref.watch(verInactivosProvider);

    return AppShell(
      titulo: 'Clientes',
      subtitulo: grupo?.titulo,
      acentado: grupo?.color,
      rutaActual: ruta,
      accionFlotante: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, null),
        backgroundColor: grupo?.color ?? Colores.marca,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      child: Column(
        children: [
          _Filtros(
            total: visibles.length,
            viendoInactivos: inactivos,
            onBuscar: (t) =>
                ref.read(busquedaClientesProvider.notifier).state = t,
            busqueda: ref.watch(busquedaClientesProvider),
            onCambiarEstado: (v) =>
                ref.read(verInactivosProvider.notifier).state = v,
          ),
          Expanded(
            child: estado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, pila) => _Error(
                mensaje: e is ApiExcepcion
                    ? e.texto
                    : 'No pudimos cargar los clientes.',
                onReintentar: () =>
                    ref.read(clientesProvider.notifier).recargar(),
              ),
              data: (lista) => visibles.isEmpty
                  ? AppVacio(
                      icono: Icons.contacts_outlined,
                      titulo: inactivos
                          ? 'No hay clientes desactivados'
                          : 'Sin clientes',
                      detalle: ref.watch(busquedaClientesProvider).isEmpty
                          ? 'Registra el primero con el botón de abajo.'
                          : 'Ninguno coincide con lo que buscaste.',
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(clientesProvider.notifier).recargar(),
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
                        itemBuilder: (context, i) => _TarjetaCliente(
                          cliente: visibles[i],
                          color: grupo?.color ?? Colores.marca,
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

  Future<void> _abrirFormulario(BuildContext context, Cliente? cliente) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClienteFormulario(cliente: cliente)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Cliente cliente,
  ) async {
    // Igual que en el panel web: desactivar nunca ocurre de un toque, primero
    // se avisa que pasa con el registro.
    final ok = await confirmarAccion(
      context,
      titulo: '${cliente.activo ? 'Desactivar' : 'Activar'} ${cliente.nombre}',
      mensaje: cliente.activo
          ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: cliente.activo ? 'Desactivar' : 'Activar',
      tono: cliente.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(clientesProvider.notifier).cambiarEstado(cliente);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            cliente.activo
                ? '${cliente.nombre} desactivado'
                : '${cliente.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.total,
    required this.busqueda,
    required this.viendoInactivos,
    required this.onBuscar,
    required this.onCambiarEstado,
  });

  final int total;
  final String busqueda;
  final bool viendoInactivos;
  final ValueChanged<String> onBuscar;
  final ValueChanged<bool> onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimen.espacio4),
      child: Column(
        children: [
          AppBuscador(
            valor: busqueda,
            onCambio: onBuscar,
            pista: 'Buscar por nombre, documento o mercado',
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              // Flexible: el conteo cede espacio antes que empujar al
              // interruptor fuera de la fila.
              Flexible(
                child: Text(
                  '$total ${total == 1 ? 'cliente' : 'clientes'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colores.tintaSuave,
                  ),
                ),
              ),
              const Spacer(),
              // Interruptor en vez de dos pestañas: ocupa menos y deja claro
              // que se esta viendo una lista distinta.
              Text(
                'Desactivados',
                style: TextStyle(
                  fontSize: 12.5,
                  color: viendoInactivos
                      ? Colores.advertencia
                      : Colores.tintaSuave,
                  fontWeight: viendoInactivos
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              Switch(
                value: viendoInactivos,
                onChanged: onCambiarEstado,
                activeThumbColor: Colores.advertencia,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({
    required this.cliente,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Cliente cliente;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  /// Los mismos datos que muestra la tabla del panel web, en el mismo orden.
  /// Los marcados `enTarjeta: false` solo salen en la ficha de detalle: en el
  /// listado estorban y hacen que entren menos registros en pantalla.
  List<CampoDetalle> get _campos => [
    CampoDetalle('Nombre', cliente.nombre),
    CampoDetalle('Direccion', cliente.direccion),
    CampoDetalle('Distrito', cliente.distrito, enTarjeta: false),
    CampoDetalle('Telefono', cliente.telefono, enTarjeta: false),
    CampoDetalle(
      'Dia visita',
      cliente.diaVisita,
      widget: cliente.diaVisita == null
          ? null
          : AppEtiqueta(
              cliente.diaVisita!,
              tono: EtiquetaTono.modulo,
              color: color,
            ),
    ),
    CampoDetalle('Ruta', cliente.ruta, enTarjeta: false),
    CampoDetalle('Mercado', cliente.mercado, enTarjeta: false),
    CampoDetalle(
      'Estado',
      cliente.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        cliente.activo ? 'Activo' : 'Inactivo',
        tono: cliente.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.storefront_outlined,
      color: color,
      titulo: cliente.documento,
      insignia: AppEtiqueta(cliente.tipoDoc),
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
          tooltip: cliente.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            cliente.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: cliente.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.storefront_outlined,
      color: color,
      titulo: cliente.nombre,
      subtitulo: '${cliente.tipoDoc} ${cliente.documento}',
      insignia: cliente.activo
          ? null
          : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        AppBoton(
          texto: cliente.activo ? 'Desactivar' : 'Activar',
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

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => AppVacio(
    icono: Icons.wifi_off_outlined,
    titulo: 'No se pudo cargar',
    detalle: mensaje,
    accion: FilledButton.icon(
      onPressed: onReintentar,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reintentar'),
    ),
  );
}
