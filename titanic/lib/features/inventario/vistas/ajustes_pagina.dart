import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart';
import '../../../compartido/exportar_csv.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/estado/filtro_documento.dart';
import '../../../compartido/estado/filtro_estado.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/documento_inventario.dart';
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';
import 'ajuste_formulario.dart';
import 'motivo_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Las dos pestañas de la vista, como en el panel web.
enum _Pestana { ajustes, motivos }

/// Ajustes de inventario y sus motivos, en pestañas: no son dos modulos, son
/// las dos caras del mismo concepto (el documento y las razones posibles).
class AjustesPagina extends ConsumerStatefulWidget {
  const AjustesPagina({super.key});

  static const ruta = '/inv/ajustes';

  @override
  ConsumerState<AjustesPagina> createState() => _AjustesPaginaState();
}

class _AjustesPaginaState extends ConsumerState<AjustesPagina> {
  var _pestana = _Pestana.ajustes;

  @override
  Widget build(BuildContext context) {
    final color =
        resolverRuta(AjustesPagina.ruta).grupo?.color ?? Colores.marca;

    return switch (_pestana) {
      _Pestana.ajustes => _vistaAjustes(color),
      _Pestana.motivos => _vistaMotivos(color),
    };
  }

  /// Ajustes | Motivos, cada una con cuántos registros tiene. En Motivos se
  /// cuentan solo los manuales, igual que en la web: son los que se
  /// administran aquí; los del sistema se listan pero no se tocan.
  Widget _pestanas() {
    final ajustes = ref.watch(ajustesProvider).valueOrNull;
    final motivos = ref.watch(motivosProvider).valueOrNull;

    return AppPestanas<_Pestana>(
      activa: _pestana,
      onCambio: (p) => setState(() => _pestana = p),
      pestanas: [
        Pestana(
          _Pestana.ajustes,
          'Ajustes',
          icono: Icons.fact_check_outlined,
          contador: ajustes?.length,
        ),
        Pestana(
          _Pestana.motivos,
          'Motivos',
          icono: Icons.checklist,
          contador: motivos?.where((m) => !m.delSistema).length,
        ),
      ],
    );
  }

  // --- Ajustes ---

  Widget _vistaAjustes(Color color) {
    final puedeAnular = puede(ref, 'inv.ajustes', Accion.anular);
    final puedeExportar = puede(ref, 'inv.ajustes', Accion.exportar);
    final puestos = ref.watch(filtrosAjustesActivosProvider);

    return AppListaPagina<DocumentoInventario>(
      titulo: 'Ajustes de inventario',
      ruta: AjustesPagina.ruta,
      pestanas: _pestanas(),
      estado: ref.watch(ajustesProvider),
      visibles: ref.watch(ajustesFiltradosProvider),
      busqueda: ref.watch(busquedaAjustesProvider),
      onBuscar: (t) => ref.read(busquedaAjustesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, almacén o motivo',
      onRecargar: () => ref.read(ajustesProvider.notifier).recargar(),
      acciones: [
        if (puede(ref, 'inv.ajustes', Accion.exportar))
          accionExportar<DocumentoInventario>(
            context,
            nombre: 'ajustes',
            filas: () => ref.read(ajustesFiltradosProvider),
            encabezados: const [
              'Número',
              'Fecha',
              'Almacén',
              'Motivo',
              'Tipo',
              'Estado',
              'Líneas',
              'Total',
              'Usuario',
            ],
            fila: (d) => [
              d.numero,
              diaIso(d.fecha),
              d.almacen,
              d.motivo,
              d.motivoTipo,
              d.estado,
              d.lineas,
              d.total,
              d.usuario,
            ],
          ),
      ],
      onNuevo: puede(ref, 'inv.ajustes', Accion.crear) ? _nuevoAjuste : null,
      textoNuevo: 'Nuevo ajuste',
      iconoVacio: Icons.fact_check_outlined,
      singular: 'ajuste',
      plural: 'ajustes',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : null,
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: _filtrosAjustes,
      ),
      fila: (context, doc) => _TarjetaAjuste(
        doc: doc,
        color: color,
        conPdf: puedeExportar,
        onAnular: doc.anulado || !puedeAnular ? null : () => _anularAjuste(doc),
      ),
    );
  }

