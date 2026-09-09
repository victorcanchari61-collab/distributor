import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/flota.dart';
import '../estado/tms_controlador.dart';

/// Los tipos de vehículo: camión, furgoneta, moto.
///
/// Es catálogo y no una lista fija en el código porque cada distribuidora
/// reparte con lo que tiene; con una lista fija, añadir "moto de tres ruedas"
/// obligaría a publicar una versión nueva de la app.
class TiposVehiculoPagina extends ConsumerWidget {
  const TiposVehiculoPagina({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(tiposVehiculoProvider);

    return Acento.modulo(
      'tms',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tipos de vehículo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirHoja(context, ref, null),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo tipo'),
        ),
        body: estado.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Dimen.espacio4),
              child: AppAlerta(e is ApiExcepcion ? e.texto : 'No pudimos cargar los tipos.'),
            ),
          ),
          data: (tipos) => tipos.isEmpty
              ? const AppVacio(
                  icono: Icons.category_outlined,
                  titulo: 'Todavía no hay tipos',
                  detalle: 'Crea al menos uno para poder dar de alta vehículos.',
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(tiposVehiculoProvider.notifier).recargar(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Dimen.espacio4),
                    itemCount: tipos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Dimen.espacio3),
                    itemBuilder: (_, i) => _Tarjeta(
                      tipo: tipos[i],
                      onEditar: () => _abrirHoja(context, ref, tipos[i]),
                      onEliminar: () => _eliminar(context, ref, tipos[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _abrirHoja(BuildContext context, WidgetRef ref, TipoVehiculo? tipo) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.superficie,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (_) => _HojaTipo(tipo: tipo),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, TipoVehiculo tipo) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${tipo.nombre}',
      mensaje: tipo.vehiculos > 0
          ? 'Hay ${tipo.vehiculos} vehículo(s) de este tipo, así que no se podrá eliminar. '
                'Desactívalo en su lugar.'
          : 'Se borra definitivamente.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(tiposVehiculoProvider.notifier).eliminar(tipo.id);
      mensajero.showSnackBar(SnackBar(content: Text('${tipo.nombre} eliminado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.tipo, required this.onEditar, required this.onEliminar});

  final TipoVehiculo tipo;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.category_outlined,
      color: Acento.de(context),
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
          widget: AppEtiqueta(
            tipo.activo ? 'Activo' : 'Inactivo',
            tono: tipo.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
          ),
        ),
      ],
      onTap: onEditar,
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
        ),
        IconButton(
          onPressed: onEliminar,
          tooltip: 'Eliminar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
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
  late final _descripcion = TextEditingController(text: widget.tipo?.descripcion ?? '');
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
    final mensajero = ScaffoldMessenger.of(context);

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
      mensajero.showSnackBar(
        SnackBar(content: Text(widget.tipo == null ? 'Tipo creado' : 'Tipo actualizado')),
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
            widget.tipo == null ? 'Nuevo tipo de vehículo' : 'Editar ${widget.tipo!.nombre}',
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
            onChanged: _guardando ? null : (v) => setState(() => _activo = v ?? true),
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
