import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/red/excepciones.dart';
import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_alerta.dart';
import 'app_aviso.dart';
import 'app_boton.dart';
import 'app_campo.dart';
import 'app_confirmacion.dart';
import 'app_etiqueta.dart';
import 'app_lista_pagina.dart';
import 'app_tarjeta_dato.dart';
import 'app_tarjeta_registro.dart';

/// Lo mínimo de una fila de catálogo simple: categorías, marcas, bancos.
class FilaCatalogo {
  const FilaCatalogo({
    required this.id,
    required this.nombre,
    required this.activo,
    this.descripcion,
    this.usos = 0,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  /// Cuántos registros lo usan (productos, cuentas). Con usos no se elimina.
  final int usos;
}

/// Un catálogo de nombre y poco más, como pestaña de otra vista: las
/// categorías y marcas dentro de Productos, los bancos dentro de Bancos.
///
/// Es el mismo componente que `CatalogoSimple` del panel web: si el diseño de
/// estas listas cambia, se cambia aquí. Se busca por nombre, se crea y edita en
/// una hoja, se activa o desactiva, y se elimina solo si nadie lo usa.
class AppCatalogoSimple extends StatefulWidget {
  const AppCatalogoSimple({
    super.key,
    required this.titulo,
    required this.ruta,
    required this.estado,
    required this.singular,
    required this.plural,
    required this.icono,
    required this.onRecargar,
    required this.onCrear,
    required this.onActualizar,
    this.onEliminar,
    this.pestanas,
    this.femenino = true,
    this.conDescripcion = false,
    this.usosEtiqueta = 'Productos',
    this.puedeCrear = true,
    this.puedeEditar = true,
    this.puedeEliminar = true,
  });

  /// El título de la pantalla (el de la vista que lo contiene: "Productos").
  final String titulo;
  final String ruta;
  final AsyncValue<List<FilaCatalogo>> estado;

  /// "categoría", "categorías": para los textos.
  final String singular;
  final String plural;
  final IconData icono;
  final Widget? pestanas;

  /// "Nueva categoría", "Activas"; en falso "Nuevo banco", "Activos".
  final bool femenino;

  /// Muestra y edita la descripción. Las marcas y los bancos no la tienen.
  final bool conDescripcion;

  /// Cómo se llama lo que lo usa: "Productos", "Cuentas".
  final String usosEtiqueta;

  final Future<void> Function() onRecargar;
  final Future<void> Function(Map<String, dynamic> cuerpo) onCrear;
  final Future<void> Function(int id, Map<String, dynamic> cuerpo) onActualizar;

  /// Null si el catálogo no se elimina (solo se desactiva).
  final Future<void> Function(int id)? onEliminar;

  final bool puedeCrear;
  final bool puedeEditar;
  final bool puedeEliminar;

  @override
  State<AppCatalogoSimple> createState() => _AppCatalogoSimpleState();
}

class _AppCatalogoSimpleState extends State<AppCatalogoSimple> {
  String _busqueda = '';

  Map<String, dynamic> _cuerpo(FilaCatalogo f, {required bool activo}) => {
    'nombre': f.nombre,
    if (widget.conDescripcion) 'descripcion': f.descripcion,
    'activo': activo,
  };

  Future<void> _abrirHoja([FilaCatalogo? editando]) {
    final acento = Acento.de(context);
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
        color: acento,
        child: _HojaCatalogo(
          editando: editando,
          singular: widget.singular,
          femenino: widget.femenino,
          conDescripcion: widget.conDescripcion,
          onGuardar: (cuerpo) async {
            if (editando == null) {
              await widget.onCrear(cuerpo);
            } else {
              await widget.onActualizar(editando.id, {
                ...cuerpo,
                'activo': editando.activo,
              });
            }
            await widget.onRecargar();
          },
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(FilaCatalogo f) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${f.activo ? 'Desactivar' : 'Activar'} ${f.nombre}',
      mensaje: f.activo
          ? 'Deja de ofrecerse al registrar. Lo que ya la usa la conserva.'
          : 'Vuelve a estar disponible.',
      textoConfirmar: f.activo ? 'Desactivar' : 'Activar',
      tono: f.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await widget.onActualizar(f.id, _cuerpo(f, activo: !f.activo));
      await widget.onRecargar();
      mensajero.mostrar(f.activo ? 'Desactivado' : 'Activado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _eliminar(FilaCatalogo f) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${f.nombre}',
      mensaje: 'Se borra definitivamente.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await widget.onEliminar!(f.id);
      await widget.onRecargar();
      mensajero.mostrar('Eliminado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todas = widget.estado.valueOrNull ?? const <FilaCatalogo>[];
    final activas = todas.where((f) => f.activo).length;
    final texto = _busqueda.trim().toLowerCase();
    final visibles = todas
        .where(
          (f) =>
              texto.isEmpty ||
              '${f.nombre} ${f.descripcion ?? ''}'.toLowerCase().contains(
                texto,
              ),
        )
        .toList();
    final acento = Acento.de(context);

    return AppListaPagina<FilaCatalogo>(
      titulo: widget.titulo,
      ruta: widget.ruta,
      pestanas: widget.pestanas,
      estado: widget.estado,
      visibles: visibles,
      busqueda: _busqueda,
      onBuscar: (t) => setState(() => _busqueda = t),
      pistaBusqueda: 'Buscar ${widget.singular}',
      onRecargar: widget.onRecargar,
      onNuevo: widget.puedeCrear ? () => _abrirHoja() : null,
      textoNuevo: '${widget.femenino ? 'Nueva' : 'Nuevo'} ${widget.singular}',
      iconoVacio: widget.icono,
      singular: widget.singular,
      plural: widget.plural,
      indicadores: [
        AppTarjetaDato(
          etiqueta: widget.femenino ? 'Activas' : 'Activos',
          valor: '$activas',
          icono: widget.icono,
          color: acento,
        ),
        AppTarjetaDato(
          etiqueta: widget.femenino ? 'Desactivadas' : 'Desactivados',
          valor: '${todas.length - activas}',
          icono: Icons.block,
          tono: DatoTono.neutral,
        ),
      ],
      fila: (context, f) => AppTarjetaRegistro(
        icono: widget.icono,
        color: acento,
        titulo: f.nombre,
        insignia: AppEtiqueta(
          f.activo ? 'Activo' : 'Inactivo',
          tono: f.activo ? EtiquetaTono.exito : EtiquetaTono.neutral,
        ),
        campos: [
          if (widget.conDescripcion) CampoDetalle('Descripción', f.descripcion),
          CampoDetalle(widget.usosEtiqueta, '${f.usos}'),
        ],
        acciones: [
          if (widget.puedeEditar)
            IconButton(
              onPressed: () => _abrirHoja(f),
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.edit_outlined, size: 18, color: acento),
            ),
          if (widget.puedeEditar)
            IconButton(
              onPressed: () => _cambiarEstado(f),
              tooltip: f.activo ? 'Desactivar' : 'Activar',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                f.activo ? Icons.block : Icons.check_circle_outline,
                size: 18,
                color: Colores.advertencia,
              ),
            ),
          // Solo sin usos: lo que ya se usa se desactiva, no se borra.
          if (widget.onEliminar != null && widget.puedeEliminar && f.usos == 0)
            IconButton(
              onPressed: () => _eliminar(f),
              tooltip: 'Eliminar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colores.advertencia,
              ),
            ),
        ],
      ),
    );
  }
}

class _HojaCatalogo extends StatefulWidget {
  const _HojaCatalogo({
    required this.editando,
    required this.singular,
    required this.femenino,
    required this.conDescripcion,
    required this.onGuardar,
  });

  final FilaCatalogo? editando;
  final String singular;
  final bool femenino;
  final bool conDescripcion;
  final Future<void> Function(Map<String, dynamic> cuerpo) onGuardar;

  @override
  State<_HojaCatalogo> createState() => _HojaCatalogoState();
}

class _HojaCatalogoState extends State<_HojaCatalogo> {
  late final _nombre = TextEditingController(
    text: widget.editando?.nombre ?? '',
  );
  late final _descripcion = TextEditingController(
    text: widget.editando?.descripcion ?? '',
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el nombre.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await widget.onGuardar({
        'nombre': _nombre.text.trim(),
        if (widget.conDescripcion)
          'descripcion': _descripcion.text.trim().isEmpty
              ? null
              : _descripcion.text.trim(),
      });
      navegador.pop();
      mensajero.mostrar(widget.editando == null ? 'Creado' : 'Guardado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final singular = widget.singular;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.editando == null
                ? '${widget.femenino ? 'Nueva' : 'Nuevo'} $singular'
                : 'Editar ${widget.editando!.nombre}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimen.espacio4),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          AppCampo(
            controlador: _nombre,
            etiqueta: 'Nombre',
            icono: Icons.label_outline,
            maxLargo: 100,
            habilitado: !_guardando,
          ),
          if (widget.conDescripcion) ...[
            const SizedBox(height: Dimen.espacio3),
            AppCampo(
              controlador: _descripcion,
              etiqueta: 'Descripción',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
          ],
          const SizedBox(height: Dimen.espacio5),
          AppBoton(
            texto: widget.editando == null ? 'Crear' : 'Guardar',
            cargando: _guardando,
            onPressed: _guardar,
          ),
        ],
      ),
    );
  }
}
