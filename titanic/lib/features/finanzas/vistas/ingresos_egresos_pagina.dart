import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
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
import '../datos/tesoreria.dart';
import '../estado/mi_caja_controlador.dart';
import '../estado/tesoreria_controlador.dart';
import 'hojas_finanzas.dart';

const _sub = 'finanzas.operativos';

String _tipoEtiqueta(String t) => t == 'INGRESO' ? 'Ingreso' : 'Egreso';
String _origenEtiqueta(String o) =>
    o == 'OPERATIVO' ? 'Operativo' : 'No operativo';

/// Ingresos y egresos: los gastos que se repiten cada mes y el catalogo de
/// categorias con que se clasifica todo lo que entra y sale. Tres pestañas,
/// igual que el panel web: lo que toca pagar, las plantillas y las categorias.
class IngresosEgresosPagina extends ConsumerWidget {
  const IngresosEgresosPagina({super.key});

  static const ruta = '/finanzas/operativos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pestana = ref.watch(pestanaOperativosProvider);
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final pestanas = _Pestanas(
      actual: pestana,
      onCambio: (p) {
        ref.read(pestanaOperativosProvider.notifier).state = p;
        ref.read(busquedaOperativosProvider.notifier).state = '';
      },
    );

    return switch (pestana) {
      PestanaOperativos.pendientes => _pendientes(
        context,
        ref,
        color,
        pestanas,
      ),
      PestanaOperativos.recurrentes => _recurrentes(
        context,
        ref,
        color,
        pestanas,
      ),
      PestanaOperativos.categorias => _categorias(
        context,
        ref,
        color,
        pestanas,
      ),
    };
  }

  Future<void> _recargar(WidgetRef ref, ProviderOrFamily provider) async {
    ref.invalidate(provider);
  }

  // ------------------------------------------------------------ Pendientes

  Widget _pendientes(
    BuildContext context,
    WidgetRef ref,
    Color color,
    Widget pestanas,
  ) {
    final todos =
        ref.watch(pendientesProvider).valueOrNull ?? const <GastoPendiente>[];
    final vencidos = todos.where((p) => p.vencido);
    final puedePagar =
        puede(ref, _sub, Accion.crear) ||
        puede(ref, 'finanzas.movimientos', Accion.crear);

    return AppListaPagina<GastoPendiente>(
      titulo: 'Ingresos y egresos',
      ruta: ruta,
      estado: ref.watch(pendientesProvider),
      visibles: ref.watch(pendientesFiltradosProvider),
      busqueda: ref.watch(busquedaOperativosProvider),
      onBuscar: (t) => ref.read(busquedaOperativosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar gasto',
      onRecargar: () => _recargar(ref, pendientesProvider),
      iconoVacio: Icons.event_available_outlined,
      singular: 'pendiente',
      plural: 'pendientes',
      tituloVacio: 'Todo al día',
      detalleVacio: 'No hay gastos recurrentes por pagar este mes.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Vencidos',
          valor: '${vencidos.length}',
          icono: Icons.warning_amber_rounded,
          tono: vencidos.isEmpty ? DatoTono.neutral : DatoTono.peligro,
          nota: formatoSoles(
            vencidos.fold<double>(0, (s, p) => s + p.montoEstimado),
          ),
        ),
        AppTarjetaDato(
          etiqueta: 'Por vencer',
          valor: '${todos.length - vencidos.length}',
          icono: Icons.event_outlined,
          tono: DatoTono.aviso,
        ),
      ],
      encabezado: pestanas,
      fila: (context, p) => AppTarjetaRegistro(
        icono: Icons.event_repeat_outlined,
        color: color,
        titulo: p.nombre,
        insignia: AppEtiqueta(
          p.vencido ? 'Vencido' : 'Por vencer',
          tono: p.vencido ? EtiquetaTono.peligro : EtiquetaTono.aviso,
        ),
        campos: [
          CampoDetalle('Categoría', p.motivoGasto),
          CampoDetalle('Monto estimado', formatoSoles(p.montoEstimado)),
          CampoDetalle('Vence', fechaCorta(p.proximoVencimiento)),
        ],
        acciones: [
          if (puedePagar)
            TextButton(
              onPressed: () =>
                  abrirHojaFinanzas(context, (_) => _HojaPagar(pendiente: p)),
              child: const Text('Pagar'),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Recurrentes

  Widget _recurrentes(
    BuildContext context,
    WidgetRef ref,
    Color color,
    Widget pestanas,
  ) {
    final puedeEditar = puede(ref, _sub, Accion.editar);
    final puedeEliminar = puede(ref, _sub, Accion.eliminar);

    return AppListaPagina<GastoRecurrente>(
      titulo: 'Ingresos y egresos',
      ruta: ruta,
      estado: ref.watch(recurrentesProvider),
      visibles: ref.watch(recurrentesFiltradosProvider),
      busqueda: ref.watch(busquedaOperativosProvider),
      onBuscar: (t) => ref.read(busquedaOperativosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar gasto recurrente',
      onRecargar: () => _recargar(ref, recurrentesProvider),
      onNuevo: puede(ref, _sub, Accion.crear)
          ? () => abrirHojaFinanzas(context, (_) => const _HojaRecurrente())
          : null,
      textoNuevo: 'Nuevo recurrente',
      iconoVacio: Icons.repeat,
      singular: 'recurrente',
      plural: 'recurrentes',
      detalleVacio: 'Alquiler, luz, internet: lo que se paga todos los meses.',
      encabezado: pestanas,
      fila: (context, r) => AppTarjetaRegistro(
        icono: Icons.repeat,
        color: color,
        titulo: r.nombre,
        insignia: r.activo
            ? null
            : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
        campos: [
          CampoDetalle('Categoría', r.motivoGasto),
          CampoDetalle('Monto estimado', formatoSoles(r.montoEstimado)),
          CampoDetalle('Vence', 'el día ${r.diaVencimiento} de cada mes'),
          CampoDetalle('Sale de', r.cuentaFinancieraSugerida),
        ],
        acciones: [
          if (puedeEditar) ...[
            IconButton(
              onPressed: () => abrirHojaFinanzas(
                context,
                (_) => _HojaRecurrente(recurrente: r),
              ),
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Acento.de(context),
              ),
            ),
            IconButton(
              onPressed: () => _estadoRecurrente(context, ref, r),
              tooltip: r.activo ? 'Desactivar' : 'Activar',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                r.activo ? Icons.block : Icons.check_circle_outline,
                size: 18,
                color: r.activo ? Colores.advertencia : Colores.exito,
              ),
            ),
          ],
          if (puedeEliminar)
            IconButton(
              onPressed: () => _eliminarRecurrente(context, ref, r),
              tooltip: 'Eliminar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colores.peligro,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _estadoRecurrente(
    BuildContext context,
    WidgetRef ref,
    GastoRecurrente r,
  ) async {
    final mensajero = Aviso.de(context);
    try {
      await ref
          .read(tesoreriaApiProvider)
          .actualizarRecurrente(r.id, r.aJson(activo: !r.activo));
      ref.invalidate(recurrentesProvider);
      ref.invalidate(pendientesProvider);
      mensajero.mostrar('${r.nombre} ${r.activo ? 'desactivado' : 'activado'}');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _eliminarRecurrente(
    BuildContext context,
    WidgetRef ref,
    GastoRecurrente r,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${r.nombre}',
      mensaje: 'Deja de aparecer en los pendientes. Lo ya pagado se conserva.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).eliminarRecurrente(r.id);
      ref.invalidate(recurrentesProvider);
      ref.invalidate(pendientesProvider);
      mensajero.mostrar('${r.nombre} eliminado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  // ------------------------------------------------------------ Categorías

  Widget _categorias(
    BuildContext context,
    WidgetRef ref,
    Color color,
    Widget pestanas,
  ) {
    final puedeEditar = puede(ref, _sub, Accion.editar);
    final puedeEliminar = puede(ref, _sub, Accion.eliminar);

    return AppListaPagina<CategoriaFinanzas>(
      titulo: 'Ingresos y egresos',
      ruta: ruta,
      estado: ref.watch(categoriasFinanzasProvider),
      visibles: ref.watch(categoriasFiltradasProvider),
      busqueda: ref.watch(busquedaOperativosProvider),
      onBuscar: (t) => ref.read(busquedaOperativosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar categoría',
      onRecargar: () => _recargar(ref, categoriasFinanzasProvider),
      onNuevo: puede(ref, _sub, Accion.crear)
          ? () => abrirHojaFinanzas(context, (_) => const _HojaCategoria())
          : null,
      textoNuevo: 'Nueva categoría',
      iconoVacio: Icons.category_outlined,
      singular: 'categoría',
      plural: 'categorías',
      encabezado: pestanas,
      filtro: BotonFiltros(
        activos: ref.watch(filtrosCategoriasActivosProvider),
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: ref.read(filtrosCategoriasActivosProvider),
          onLimpiar: () {
            ref.read(tipoCategoriasFiltroProvider.notifier).state = null;
            ref.read(origenCategoriasFiltroProvider.notifier).state = null;
          },
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<String?>(
                titulo: 'Tipo',
                valor: ref.watch(tipoCategoriasFiltroProvider),
                opciones: const [
                  OpcionFiltro(null, 'Todos'),
                  OpcionFiltro('INGRESO', 'Ingreso'),
                  OpcionFiltro('EGRESO', 'Egreso'),
                ],
                onCambio: (v) =>
                    ref.read(tipoCategoriasFiltroProvider.notifier).state = v,
              ),
            ),
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<String?>(
                titulo: 'Origen',
                valor: ref.watch(origenCategoriasFiltroProvider),
                opciones: const [
                  OpcionFiltro(null, 'Todos'),
                  OpcionFiltro('OPERATIVO', 'Operativo'),
                  OpcionFiltro('NO_OPERATIVO', 'No operativo'),
                ],
                onCambio: (v) =>
                    ref.read(origenCategoriasFiltroProvider.notifier).state = v,
              ),
            ),
          ],
        ),
      ),
      fila: (context, c) => AppTarjetaRegistro(
        icono: c.esSistema ? Icons.lock_outline : Icons.category_outlined,
        color: color,
        titulo: c.nombre,
        insignia: AppEtiqueta(
          _tipoEtiqueta(c.tipo),
          tono: c.tipo == 'INGRESO' ? EtiquetaTono.exito : EtiquetaTono.peligro,
        ),
        campos: [
          CampoDetalle('Origen', _origenEtiqueta(c.origen)),
          CampoDetalle('Registro', c.esSistema ? 'Sistema' : 'Manual'),
          CampoDetalle('Usos', '${c.usos}'),
          CampoDetalle('Estado', c.activo ? 'Activa' : 'Inactiva'),
          CampoDetalle('Descripción', c.descripcion),
        ],
        acciones: [
          // Las del sistema las usa el propio sistema: no se tocan.
          if (puedeEditar && !c.esSistema)
            IconButton(
              onPressed: () => abrirHojaFinanzas(
                context,
                (_) => _HojaCategoria(categoria: c),
              ),
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Acento.de(context),
              ),
            ),
          if (puedeEliminar && !c.esSistema && c.usos == 0)
            IconButton(
              onPressed: () => _eliminarCategoria(context, ref, c),
              tooltip: 'Eliminar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colores.peligro,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _eliminarCategoria(
    BuildContext context,
    WidgetRef ref,
    CategoriaFinanzas c,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${c.nombre}',
      mensaje: 'Nadie la usa todavía, así que se borra del catálogo.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).eliminarCategoria(c.id);
      ref.invalidate(categoriasFinanzasProvider);
      mensajero.mostrar('${c.nombre} eliminada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

/// Las tres pestañas, arriba de la lista.
class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.actual, required this.onCambio});

  final PestanaOperativos actual;
  final ValueChanged<PestanaOperativos> onCambio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: SegmentedButton<PestanaOperativos>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: PestanaOperativos.pendientes,
            label: Text('Pendientes'),
          ),
          ButtonSegment(
            value: PestanaOperativos.recurrentes,
            label: Text('Recurrentes'),
          ),
          ButtonSegment(
            value: PestanaOperativos.categorias,
            label: Text('Categorías'),
          ),
        ],
        selected: {actual},
        onSelectionChanged: (s) => onCambio(s.first),
      ),
    );
  }
}

/// Pagar un gasto recurrente: sale como un egreso de la cuenta elegida.
class _HojaPagar extends ConsumerStatefulWidget {
  const _HojaPagar({required this.pendiente});

  final GastoPendiente pendiente;

  @override
  ConsumerState<_HojaPagar> createState() => _HojaPagarState();
}

class _HojaPagarState extends ConsumerState<_HojaPagar> {
  late final _monto = TextEditingController(
    text: widget.pendiente.montoEstimado.toStringAsFixed(2),
  );
  final _detalle = TextEditingController();
  late int? _cuentaId = widget.pendiente.cuentaFinancieraSugeridaId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _pagar() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    final error = monto == null || monto <= 0
        ? 'Ingresa un monto mayor a cero.'
        : _cuentaId == null
        ? 'Elige de qué cuenta sale.'
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
    final p = widget.pendiente;

    try {
      await ref.read(tesoreriaApiProvider).crearMovimiento({
        'cuentaFinancieraId': _cuentaId,
        'tipo': 'EGRESO',
        'motivoGastoId': p.motivoGastoId,
        'monto': monto,
        'descripcion': _detalle.text.trim().isEmpty
            ? p.nombre
            : _detalle.text.trim(),
        'gastoRecurrenteId': p.gastoRecurrenteId,
      });
      ref.invalidate(pendientesProvider);
      ref.invalidate(movimientosDineroProvider);
      navegador.pop();
      mensajero.mostrar('${p.nombre} pagado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasMovimientoProvider);
    final p = widget.pendiente;

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              'Pagar ${p.nombre}',
              apoyo:
                  '${p.motivoGasto} · vence ${fechaCorta(p.proximoVencimiento)}',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _monto,
              etiqueta: 'Monto',
              icono: Icons.payments_outlined,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [soloMonto],
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            cuentas.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: lista.any((c) => c.id == _cuentaId) ? _cuentaId : null,
                etiqueta: 'Sale de',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _detalle,
              etiqueta: 'Detalle',
              icono: Icons.notes_outlined,
              pista: p.nombre,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(texto: 'Pagar', cargando: _guardando, onPressed: _pagar),
          ],
        ),
      ),
    );
  }
}

/// Alta y edicion de un gasto recurrente.
class _HojaRecurrente extends ConsumerStatefulWidget {
  const _HojaRecurrente({this.recurrente});

  /// Null cuando es nuevo.
  final GastoRecurrente? recurrente;

  @override
  ConsumerState<_HojaRecurrente> createState() => _HojaRecurrenteState();
}

class _HojaRecurrenteState extends ConsumerState<_HojaRecurrente> {
  late final _nombre = TextEditingController(
    text: widget.recurrente?.nombre ?? '',
  );
  late final _monto = TextEditingController(
    text: widget.recurrente?.montoEstimado.toStringAsFixed(2) ?? '',
  );
  late final _dia = TextEditingController(
    text: widget.recurrente?.diaVencimiento.toString() ?? '',
  );
  late int? _categoriaId = widget.recurrente?.motivoGastoId;
  late int? _cuentaId = widget.recurrente?.cuentaFinancieraSugeridaId;
  bool _guardando = false;
  String? _error;

  bool get _esNuevo => widget.recurrente == null;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    _dia.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    final dia = int.tryParse(_dia.text.trim());
    final error = _nombre.text.trim().isEmpty
        ? 'Ingresa el nombre.'
        : _categoriaId == null
        ? 'Elige la categoría.'
        : monto == null || monto <= 0
        ? 'Ingresa el monto estimado.'
        : dia == null || dia < 1 || dia > 31
        ? 'El día de vencimiento va del 1 al 31.'
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

    final cuerpo = {
      'nombre': _nombre.text.trim(),
      'motivoGastoId': _categoriaId,
      'montoEstimado': monto,
      'diaVencimiento': dia,
      'cuentaFinancieraSugeridaId': _cuentaId,
      'activo': widget.recurrente?.activo ?? true,
    };

    try {
      final api = ref.read(tesoreriaApiProvider);
      if (_esNuevo) {
        await api.crearRecurrente(cuerpo);
      } else {
        await api.actualizarRecurrente(widget.recurrente!.id, cuerpo);
      }
      ref.invalidate(recurrentesProvider);
      ref.invalidate(pendientesProvider);
      navegador.pop();
      mensajero.mostrar(
        _esNuevo ? 'Recurrente creado' : 'Recurrente actualizado',
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
    // Una plantilla recurrente es siempre un gasto.
    final categorias = ref.watch(categoriasMiCajaProvider('EGRESO'));
    final cuentas = ref.watch(cuentasMovimientoProvider);

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              _esNuevo
                  ? 'Nuevo gasto recurrente'
                  : 'Editar ${widget.recurrente!.nombre}',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              icono: Icons.label_outline,
              pista: 'Alquiler del almacén',
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            categorias.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion
                    ? e.texto
                    : 'No pudimos cargar las categorías.',
              ),
              data: (lista) => AppSelector<int>(
                valor: lista.any((c) => c.id == _categoriaId)
                    ? _categoriaId
                    : null,
                etiqueta: 'Categoría',
                icono: Icons.category_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _categoriaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            Row(
              children: [
                Expanded(
                  child: AppCampo(
                    controlador: _monto,
                    etiqueta: 'Monto estimado',
                    icono: Icons.payments_outlined,
                    tipoTeclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formateadores: [soloMonto],
                    habilitado: !_guardando,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                SizedBox(
                  width: 110,
                  child: AppCampo(
                    controlador: _dia,
                    etiqueta: 'Día',
                    icono: Icons.event_outlined,
                    tipoTeclado: TextInputType.number,
                    formateadores: [FilteringTextInputFormatter.digitsOnly],
                    maxLargo: 2,
                    habilitado: !_guardando,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            cuentas.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: lista.any((c) => c.id == _cuentaId) ? _cuentaId : null,
                etiqueta: 'Sale de (sugerida)',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: _esNuevo ? 'Crear' : 'Guardar',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta y edicion de una categoria. Las del sistema no llegan aqui.
class _HojaCategoria extends ConsumerStatefulWidget {
  const _HojaCategoria({this.categoria});

  /// Null cuando es nueva.
  final CategoriaFinanzas? categoria;

  @override
  ConsumerState<_HojaCategoria> createState() => _HojaCategoriaState();
}

class _HojaCategoriaState extends ConsumerState<_HojaCategoria> {
  late final _nombre = TextEditingController(
    text: widget.categoria?.nombre ?? '',
  );
  late final _descripcion = TextEditingController(
    text: widget.categoria?.descripcion ?? '',
  );
  late String _tipo = widget.categoria?.tipo ?? 'EGRESO';
  late String _origen = widget.categoria?.origen ?? 'OPERATIVO';
  late bool _activo = widget.categoria?.activo ?? true;
  bool _guardando = false;
  String? _error;

  bool get _esNueva => widget.categoria == null;

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

    final cuerpo = {
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim().isEmpty
          ? null
          : _descripcion.text.trim(),
      'tipo': _tipo,
      'origen': _origen,
      'activo': _activo,
    };

    try {
      final api = ref.read(tesoreriaApiProvider);
      if (_esNueva) {
        await api.crearCategoria(cuerpo);
      } else {
        await api.actualizarCategoria(widget.categoria!.id, cuerpo);
      }
      ref.invalidate(categoriasFinanzasProvider);
      navegador.pop();
      mensajero.mostrar(
        _esNueva ? 'Categoría creada' : 'Categoría actualizada',
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
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              _esNueva
                  ? 'Nueva categoría'
                  : 'Editar ${widget.categoria!.nombre}',
              apoyo:
                  'Operativo suma al resultado del negocio; no operativo va aparte.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              icono: Icons.label_outline,
              pista: 'Alquiler, Luz, Aporte de capital...',
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            Row(
              children: [
                Expanded(
                  child: AppSelector<String>(
                    valor: _tipo,
                    etiqueta: 'Tipo',
                    habilitado: !_guardando,
                    opciones: const [
                      Opcion('INGRESO', 'Ingreso'),
                      Opcion('EGRESO', 'Egreso'),
                    ],
                    onCambio: (v) => setState(() => _tipo = v ?? _tipo),
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: AppSelector<String>(
                    valor: _origen,
                    etiqueta: 'Origen',
                    habilitado: !_guardando,
                    opciones: const [
                      Opcion('OPERATIVO', 'Operativo'),
                      Opcion('NO_OPERATIVO', 'No operativo'),
                    ],
                    onCambio: (v) => setState(() => _origen = v ?? _origen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _descripcion,
              etiqueta: 'Descripción',
              icono: Icons.notes_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            if (!_esNueva) ...[
              const SizedBox(height: Dimen.espacio2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activa', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  'Desactivada no se ofrece en ingresos y egresos nuevos.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _activo,
                onChanged: _guardando
                    ? null
                    : (v) => setState(() => _activo = v),
              ),
            ],
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: _esNueva ? 'Crear' : 'Guardar',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