  void _nuevoAjuste() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AjusteFormulario()));
  }

  /// Lo que se pregunta de un listado de ajustes: en que quedo y por que fue.
  Future<void> _filtrosAjustes() {
    final motivos = ref.read(motivosProvider).valueOrNull ?? const <Motivo>[];

    return mostrarFiltros(
      context,
      activos: ref.read(filtrosAjustesActivosProvider),
      onLimpiar: () {
        ref.read(filtroDocumentoProvider.notifier).state =
            FiltroDocumento.todos;
        ref.read(motivoAjusteFiltroProvider.notifier).state = null;
        ref.read(almacenAjusteFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroDocumento>(
            titulo: 'Estado',
            valor: ref.watch(filtroDocumentoProvider),
            opciones: const [
              OpcionFiltro(FiltroDocumento.todos, 'Todos'),
              OpcionFiltro(FiltroDocumento.vigentes, 'Vigentes'),
              OpcionFiltro(FiltroDocumento.anulados, 'Anulados'),
            ],
            onCambio: (v) =>
                ref.read(filtroDocumentoProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<int?>(
            titulo: 'Motivo',
            valor: ref.watch(motivoAjusteFiltroProvider),
            opciones: [
              const OpcionFiltro<int?>(null, 'Todos'),
              for (final m in motivos)
                OpcionFiltro<int?>(
                  m.id,
                  '${m.nombre} (${m.esEntrada ? 'Ingreso' : 'Salida'})',
                ),
            ],
            onCambio: (v) =>
                ref.read(motivoAjusteFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final almacenes = ref.watch(almacenesActivosProvider);
            if (almacenes.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Almacén',
              valor: ref.watch(almacenAjusteFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final a in almacenes) OpcionFiltro(a.nombre, a.nombre),
              ],
              onCambio: (v) =>
                  ref.read(almacenAjusteFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _anularAjuste(DocumentoInventario doc) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${doc.numero}',
      mensaje:
          'Se crea un documento que revierte el movimiento; el original queda '
          'en el historial marcado como anulado. No se puede deshacer.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(ajustesProvider.notifier).anular(doc.id);
      mensajero.mostrar('${doc.numero} anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  // --- Motivos ---

  /*
   * Los motivos, como `MotivosTabla` del panel web.
   *
   * Se listan todos: los manuales primero, que son los que se administran, y
   * los del sistema detras, en solo lectura —aparecen en el kardex y en cada
   * movimiento, y esconderlos hacia parecer que faltaban—. Solo los manuales
   * se editan, se activan o desactivan y se eliminan.
   */
  Widget _vistaMotivos(Color color) {
    final puedeEditar = puede(ref, 'inv.ajustes', Accion.editar);
    final puestos = ref.watch(filtrosMotivosActivosProvider);
    final busqueda = ref.watch(busquedaMotivosProvider);

    return AppListaPagina<Motivo>(
      titulo: 'Ajustes de inventario',
      ruta: AjustesPagina.ruta,
      pestanas: _pestanas(),
      estado: ref.watch(motivosProvider),
      visibles: ref.watch(motivosFiltradosProvider),
      busqueda: busqueda,
      onBuscar: (t) => ref.read(busquedaMotivosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar motivo',
      onRecargar: () => ref.read(motivosProvider.notifier).recargar(),
      onNuevo: puede(ref, 'inv.ajustes', Accion.crear)
          ? () => mostrarFormularioMotivo(context, ref)
          : null,
      textoNuevo: 'Nuevo motivo',
      iconoVacio: Icons.checklist,
      singular: 'motivo',
      plural: 'motivos',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : busqueda.isEmpty
          ? 'Crea los motivos con los que justificas un ajuste.'
          : null,
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: _filtrosMotivos,
      ),
      fila: (context, motivo) {
        // El del sistema no se edita, ni se desactiva, ni se borra: no hay
        // accion que ofrecerle.
        final editable = !motivo.delSistema && puedeEditar;

        return _TarjetaMotivo(
          motivo: motivo,
          color: color,
          onEditar: editable
              ? () => mostrarFormularioMotivo(context, ref, motivo: motivo)
              : null,
          onEstado: editable ? () => _cambiarEstadoMotivo(motivo) : null,
          // Va con "editar" y no con "eliminar", como en la web: inv.ajustes
          // no declara esa accion porque un ajuste no se borra, se anula.
          // Solo sin movimientos: lo que ya se usa se desactiva.
          onEliminar: editable && motivo.movimientos == 0
              ? () => _eliminarMotivo(motivo)
              : null,
        );
      },
    );
  }

  /// El catalogo de motivos: de donde sale cada uno y si suma o resta.
  Future<void> _filtrosMotivos() {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosMotivosActivosProvider),
      onLimpiar: () {
        ref.read(origenMotivoProvider.notifier).state = FiltroOrigen.todos;
        ref.read(tipoMotivoProvider.notifier).state = FiltroMovimiento.todos;
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroOrigen>(
            titulo: 'Origen',
            valor: ref.watch(origenMotivoProvider),
            opciones: const [
              OpcionFiltro(FiltroOrigen.todos, 'Todos'),
              OpcionFiltro(FiltroOrigen.manuales, 'Manuales'),
              OpcionFiltro(FiltroOrigen.delSistema, 'Del sistema'),
            ],
            onCambio: (v) => ref.read(origenMotivoProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroMovimiento>(
            titulo: 'Tipo',
            valor: ref.watch(tipoMotivoProvider),
            opciones: const [
              OpcionFiltro(FiltroMovimiento.todos, 'Todos'),
              OpcionFiltro(FiltroMovimiento.entradas, 'Ingresos'),
              OpcionFiltro(FiltroMovimiento.salidas, 'Salidas'),
            ],
            onCambio: (v) => ref.read(tipoMotivoProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroEstado>(
            titulo: 'Estado',
            valor: ref.watch(estadoFiltroProvider),
            opciones: const [
              OpcionFiltro(FiltroEstado.activos, 'Activos'),
              OpcionFiltro(FiltroEstado.inactivos, 'Desactivados'),
              OpcionFiltro(FiltroEstado.todos, 'Todos'),
            ],
            onCambio: (v) => ref.read(estadoFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  /// El backend no tiene activar/desactivar propio: se manda el mismo PUT con
  /// el estado invertido, igual que hace el panel web.
  Future<void> _cambiarEstadoMotivo(Motivo m) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${m.activo ? 'Desactivar' : 'Activar'} ${m.nombre}',
      mensaje: m.activo
          ? 'Deja de ofrecerse al registrar un ajuste nuevo. Los documentos '
                'que ya lo usan lo conservan.'
          : 'Vuelve a estar disponible para ajustes nuevos.',
      textoConfirmar: m.activo ? 'Desactivar' : 'Activar',
      tono: m.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref
          .read(motivosProvider.notifier)
          .guardar(
            id: m.id,
            cuerpo: {
              'codigo': m.codigo,
              'nombre': m.nombre,
              'tipo': m.tipo,
              'activo': !m.activo,
            },
          );
      mensajero.mostrar(
        m.activo ? '${m.nombre} desactivado' : '${m.nombre} activado',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _eliminarMotivo(Motivo m) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${m.nombre}',
      mensaje: 'Se borra definitivamente.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(motivosProvider.notifier).eliminar(m.id);
      mensajero.mostrar('${m.nombre} eliminado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaAjuste extends StatelessWidget {
  const _TarjetaAjuste({
    required this.doc,
    required this.color,
    required this.conPdf,
    this.onAnular,
  });

  final DocumentoInventario doc;
  final Color color;

  /// Si se ofrece el PDF: pide el permiso de exportar.
  final bool conPdf;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Almacén', doc.almacen),
    CampoDetalle('Motivo', doc.motivo),
    CampoDetalle('Líneas', '${doc.lineas}'),
    CampoDetalle('Total', 'S/ ${doc.total.toStringAsFixed(2)}'),
    if (doc.usuario != null) CampoDetalle('Registrado por', doc.usuario),
    if (doc.observacion != null) CampoDetalle('Observación', doc.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in doc.detalle)
      LineaProductoTarjeta(
        titulo: linea.producto,
        subtitulo:
            '${linea.codigo} · ${linea.presentacion ?? linea.unidadBase}',
        filas: [
          [
            ('Tipo', linea.esEntrada ? 'Ingreso' : 'Salida'),
            ('Cant.', formatoNumero(linea.cantidadPresentacion)),
            ('Subtotal', 'S/ ${linea.costoTotal.toStringAsFixed(2)}'),
          ],
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.fact_check_outlined,
      color: color,
      titulo: doc.numero,
      estado: AppEtiqueta(
        doc.anulado ? 'Anulado' : 'Confirmado',
        tono: doc.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.fact_check_outlined,
        color: color,
        titulo: doc.numero,
        subtitulo: doc.motivo,
        campos: _campos,
        contenidoExtra: _lineas,
      ),
      acciones: [
        if (conPdf)
          IconButton(
            onPressed: () => mostrarOpcionesPdf(
              context,
              documento: DocumentoPdf.ajuste,
              id: doc.id,
              numero: doc.numero,
            ),
            tooltip: 'PDF',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          ),
        if (onAnular != null)
          IconButton(
            onPressed: onAnular,
            tooltip: 'Anular',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.block, size: 18, color: Colores.advertencia),
          ),
      ],
    );
  }
}

class _TarjetaMotivo extends StatelessWidget {
  const _TarjetaMotivo({
    required this.motivo,
    required this.color,
    this.onEditar,
    this.onEstado,
    this.onEliminar,
  });

  final Motivo motivo;
  final Color color;

  /// Null en los del sistema o sin permiso: no hay accion que ofrecerles.
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.checklist,
      color: color,
      titulo: motivo.nombre,
      insignia: AppEtiqueta(
        motivo.esEntrada ? 'Ingreso' : 'Salida',
        tono: motivo.esEntrada ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
      campos: [
        // Explica por que unas tarjetas no tienen acciones.
        CampoDetalle(
          'Origen',
          motivo.delSistema ? 'Sistema' : 'Manual',
          widget: AppEtiqueta(
            motivo.delSistema ? 'Sistema' : 'Manual',
            tono: motivo.delSistema
                ? EtiquetaTono.neutral
                : EtiquetaTono.modulo,
          ),
        ),
        CampoDetalle('Código', motivo.codigo),
        CampoDetalle('Pide costo', motivo.pideCosto ? 'Sí' : 'No'),
        CampoDetalle('Movimientos', '${motivo.movimientos}'),
        CampoDetalle(
          'Estado',
          motivo.activo ? 'Activo' : 'Inactivo',
          widget: AppEtiqueta(
            motivo.activo ? 'Activo' : 'Inactivo',
            tono: motivo.activo ? EtiquetaTono.exito : EtiquetaTono.neutral,
          ),
        ),
      ],
      onTap: onEditar,
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
        if (onEstado != null)
          IconButton(
            onPressed: onEstado,
            tooltip: motivo.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              motivo.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: Colores.advertencia,
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
