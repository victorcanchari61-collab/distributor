import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/flota.dart';
import '../estado/tms_controlador.dart';
import 'flota_pagina.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Los tipos de vehículo: camión, furgoneta, moto. Son la segunda pestaña de
/// Flota, como en el panel web, y no una pantalla aparte.
///
/// Es catálogo y no una lista fija en el código porque cada distribuidora
/// reparte con lo que tiene; con una lista fija, añadir "moto de tres ruedas"
/// obligaría a publicar una versión nueva de la app.
class TiposVehiculoPestana extends ConsumerWidget {
  const TiposVehiculoPestana({super.key, required this.pestanas});

  /// Las pestañas de Flota, que van arriba de todo.
  final Widget pestanas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(FlotaPagina.ruta).grupo?.color ?? Colores.marca;
    final busqueda = ref.watch(busquedaTiposVehiculoProvider);
    final filtros =
        ref.watch(estadoTiposVehiculoFiltroProvider) == FiltroEstado.todos
        ? 0
        : 1;
    final puedeEditar = puede(ref, 'tms.flota', Accion.editar);

    return AppListaPagina<TipoVehiculo>(
      titulo: 'Flota',
      ruta: FlotaPagina.ruta,
      pestanas: pestanas,
      estado: ref.watch(tiposVehiculoProvider),
      visibles: ref.watch(tiposVehiculoFiltradosProvider),
      busqueda: busqueda,
      onBuscar: (t) =>
          ref.read(busquedaTiposVehiculoProvider.notifier).state = t,
      pistaBusqueda: 'Buscar tipo',
      onRecargar: () => ref.read(tiposVehiculoProvider.notifier).recargar(),
      onNuevo: puede(ref, 'tms.flota', Accion.crear)
          ? () => _abrirHoja(context, null)
          : null,
      textoNuevo: 'Nuevo tipo',
      iconoVacio: Icons.build_outlined,
      singular: 'tipo',
      plural: 'tipos',
      tituloVacio: 'Sin tipos de vehículo',
      detalleVacio: busqueda.isEmpty && filtros == 0
          ? 'Crea al menos uno para poder dar de alta vehículos.'
          : 'Ninguno coincide con lo que buscaste.',
      filtro: BotonFiltros(
        activos: filtros,
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: filtros,
          onLimpiar: () =>
              ref.read(estadoTiposVehiculoFiltroProvider.notifier).state =
                  FiltroEstado.todos,
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<FiltroEstado>(
                titulo: 'Estado',
                valor: ref.watch(estadoTiposVehiculoFiltroProvider),
                opciones: const [
                  OpcionFiltro(FiltroEstado.todos, 'Todos'),
                  OpcionFiltro(FiltroEstado.activos, 'Activos'),
                  OpcionFiltro(FiltroEstado.inactivos, 'Desactivados'),
                ],
                onCambio: (v) =>
                    ref.read(estadoTiposVehiculoFiltroProvider.notifier).state =
                        v,
              ),
            ),
          ],
        ),
      ),
      fila: (context, tipo) => _Tarjeta(
        tipo: tipo,
        color: color,
        onVer: () => _verDetalle(context, tipo, color),
        onEditar: puedeEditar ? () => _abrirHoja(context, tipo) : null,
        onEstado: puedeEditar ? () => _cambiarEstado(context, ref, tipo) : null,
      ),
    );
  }

  Future<void> _abrirHoja(BuildContext context, TipoVehiculo? tipo) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.superficie,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      // La hoja cuelga del Navigator y no hereda el acento del modulo.
      builder: (_) => Acento.modulo('tms', (_) => _HojaTipo(tipo: tipo)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    TipoVehiculo tipo,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${tipo.activo ? 'Desactivar' : 'Activar'} ${tipo.nombre}',
      mensaje: tipo.activo
          ? 'Deja de ofrecerse al dar de alta vehículos nuevos. Los '
                '${tipo.vehiculos} que ya son de este tipo lo conservan.'
          : 'Vuelve a estar disponible para elegirse.',
      textoConfirmar: tipo.activo ? 'Desactivar' : 'Activar',
      tono: tipo.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      // El PUT reemplaza el registro entero, asi que se reenvia lo que ya
      // tenia: mandar solo `activo` vaciaria el nombre y la descripcion.
      await ref
          .read(tiposVehiculoProvider.notifier)
          .guardar(
            id: tipo.id,
            cuerpo: {
              'nombre': tipo.nombre,
              'descripcion': tipo.descripcion,
              'capacidadKgReferencia': tipo.capacidadKgReferencia,
              'activo': !tipo.activo,
            },
          );
      mensajero.mostrar(
        tipo.activo ? '${tipo.nombre} desactivado' : '${tipo.nombre} activado',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  /// Ficha de solo lectura.
  ///
  /// Existe para poder consultar el tipo sin abrir la hoja de edicion, donde
  /// un toque de mas guarda cambios que nadie queria hacer.
  Future<void> _verDetalle(
    BuildContext context,
    TipoVehiculo tipo,
    Color color,
  ) {
    return mostrarDetalle(
      context,
      icono: Icons.build_outlined,
      color: color,
      titulo: tipo.nombre,
      subtitulo: tipo.descripcion,
      estado: insigniaActivo(tipo.activo),
      campos: [
        CampoDetalle('Nombre', tipo.nombre),
        CampoDetalle('Descripción', tipo.descripcion),
        CampoDetalle(
          'Capacidad de referencia',
          tipo.capacidadKgReferencia == null
              ? null
              : '${formatoNumero(tipo.capacidadKgReferencia!)} kg',
        ),
        CampoDetalle('Vehículos', '${tipo.vehiculos}'),
        CampoDetalle(
          'Estado',
          tipo.activo ? 'Activo' : 'Inactivo',
          widget: insigniaActivo(tipo.activo),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.tipo,
    required this.color,
    required this.onVer,
    this.onEditar,
    this.onEstado,
  });

  final TipoVehiculo tipo;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.build_outlined,
      color: color,
      titulo: tipo.nombre,
      campos: [
        CampoDetalle('Descripción', tipo.descripcion),
        if (tipo.capacidadKgReferencia != null)
          CampoDetalle(
            'Capacidad de referencia',
            '${formatoNumero(tipo.capacidadKgReferencia!)} kg',
          ),
        CampoDetalle('Vehículos', '${tipo.vehiculos}'),
        CampoDetalle(
          'Estado',
          tipo.activo ? 'Activo' : 'Inactivo',
          widget: insigniaActivo(tipo.activo),
        ),
      ],
      onTap: onVer,
      acciones: [
        IconButton(
          onPressed: onVer,
          tooltip: 'Ver detalle',
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.visibility_outlined,
            size: 18,
            color: Colores.tintaSuave,
          ),
        ),
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
        if (onEstado != null)
          IconButton(
            onPressed: onEstado,
            tooltip: tipo.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              tipo.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: tipo.activo ? Colores.advertencia : Colores.exito,
            ),
          ),
      ],
    );
  }
}

