import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/catalogo.dart';
import '../estado/maestros_controlador.dart';

/// Recarga las unidades y espera la lista nueva.
Future<void> _recargar(WidgetRef ref) async {
  ref.invalidate(unidadesProvider);
  try {
    await ref.read(unidadesProvider.future);
  } catch (_) {
    // El fallo ya se ve en la pantalla, con su botón de reintentar.
  }
}

/// Las unidades de medida, como pestaña de Productos.
///
/// Lista propia y no `AppCatalogoSimple` porque una unidad tiene código, tipo
/// y si admite decimales: es `UnidadesTabla` del panel web. Como allá, se
/// crean, se editan y se eliminan mientras nada las use; activarlas o
/// desactivarlas no se ofrece en la web y tampoco aquí.
class UnidadesPestana extends ConsumerWidget {
  const UnidadesPestana({
    super.key,
    required this.titulo,
    required this.ruta,
    this.pestanas,
  });

  /// El título de la pantalla que la contiene ("Productos").
  final String titulo;
  final String ruta;
  final Widget? pestanas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(unidadesProvider);
    final todas = estado.valueOrNull ?? const <UnidadMedida>[];
    final activas = todas.where((u) => u.activo).length;
    final busqueda = ref.watch(busquedaUnidadesProvider);
    final puestos = ref.watch(filtrosUnidadesActivosProvider);
    final puedeEditar = puede(ref, 'maestros.productos', Accion.editar);
    final puedeEliminar = puede(ref, 'maestros.productos', Accion.eliminar);

