import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/presentaciones_uso.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/dimensiones.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/solicitud_compra.dart';
import '../estado/compras_controlador.dart';

/// Alta y edición de una solicitud de compra: lo que el almacén pide que se compre. Solo se edita mientras está
/// Pendiente.
///
/// No lleva costos ni proveedor: eso lo pone Compras cuando arma la orden de compra con ella.
class SolicitudCompraFormulario extends ConsumerStatefulWidget {
  const SolicitudCompraFormulario({super.key, this.solicitud});

  /// La solicitud a corregir, ya con sus líneas. Null al crear una.
  final SolicitudCompra? solicitud;

  @override
  ConsumerState<SolicitudCompraFormulario> createState() =>
      _SolicitudCompraFormularioState();
}

class _SolicitudCompraFormularioState
    extends ConsumerState<SolicitudCompraFormulario> {
  late final _observacion = TextEditingController(
    text: widget.solicitud?.observacion ?? '',
  );

  late int? _almacenId = widget.solicitud?.almacenId;
  late String _urgencia =
      widget.solicitud?.urgencia ?? UrgenciaSolicitud.normal;

  final List<LineaDocumento> _lineas = [];

  /// Las líneas de una solicitud que ya existe, una vez que llega el catálogo: necesitan las presentaciones del
  /// producto para poder cambiar de unidad, y esas vienen por red.
  bool _lineasPuestas = false;

  bool _guardando = false;
  bool _trayendo = false;
  String? _error;
  String? _errorAlmacen;
  String? _errorLineas;

  bool get _esNueva => widget.solicitud == null;

  /// Una ya enviada solo se corrige; un borrador se guarda para seguir o se envía.
  bool get _soloCorregir =>
      widget.solicitud != null && !widget.solicitud!.esBorrador;

  void _ponerLineasExistentes(List<Producto> catalogo) {
    final detalle = widget.solicitud?.detalle ?? const <LineaSolicitud>[];
    if (_lineasPuestas || detalle.isEmpty || catalogo.isEmpty) return;
    _lineasPuestas = true;

    final porId = {for (final p in catalogo) p.id: p};
    final nuevas = [
      for (final l in detalle)
        LineaDocumento(
          productoId: l.productoId,
          producto: l.producto,
          codigo: l.codigo,
          unidadBase: l.unidadBase,
          presentaciones:
              porId[l.productoId]?.presentaciones ?? const <Presentacion>[],
          uso: UsoPresentacion.compra,
          presentacionId: l.presentacionId ?? 0,
          cantidad: l.cantidadPresentacion,
          importe: 0,
        ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lineas.addAll(nuevas));
    });
  }

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorAlmacen = _almacenId == null
          ? 'Elige el almacén para el que se pide.'
          : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
    });
    return _errorAlmacen == null && _errorLineas == null;
  }

  /// [enviar] false la deja en borrador (solo la ve quien la pide); true la manda al administrador.
  Future<void> _guardar({required bool enviar}) async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    final cuerpo = <String, dynamic>{
      'almacenId': _almacenId,
      'urgencia': _urgencia,
      'enviar': enviar,
      'observacion': _observacion.text.trim().isEmpty
          ? null
          : _observacion.text.trim(),
      'detalle': [
        for (final f in _lineas)
          {
            'productoId': f.productoId,
            'presentacionId': f.presentacionId == 0 ? null : f.presentacionId,
            'cantidad': f.cantidad,
          },
      ],
    };

    try {
      if (_esNueva) {
        await ref.read(solicitudesCompraProvider.notifier).crear(cuerpo);
      } else {
        await ref
            .read(solicitudesCompraProvider.notifier)
            .actualizar(widget.solicitud!.id, cuerpo);
      }

      navegador.pop();
      mensajero.mostrar(
        enviar
            ? 'Solicitud enviada al administrador'
            : _esNueva
            ? 'Borrador guardado: solo lo ves tú hasta que lo envíes'
            : 'Solicitud actualizada',
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  /// Agrega las líneas elegidas, vengan del panel o de la hoja múltiple. Lo último agregado va arriba: es lo que
  /// hay que mirar y queda justo debajo del buscador.
  void _agregarLineas(List<LineaElegida> elegidas) {
    setState(() {
      _lineas.insertAll(0, [
        for (final e in elegidas)
          LineaDocumento(
            productoId: e.producto.id,
            producto: e.producto.nombre,
            codigo: e.producto.codigo,
            unidadBase: e.producto.unidadBase,
            presentaciones: e.producto.presentaciones,
            uso: UsoPresentacion.compra,
            presentacionId: e.presentacionId,
            cantidad: e.cantidad,
            importe: 0,
          ),
      ]);
      _errorLineas = null;
    });
  }

  /// Trae lo que está bajo el mínimo en el almacén elegido, sin repetir lo que ya está en la lista.
  Future<void> _traerBajoMinimo() async {
    final almacenId = _almacenId;
    if (almacenId == null) {
      setState(() => _errorAlmacen = 'Elige primero el almacén.');
      return;
    }

    final mensajero = Aviso.de(context);
    setState(() => _trayendo = true);

    try {
      final sugeridos = await ref
          .read(comprasApiProvider)
          .sugerenciasSolicitud(almacenId);
      if (!mounted) return;

      final catalogo = {
        for (final p
            in ref.read(productosProvider).valueOrNull ?? const <Producto>[])
          p.id: p,
      };
      final yaEstan = _lineas.map((l) => l.productoId).toSet();
      final nuevos = sugeridos
          .where((s) => !yaEstan.contains(s.productoId))
          .toList();

      if (nuevos.isEmpty) {
        mensajero.mostrar(
          sugeridos.isEmpty
              ? 'Ningún producto de ese almacén está bajo su mínimo.'
              : 'Lo que está bajo el mínimo ya está en la lista.',
        );
        return;
      }

      setState(() {
        _lineas.addAll([
          for (final s in nuevos)
            LineaDocumento(
              productoId: s.productoId,
              producto: s.producto,
              codigo: s.codigo,
              unidadBase: s.unidadBase,
              presentaciones:
                  catalogo[s.productoId]?.presentaciones ??
                  const <Presentacion>[],
              uso: UsoPresentacion.compra,
              // La unidad base: es en la que el servidor calcula lo que falta.
              presentacionId: 0,
              cantidad: s.cantidadSugerida,
              importe: 0,
            ),
        ]);
        _errorLineas = null;
      });
      mensajero.mostrar(
        'Se agregaron ${nuevos.length} producto${nuevos.length == 1 ? '' : 's'} bajo el mínimo.',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } finally {
      if (mounted) setState(() => _trayendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ponerLineasExistentes(
      ref.watch(productosProvider).valueOrNull ?? const <Producto>[],
    );

    final almacenes = ref.watch(almacenesActivosProvider);

    // Con un solo almacén no hay nada que elegir.
    if (_almacenId == null && almacenes.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _almacenId == null) {
          setState(() => _almacenId = almacenes.first.id);
        }
      });
    }

    final stock = ref.watch(stockDisponibleProvider(_almacenId)).valueOrNull;
    final reservado = ref.watch(stockReservadoProvider(_almacenId)).valueOrNull;

    // Su propio Scaffold: no cuelga de AppShell, así que declara aquí el acento del módulo.
    return Acento.modulo(
      'compras',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNueva ? 'Nueva solicitud de compra' : 'Editar solicitud',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio4),
            ],

            AppSelector<int>(
              valor: _almacenId,
              etiqueta: 'Almacén',
              icono: Icons.warehouse_outlined,
              error: _errorAlmacen,
              habilitado: !_guardando,
              opciones: [
                for (final a in almacenes) Opcion<int>(a.id, a.nombre),
              ],
              onCambio: (v) => setState(() {
                _almacenId = v;
                _errorAlmacen = null;
              }),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<String>(
              valor: _urgencia,
              etiqueta: 'Urgencia',
              icono: Icons.priority_high,
              habilitado: !_guardando,
              opciones: const [
                Opcion<String>(UrgenciaSolicitud.normal, 'Normal'),
                Opcion<String>(UrgenciaSolicitud.urgente, 'Urgente'),
              ],
              onCambio: (v) => setState(() => _urgencia = v ?? UrgenciaSolicitud.normal),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Motivo u observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),

            AppBoton(
              texto: 'Traer lo que está bajo el mínimo',
              variante: BotonVariante.secundario,
              expandido: true,
              cargando: _trayendo,
              onPressed: _guardando ? null : _traerBajoMinimo,
            ),
            const SizedBox(height: Dimen.espacio4),

            // Sin costo: la solicitud no maneja plata. El costo y el proveedor los pone Compras en la orden.
            AppPanelProducto(
              productos:
                  (ref.watch(productosProvider).valueOrNull ??
                          const <Producto>[])
                      .where((p) => p.activo && p.controlaStock)
                      .toList(),
              cargando: ref.watch(productosProvider).isLoading,
              paraVenta: false,
              uso: UsoPresentacion.compra,
              pideImporte: false,
              stock: stock,
              reservado: reservado,
              habilitado: !_guardando,
              onAgregar: _agregarLineas,
            ),
            const SizedBox(height: Dimen.espacio5),

            AppLineasProducto(
              lineas: _lineas,
              error: _errorLineas,
              mostrarImporte: false,
              habilitado: !_guardando,
              onCambio: () => setState(() {}),
              onEliminar: (l) => setState(() => _lineas.remove(l)),
            ),
            const SizedBox(height: Dimen.espacio6),

            if (_soloCorregir)
              AppBotonesFormulario(
                onCancelar: () => Navigator.of(context).pop(),
                onGuardar: () => _guardar(enviar: false),
                textoGuardar: 'Guardar',
                cargando: _guardando,
              )
            else ...[
              AppBoton(
                texto: 'Enviar al administrador',
                expandido: true,
                cargando: _guardando,
                onPressed: () => _guardar(enviar: true),
              ),
              const SizedBox(height: Dimen.espacio3),
              AppBoton(
                texto: 'Guardar borrador',
                variante: BotonVariante.secundario,
                expandido: true,
                onPressed: _guardando ? null : () => _guardar(enviar: false),
              ),
              const SizedBox(height: Dimen.espacio3),
              AppBoton(
                texto: 'Cancelar',
                variante: BotonVariante.texto,
                expandido: true,
                onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              ),
            ],
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}