/// Alta y edición de un tipo. Son cuatro campos: cabe en una hoja.
class _HojaTipo extends ConsumerStatefulWidget {
  const _HojaTipo({this.tipo});

  final TipoVehiculo? tipo;

  @override
  ConsumerState<_HojaTipo> createState() => _HojaTipoState();
}

class _HojaTipoState extends ConsumerState<_HojaTipo> {
  late final _nombre = TextEditingController(text: widget.tipo?.nombre ?? '');
  late final _descripcion = TextEditingController(
    text: widget.tipo?.descripcion ?? '',
  );
  late final _capacidad = TextEditingController(
    text: widget.tipo?.capacidadKgReferencia == null
        ? ''
        : formatoNumero(widget.tipo!.capacidadKgReferencia!),
  );

  late bool _activo = widget.tipo?.activo ?? true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Ponle un nombre al tipo.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(tiposVehiculoProvider.notifier)
          .guardar(
            id: widget.tipo?.id,
            cuerpo: {
              'nombre': _nombre.text.trim(),
              'descripcion': _descripcion.text.trim().isEmpty
                  ? null
                  : _descripcion.text.trim(),
              'capacidadKgReferencia': double.tryParse(
                _capacidad.text.replaceAll(',', '.'),
              ),
              'activo': _activo,
            },
          );

      navegador.pop();
      mensajero.mostrar(
        widget.tipo == null ? 'Tipo creado' : 'Tipo actualizado',
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        top: Dimen.espacio2,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.tipo == null
                ? 'Nuevo tipo de vehículo'
                : 'Editar ${widget.tipo!.nombre}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio4),

          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],

          AppCampo(
            controlador: _nombre,
            etiqueta: 'Nombre',
            pista: 'Camión, furgoneta, moto...',
            icono: Icons.category_outlined,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampo(
            controlador: _descripcion,
            etiqueta: 'Descripción',
            icono: Icons.notes_outlined,
            opcional: true,
            maxLargo: 250,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampo(
            controlador: _capacidad,
            etiqueta: 'Capacidad de referencia (kg)',
            pista: 'Se propone al dar de alta un vehículo de este tipo',
            icono: Icons.scale_outlined,
            opcional: true,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio2),

          CheckboxListTile(
            value: _activo,
            onChanged: _guardando
                ? null
                : (v) => setState(() => _activo = v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Si se desactiva, deja de ofrecerse al dar de alta vehículos.',
              style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ),
          const SizedBox(height: Dimen.espacio3),

          AppBoton(texto: 'Guardar', cargando: _guardando, onPressed: _guardar),
        ],
      ),
    );
  }
}
