import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/documento_inventario.dart';
import '../datos/motivo.dart';
import '../estado/inventario_controlador.dart';
import 'ajuste_formulario.dart';
import 'motivo_formulario.dart';

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
          onPressed: () => _tabs.index == 0 ? _nuevoAjuste(context) : _nuevoMotivo(context),
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

  Widget _tabAjustes(Color color) {
    final estado = ref.watch(ajustesProvider);
    final visibles = ref.watch(ajustesFiltradosProvider);
    final busqueda = ref.watch(busquedaAjustesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimen.espacio4),
          child: AppBuscador(
            valor: busqueda,
            onCambio: (t) => ref.read(busquedaAjustesProvider.notifier).state = t,
            pista: 'Buscar por número, almacén o motivo',
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

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(ajustesProvider.notifier).anular(doc.id);
      mensajero.showSnackBar(SnackBar(content: Text('${doc.numero} anulado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
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
          child: AppBuscador(
            valor: busqueda,
            onCambio: (t) => ref.read(busquedaMotivosProvider.notifier).state = t,
            pista: 'Buscar motivo',
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
                    detalle: 'Los motivos del sistema (venta, compra...) no aparecen aquí.',
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
                        onEditar: () => mostrarFormularioMotivo(context, ref, motivo: visibles[i]),
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
    for (final linea in doc.detalle)
      CampoDetalle(
        linea.producto,
        '${linea.esEntrada ? '+' : '-'}${formatoNumero(linea.cantidadPresentacion)} '
        '${linea.presentacion ?? linea.unidadBase} · S/ ${linea.costoTotal.toStringAsFixed(2)}',
        enTarjeta: false,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.fact_check_outlined,
      color: color,
      titulo: doc.numero,
      insignia: AppEtiqueta(
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
      ),
      acciones: [
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
  const _TarjetaMotivo({required this.motivo, required this.color, required this.onEditar});

  final Motivo motivo;
  final Color color;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.fact_check_outlined,
      color: color,
      titulo: motivo.nombre,
      insignia: AppEtiqueta(motivo.esEntrada ? 'Entrada' : 'Salida'),
      campos: [
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
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
      ],
    );
  }
}