    return AppListaPagina<UnidadMedida>(
      titulo: titulo,
      ruta: ruta,
      pestanas: pestanas,
      estado: estado,
      visibles: ref.watch(unidadesFiltradasProvider),
      busqueda: busqueda,
      onBuscar: (t) => ref.read(busquedaUnidadesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar unidad',
      onRecargar: () => _recargar(ref),
      onNuevo: puede(ref, 'maestros.productos', Accion.crear)
          ? () => _abrirHoja(context, color)
          : null,
      textoNuevo: 'Nueva unidad',
      iconoVacio: Icons.straighten_outlined,
      singular: 'unidad',
      plural: 'unidades',
      detalleVacio: puestos > 0
          ? 'Ninguna coincide con los filtros puestos.'
          : busqueda.isNotEmpty
          ? 'Ninguna coincide con lo que buscaste.'
          : 'Registra la primera con el botón de abajo.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Activas',
          valor: '$activas',
          icono: Icons.straighten_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Desactivadas',
          valor: '${todas.length - activas}',
          icono: Icons.block,
          tono: DatoTono.neutral,
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, u) => _TarjetaUnidad(
        unidad: u,
        color: color,
        onEditar: puedeEditar ? () => _abrirHoja(context, color, u) : null,
        // Solo las que se pueden borrar: las del sistema y las que ya se usan
        // el backend las rechaza.
        onEliminar: puedeEliminar && u.usos == 0 && !u.delSistema
            ? () => _eliminar(context, ref, u)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosUnidadesActivosProvider),
      onLimpiar: () {
        ref.read(tipoUnidadFiltroProvider.notifier).state = null;
        ref.read(fraccionableFiltroProvider.notifier).state = null;
        ref.read(activoUnidadFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Tipo',
            valor: ref.watch(tipoUnidadFiltroProvider),
            opciones: [
              const OpcionFiltro(null, 'Todos'),
              for (final t in TipoUnidad.todos)
                OpcionFiltro(t, TipoUnidad.etiqueta(t)),
            ],
            onCambio: (v) =>
                ref.read(tipoUnidadFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<bool?>(
            titulo: 'Admite decimales',
            valor: ref.watch(fraccionableFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(true, 'Sí'),
              OpcionFiltro(false, 'No'),
            ],
            onCambio: (v) =>
                ref.read(fraccionableFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<bool?>(
            titulo: 'Estado',
            valor: ref.watch(activoUnidadFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(true, 'Activas'),
              OpcionFiltro(false, 'Desactivadas'),
            ],
            onCambio: (v) =>
                ref.read(activoUnidadFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirHoja(
    BuildContext context,
    Color color, [
    UnidadMedida? editando,
  ]) {
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
      // La hoja cuelga del Navigator y no hereda el acento de la vista.
      builder: (_) => Acento(
        color: color,
        child: _HojaUnidad(editando: editando),
      ),
    );
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    UnidadMedida u,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${u.nombre}',
      mensaje: 'Se borra definitivamente.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(maestrosApiProvider).eliminarUnidad(u.id);
      await _recargar(ref);
      mensajero.mostrar('${u.nombre} eliminada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaUnidad extends StatelessWidget {
  const _TarjetaUnidad({
    required this.unidad,
    required this.color,
    this.onEditar,
    this.onEliminar,
  });

  final UnidadMedida unidad;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final u = unidad;
    return AppTarjetaRegistro(
      icono: Icons.straighten_outlined,
      color: color,
      titulo: u.nombre,
      // El código es el que sale impreso: identifica a la unidad.
      insignia: AppEtiqueta(u.codigo),
      campos: [
        CampoDetalle(
          'Tipo',
          TipoUnidad.etiqueta(u.tipo),
          widget: AppEtiqueta(
            TipoUnidad.etiqueta(u.tipo),
            tono: EtiquetaTono.modulo,
            color: color,
          ),
        ),
        CampoDetalle('Admite decimales', u.fraccionable ? 'Sí' : 'No'),
        CampoDetalle('En uso', '${u.usos}'),
      ],
      estado: AppEtiqueta(
        u.activo ? 'Activo' : 'Inactivo',
        tono: u.activo ? EtiquetaTono.exito : EtiquetaTono.neutral,
      ),
      acciones: [
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
        if (onEliminar != null)
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Colores.advertencia,
            ),
          ),
      ],
    );
  }
}

/// Crear o editar una unidad: código, nombre, tipo y si admite decimales.
class _HojaUnidad extends ConsumerStatefulWidget {
  const _HojaUnidad({this.editando});

  final UnidadMedida? editando;

  @override
  ConsumerState<_HojaUnidad> createState() => _HojaUnidadState();
}

class _HojaUnidadState extends ConsumerState<_HojaUnidad> {
  late final _codigo = TextEditingController(
    text: widget.editando?.codigo ?? '',
  );
  late final _nombre = TextEditingController(
    text: widget.editando?.nombre ?? '',
  );
  late String _tipo = widget.editando?.tipo ?? TipoUnidad.conteo;
  late bool _fraccionable = widget.editando?.fraccionable ?? false;
  bool _guardando = false;
  String? _error;

  /// El código se escribe en mayúsculas, como sale impreso: el backend igual
  /// lo guarda así.
  static final _mayusculas = TextInputFormatter.withFunction(
    (anterior, nuevo) => nuevo.copyWith(text: nuevo.text.toUpperCase()),
  );

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigo.text.trim().toUpperCase();
    final nombre = _nombre.text.trim();
    final error = codigo.isEmpty
        ? 'Ingresa el código.'
        : nombre.isEmpty
        ? 'Ingresa el nombre.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);
    final api = ref.read(maestrosApiProvider);
    final editando = widget.editando;
    final cuerpo = {
      'codigo': codigo,
      'nombre': nombre,
      'tipo': _tipo,
      'fraccionable': _fraccionable,
    };

    try {
      if (editando == null) {
        await api.crearUnidad(cuerpo);
      } else {
        // El estado no se toca al editar: se conserva el que tenía.
        await api.actualizarUnidad(editando.id, {
          ...cuerpo,
          'activo': editando.activo,
        });
      }
      ref.invalidate(unidadesProvider);
      navegador.pop();
      mensajero.mostrar(editando == null ? 'Unidad creada' : 'Unidad guardada');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editando == null ? 'Nueva unidad' : 'Editar ${editando.nombre}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'El código es el que sale impreso en los documentos.',
              style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: AppCampo(
                    controlador: _codigo,
                    etiqueta: 'Código',
                    pista: 'SAC',
                    maxLargo: 10,
                    formateadores: [_mayusculas],
                    habilitado: !_guardando,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: AppCampo(
                    controlador: _nombre,
                    etiqueta: 'Nombre',
                    pista: 'Saco',
                    maxLargo: 60,
                    habilitado: !_guardando,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            AppSelector<String>(
              valor: _tipo,
              etiqueta: 'Tipo',
              icono: Icons.straighten_outlined,
              habilitado: !_guardando,
              opciones: [
                for (final t in TipoUnidad.todos)
                  Opcion(t, TipoUnidad.etiqueta(t)),
              ],
              onCambio: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                TipoUnidad.nota(_tipo),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colores.tintaSuave,
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio2),
            CheckboxListTile(
              value: _fraccionable,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Admite decimales',
                style: TextStyle(fontSize: 13.5),
              ),
              subtitle: const Text(
                '2.5 kilos sí, 2.5 sacos no.',
                style: TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
              ),
              onChanged: _guardando
                  ? null
                  : (v) => setState(() => _fraccionable = v ?? false),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppBoton(
              texto: editando == null ? 'Crear unidad' : 'Guardar cambios',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
