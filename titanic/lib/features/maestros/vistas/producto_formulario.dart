import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/catalogo.dart';
import '../datos/maestros_api.dart';
import '../datos/producto.dart';
import '../estado/maestros_controlador.dart';

/// Una presentacion en edicion dentro del formulario. `id` null cuando aun no
/// se guarda: es lo que distingue "agregar" de "actualizar" al sincronizar.
class _FilaPresentacion {
  _FilaPresentacion({
    this.id,
    required this.unidadId,
    required this.unidad,
    required this.nombre,
    required this.factor,
    this.esCompra = true,
    this.esVenta = true,
  });

  final int? id;
  int unidadId;
  String unidad;
  String nombre;
  double factor;
  bool esCompra;
  bool esVenta;
}

/// Alta y edicion de un producto, con sus presentaciones.
class ProductoFormulario extends ConsumerStatefulWidget {
  const ProductoFormulario({super.key, this.producto});

  /// Null cuando es un producto nuevo.
  final Producto? producto;

  @override
  ConsumerState<ProductoFormulario> createState() => _ProductoFormularioState();
}

class _ProductoFormularioState extends ConsumerState<ProductoFormulario>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  late final _codigo = TextEditingController(text: widget.producto?.codigo ?? '');
  late final _nombre = TextEditingController(text: widget.producto?.nombre ?? '');
  late final _descripcion = TextEditingController(text: widget.producto?.descripcion ?? '');
  late final _costoReferencia = TextEditingController(
    text: widget.producto?.costoReferencia == null
        ? ''
        : formatoNumero(widget.producto!.costoReferencia!),
  );
  late final _stockMinimo = TextEditingController(
    text: widget.producto == null ? '' : formatoNumero(widget.producto!.stockMinimo),
  );

  late int? _categoriaId = widget.producto?.categoriaId;
  late int? _marcaId = widget.producto?.marcaId;
  late int? _unidadBaseId = widget.producto?.unidadBaseId;
  late bool _controlaStock = widget.producto?.controlaStock ?? true;

  late final List<_FilaPresentacion> _filas = [
    for (final p in widget.producto?.presentaciones ?? const <Presentacion>[])
      if (!p.esBase)
        _FilaPresentacion(
          id: p.id,
          unidadId: p.unidadId,
          unidad: p.unidad,
          nombre: p.nombre,
          factor: p.factor,
          esCompra: p.esCompra,
          esVenta: p.esVenta,
        ),
  ];

  bool _guardando = false;
  String? _error;
  String? _errorCodigo;
  String? _errorNombre;
  String? _errorUnidad;

  bool get _esNuevo => widget.producto == null;

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [_codigo, _nombre, _descripcion, _costoReferencia, _stockMinimo]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorCodigo = _codigo.text.trim().isEmpty ? 'Ingresa el código.' : null;
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
      _errorUnidad = _unidadBaseId == null ? 'Elige la unidad base.' : null;
    });
    return _errorCodigo == null && _errorNombre == null && _errorUnidad == null;
  }

  double? _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final api = ref.read(maestrosApiProvider);

    final cuerpo = <String, dynamic>{
      'codigo': _codigo.text.trim(),
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'categoriaId': _categoriaId,
      'marcaId': _marcaId,
      'unidadBaseId': _unidadBaseId,
      'costoReferencia': _numero(_costoReferencia.text),
      'controlaStock': _controlaStock,
      'stockMinimo': _controlaStock ? (_numero(_stockMinimo.text) ?? 0) : 0,
      if (!_esNuevo) 'activo': widget.producto!.activo,
    };

    try {
      if (_esNuevo) {
        cuerpo['presentaciones'] = [for (final f in _filas) _cuerpoPresentacion(f)];
        await api.crearProducto(cuerpo);
      } else {
        await api.actualizarProducto(widget.producto!.id, cuerpo);
        await _sincronizarPresentaciones(api);
      }

      await ref.read(productosProvider.notifier).recargar();

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Producto creado' : 'Producto actualizado')),
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  Map<String, dynamic> _cuerpoPresentacion(_FilaPresentacion f) => {
    'unidadId': f.unidadId,
    'nombre': f.nombre,
    'factor': f.factor,
    'esCompra': f.esCompra,
    'esVenta': f.esVenta,
  };

  /// Las presentaciones se guardan una a una: las nuevas se agregan, las que
  /// ya tenian id se actualizan y las que faltan (se borraron en pantalla) se
  /// eliminan.
  Future<void> _sincronizarPresentaciones(MaestrosApi api) async {
    final previas = widget.producto!.presentaciones.where((p) => !p.esBase);
    final actualesIds = _filas.map((f) => f.id).whereType<int>().toSet();

    for (final previa in previas) {
      if (!actualesIds.contains(previa.id)) {
        await api.eliminarPresentacion(previa.id);
      }
    }

    for (final f in _filas) {
      if (f.id == null) {
        await api.agregarPresentacion(widget.producto!.id, _cuerpoPresentacion(f));
      } else {
        await api.actualizarPresentacion(f.id!, _cuerpoPresentacion(f));
      }
    }
  }

  Future<void> _agregarPresentacion() async {
    final unidades = ref.read(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];
    if (unidades.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Todavía no hay unidades registradas.')));
      return;
    }
    final fila = await _mostrarHojaPresentacion(context, unidades: unidades);
    if (fila != null) setState(() => _filas.add(fila));
  }

  Future<void> _editarPresentacion(_FilaPresentacion original) async {
    final unidades = ref.read(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];
    final fila = await _mostrarHojaPresentacion(context, unidades: unidades, existente: original);
    if (fila != null) {
      setState(() {
        final i = _filas.indexOf(original);
        _filas[i] = fila;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'maestros',
      Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo producto' : 'Editar producto',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: 'Datos'),
              Tab(text: 'Presentaciones (${_filas.length})'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Dimen.espacio4,
                    Dimen.espacio3,
                    Dimen.espacio4,
                    0,
                  ),
                  child: AppAlerta(_error!),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_datosTab(), _presentacionesTab()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimen.espacio4,
                  Dimen.espacio3,
                  Dimen.espacio4,
                  Dimen.espacio4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppBoton(
                        texto: 'Cancelar',
                        variante: BotonVariante.secundario,
                        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio3),
                    Expanded(
                      child: AppBoton(
                        texto: _esNuevo ? 'Crear' : 'Guardar',
                        cargando: _guardando,
                        onPressed: _guardar,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datosTab() {
    final categorias = ref.watch(categoriasProvider).valueOrNull ?? const <Categoria>[];
    final marcas = ref.watch(marcasProvider).valueOrNull ?? const <Marca>[];
    final unidades = ref.watch(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: AppCampo(
                controlador: _codigo,
                etiqueta: 'Código',
                icono: Icons.tag,
                maxLargo: 30,
                error: _errorCodigo,
                habilitado: !_guardando,
              ),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              flex: 3,
              child: AppCampo(
                controlador: _nombre,
                etiqueta: 'Nombre',
                icono: Icons.inventory_2_outlined,
                maxLargo: 150,
                error: _errorNombre,
                habilitado: !_guardando,
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
          maxLargo: 500,
          habilitado: !_guardando,
        ),
        const SizedBox(height: Dimen.espacio4),

        Row(
          children: [
            Expanded(
              child: AppSelector<int?>(
                valor: _categoriaId,
                etiqueta: 'Categoría',
                icono: Icons.category_outlined,
                habilitado: !_guardando,
                opciones: [
                  const Opcion<int?>(null, 'Sin categoría'),
                  for (final c in categorias) Opcion<int?>(c.id, c.nombre),
                ],
                onCambio: (v) => setState(() => _categoriaId = v),
              ),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: AppSelector<int?>(
                valor: _marcaId,
                etiqueta: 'Marca',
                icono: Icons.sell_outlined,
                habilitado: !_guardando,
                opciones: [
                  const Opcion<int?>(null, 'Sin marca'),
                  for (final m in marcas) Opcion<int?>(m.id, m.nombre),
                ],
                onCambio: (v) => setState(() => _marcaId = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        AppSelector<int>(
          valor: _unidadBaseId,
          etiqueta: 'Unidad base',
          icono: Icons.straighten_outlined,
          habilitado: _esNuevo && !_guardando,
          error: _errorUnidad,
          opciones: [for (final u in unidades) Opcion(u.id, '${u.nombre} (${u.codigo})')],
          onCambio: (v) => setState(() => _unidadBaseId = v),
        ),
        if (!_esNuevo) ...[
          const SizedBox(height: Dimen.espacio1),
          const Text(
            'No se puede cambiar después de crear el producto.',
            style: TextStyle(fontSize: 11.5, color: Colores.tintaTenue),
          ),
        ],
        const SizedBox(height: Dimen.espacio4),

        AppCampo(
          controlador: _costoReferencia,
          etiqueta: 'Costo de referencia',
          pista: 'Lo que suele costar la unidad base',
          icono: Icons.payments_outlined,
          opcional: true,
          tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
          habilitado: !_guardando,
        ),
        const SizedBox(height: Dimen.espacio2),

        SwitchListTile(
          value: _controlaStock,
          onChanged: _guardando ? null : (v) => setState(() => _controlaStock = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Controla stock', style: TextStyle(fontSize: 14, color: Colores.tinta)),
          subtitle: const Text(
            'Se descuenta en cada salida y avisa cuando llega al mínimo.',
            style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
        ),
        if (_controlaStock) ...[
          const SizedBox(height: Dimen.espacio2),
          AppCampo(
            controlador: _stockMinimo,
            etiqueta: 'Stock mínimo',
            icono: Icons.warning_amber_outlined,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            habilitado: !_guardando,
          ),
        ],
        const SizedBox(height: Dimen.espacio5),
      ],
    );
  }

  Widget _presentacionesTab() {
    final unidades = ref.watch(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];
    final unidadBase = _buscarUnidad(unidades, _unidadBaseId);

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        // La presentacion base la arma sola el backend con la unidad elegida
        // en Datos: aqui solo se ven y editan las presentaciones extra.
        Container(
          padding: const EdgeInsets.all(Dimen.espacio3),
          decoration: BoxDecoration(
            color: Colores.marca.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 17, color: Colores.marca),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: Text(
                  unidadBase == null
                      ? 'Elige la unidad base en Datos para armar la presentación base.'
                      : 'Unidad base: ${unidadBase.nombre} · factor 1 (se crea sola)',
                  style: const TextStyle(fontSize: 12.5, color: Colores.tinta),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Dimen.espacio4),

        for (final fila in _filas) ...[
          _TarjetaPresentacion(
            fila: fila,
            onEditar: () => _editarPresentacion(fila),
            onEliminar: () => setState(() => _filas.remove(fila)),
          ),
          const SizedBox(height: Dimen.espacio2),
        ],
        if (_filas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
            child: Text(
              'Solo tiene la unidad base. Agrega otras formas de comprar o '
              'vender, como un saco o una caja.',
              style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
          ),
        const SizedBox(height: Dimen.espacio2),

        AppBoton(
          texto: 'Agregar presentación',
          variante: BotonVariante.secundario,
          icono: Icons.add,
          onPressed: _guardando ? null : _agregarPresentacion,
        ),
      ],
    );
  }
}

UnidadMedida? _buscarUnidad(List<UnidadMedida> unidades, int? id) {
  for (final u in unidades) {
    if (u.id == id) return u;
  }
  return null;
}

class _TarjetaPresentacion extends StatelessWidget {
  const _TarjetaPresentacion({
    required this.fila,
    required this.onEditar,
    required this.onEliminar,
  });

  final _FilaPresentacion fila;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final usos = [if (fila.esCompra) 'Compra', if (fila.esVenta) 'Venta'];

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fila.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatoNumero(fila.factor)} ${fila.unidad}'
                  '${usos.isEmpty ? '' : ' · ${usos.join(' y ')}'}',
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
          ),
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
          ),
        ],
      ),
    );
  }
}

/// Hoja para agregar o editar una presentacion.
Future<_FilaPresentacion?> _mostrarHojaPresentacion(
  BuildContext context, {
  required List<UnidadMedida> unidades,
  _FilaPresentacion? existente,
}) {
  final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
  final factorCtrl = TextEditingController(
    text: existente == null ? '' : formatoNumero(existente.factor),
  );
  int? unidadId = existente?.unidadId ?? (unidades.length == 1 ? unidades.first.id : null);
  bool esCompra = existente?.esCompra ?? true;
  bool esVenta = existente?.esVenta ?? true;
  String? errorNombre;
  String? errorUnidad;
  String? errorFactor;

  return showModalBottomSheet<_FilaPresentacion>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void guardar() {
            final factor = double.tryParse(factorCtrl.text.trim().replaceAll(',', '.'));

            setSheetState(() {
              errorNombre = nombreCtrl.text.trim().isEmpty ? 'Ingresa un nombre.' : null;
              errorUnidad = unidadId == null ? 'Elige la unidad.' : null;
              errorFactor = factor == null || factor <= 0 ? 'Debe ser mayor que cero.' : null;
            });
            if (errorNombre != null || errorUnidad != null || errorFactor != null) return;

            final unidad = _buscarUnidad(unidades, unidadId);
            Navigator.of(context).pop(
              _FilaPresentacion(
                id: existente?.id,
                unidadId: unidadId!,
                unidad: unidad?.nombre ?? '',
                nombre: nombreCtrl.text.trim(),
                factor: factor!,
                esCompra: esCompra,
                esVenta: esVenta,
              ),
            );
          }

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
                  existente == null ? 'Nueva presentación' : 'Editar presentación',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                const SizedBox(height: Dimen.espacio4),
                AppCampo(
                  controlador: nombreCtrl,
                  etiqueta: 'Nombre',
                  pista: 'Saco de 50, Caja x12...',
                  icono: Icons.label_outline,
                  error: errorNombre,
                ),
                const SizedBox(height: Dimen.espacio4),
                AppSelector<int>(
                  valor: unidadId,
                  etiqueta: 'Unidad',
                  icono: Icons.straighten_outlined,
                  error: errorUnidad,
                  opciones: [for (final u in unidades) Opcion(u.id, '${u.nombre} (${u.codigo})')],
                  onCambio: (v) => setSheetState(() => unidadId = v),
                ),
                const SizedBox(height: Dimen.espacio4),
                AppCampo(
                  controlador: factorCtrl,
                  etiqueta: 'Factor',
                  pista: 'Cuántas unidades base equivale',
                  icono: Icons.calculate_outlined,
                  tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                  error: errorFactor,
                ),
                const SizedBox(height: Dimen.espacio2),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: esCompra,
                        onChanged: (v) => setSheetState(() => esCompra = v ?? true),
                        title: const Text('Compra', style: TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        value: esVenta,
                        onChanged: (v) => setSheetState(() => esVenta = v ?? true),
                        title: const Text('Venta', style: TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimen.espacio4),
                AppBoton(
                  texto: existente == null ? 'Agregar' : 'Guardar cambios',
                  onPressed: guardar,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
