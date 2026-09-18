import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/estado/filtro_documento.dart';
import '../../../compartido/estado/filtro_estado.dart';
import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/documento_inventario.dart';
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';
import 'ajuste_formulario.dart';
import 'motivo_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Ajustes de inventario y sus motivos, en pestañas: no son dos modulos, son
/// las dos caras del mismo concepto (el documento y las razones posibles).
class AjustesPagina extends ConsumerStatefulWidget {
  const AjustesPagina({super.key});

  static const ruta = '/inv/ajustes';

  @override
  ConsumerState<AjustesPagina> createState() => _AjustesPaginaState();
}

class _AjustesPaginaState extends ConsumerState<AjustesPagina>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = resolverRuta(AjustesPagina.ruta).grupo?.color ?? Colores.marca;

    return AppShell(
      titulo: 'Ajustes de inventario',
      subtitulo: resolverRuta(AjustesPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: AjustesPagina.ruta,
      accionFlotante: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: () =>
              _tabs.index == 0 ? _nuevoAjuste(context) : _nuevoMotivo(context),
          backgroundColor: color,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(_tabs.index == 0 ? 'Nuevo ajuste' : 'Nuevo motivo'),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: color,
            unselectedLabelColor: Colores.tintaSuave,
            indicatorColor: color,
            tabs: const [Tab(text: 'Ajustes'), Tab(text: 'Motivos')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_tabAjustes(color), _tabMotivos(color)],
            ),
          ),
        ],
      ),
    );
  }

  void _nuevoAjuste(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjusteFormulario()));
  }

  void _nuevoMotivo(BuildContext context) {
    mostrarFormularioMotivo(context, ref);
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
                  '${m.nombre} (${m.esEntrada ? 'Entrada' : 'Salida'})',
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
              OpcionFiltro(FiltroMovimiento.entradas, 'Entradas'),
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

  Widget _tabAjustes(Color color) {
    final estado = ref.watch(ajustesProvider);
    final visibles = ref.watch(ajustesFiltradosProvider);
    final busqueda = ref.watch(busquedaAjustesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimen.espacio4),
          child: Row(
            children: [
              Expanded(
                child: AppBuscador(
                  valor: busqueda,
                  onCambio: (t) =>
                      ref.read(busquedaAjustesProvider.notifier).state = t,
                  pista: 'Buscar por número, almacén o motivo',
                ),
              ),
              BotonFiltros(
                activos: ref.watch(filtrosAjustesActivosProvider),
                color: color,
                onAbrir: _filtrosAjustes,
              ),
            ],
          ),
        ),
        Expanded(
          child: estado.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppVacio(
              icono: Icons.wifi_off_outlined,
              titulo: 'No se pudo cargar',
              detalle: e is ApiExcepcion ? e.texto : 'No pudimos cargar los ajustes.',
              accion: FilledButton.icon(
                onPressed: () => ref.read(ajustesProvider.notifier).recargar(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ),
            data: (_) => visibles.isEmpty
                ? const AppVacio(
                    icono: Icons.fact_check_outlined,
                    titulo: 'Sin ajustes',
                    detalle: 'Registra el primero con el botón de abajo.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(ajustesProvider.notifier).recargar(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Dimen.espacio4,
                        0,
                        Dimen.espacio4,
                        Dimen.espacio6 * 2,
                      ),
                      itemCount: visibles.length,
                      separatorBuilder: (context, i) => const SizedBox(height: Dimen.espacio2),
                      itemBuilder: (context, i) => _TarjetaAjuste(
                        doc: visibles[i],
                        color: color,
                        onAnular: visibles[i].anulado ? null : () => _anularAjuste(visibles[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _anularAjuste(DocumentoInventario doc) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${doc.numero}',
      mensaje: 'Se revierte el movimiento con un documento espejo. No se puede deshacer.',
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

  Widget _tabMotivos(Color color) {
    final estado = ref.watch(motivosProvider);
    final visibles = ref.watch(motivosFiltradosProvider);
    final busqueda = ref.watch(busquedaMotivosProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimen.espacio4),
          child: Row(
            children: [
              Expanded(
                child: AppBuscador(
                  valor: busqueda,
                  onCambio: (t) =>
                      ref.read(busquedaMotivosProvider.notifier).state = t,
                  pista: 'Buscar motivo',
                ),
              ),
              BotonFiltros(
                activos: ref.watch(filtrosMotivosActivosProvider),
                color: color,
                onAbrir: _filtrosMotivos,
              ),
            ],
          ),
        ),
        Expanded(
          child: estado.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppVacio(
              icono: Icons.wifi_off_outlined,
              titulo: 'No se pudo cargar',
              detalle: e is ApiExcepcion ? e.texto : 'No pudimos cargar los motivos.',
              accion: FilledButton.icon(
                onPressed: () => ref.read(motivosProvider.notifier).recargar(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ),
            data: (_) => visibles.isEmpty
                ? const AppVacio(
                    icono: Icons.fact_check_outlined,
                    titulo: 'Sin motivos',
                    detalle: 'Crea los motivos con los que justificas un ajuste.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(motivosProvider.notifier).recargar(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Dimen.espacio4,
                        0,
                        Dimen.espacio4,
                        Dimen.espacio6 * 2,
                      ),
                      itemCount: visibles.length,
                      separatorBuilder: (context, i) => const SizedBox(height: Dimen.espacio2),
                      itemBuilder: (context, i) => _TarjetaMotivo(
                        motivo: visibles[i],
                        color: color,
                        onEditar:
                            visibles[i].delSistema ||
                                !puede(ref, 'inv.ajustes', Accion.editar)
                            ? null
                            : () => mostrarFormularioMotivo(context, ref, motivo: visibles[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaAjuste extends StatelessWidget {
  const _TarjetaAjuste({required this.doc, required this.color, this.onAnular});

  final DocumentoInventario doc;
  final Color color;
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
        subtitulo: '${linea.codigo} · ${linea.presentacion ?? linea.unidadBase}',
        filas: [
          [
            ('Tipo', linea.esEntrada ? 'Entrada' : 'Salida'),
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
            icon: const Icon(Icons.block, size: 18, color: Colores.peligro),
          ),
      ],
    );
  }
}

class _TarjetaMotivo extends StatelessWidget {
  const _TarjetaMotivo({required this.motivo, required this.color, this.onEditar});

  final Motivo motivo;
  final Color color;

  /// Null en los del sistema: no hay accion que ofrecerles.
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.fact_check_outlined,
      color: color,
      titulo: motivo.nombre,
      insignia: AppEtiqueta(motivo.esEntrada ? 'Entrada' : 'Salida'),
      campos: [
        // Explica por que unas tarjetas no tienen acciones.
        CampoDetalle(
          'Origen',
          motivo.delSistema ? 'Sistema' : 'Manual',
          widget: AppEtiqueta(
            motivo.delSistema ? 'Sistema' : 'Manual',
            tono: motivo.delSistema ? EtiquetaTono.neutral : EtiquetaTono.modulo,
          ),
        ),
        CampoDetalle('Código', motivo.codigo),
        CampoDetalle('Usos', '${motivo.movimientos}'),
        CampoDetalle(
          'Estado',
          motivo.activo ? 'Activo' : 'Inactivo',
          widget: AppEtiqueta(
            motivo.activo ? 'Activo' : 'Inactivo',
            tono: motivo.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
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
            icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
          ),
      ],
    );
  }
}
