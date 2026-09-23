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
import '../../../compartido/widgets/app_aviso.dart';

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
    this.precioPorPresentacion = false,
  });

  final int? id;
  int unidadId;
  String unidad;
  String nombre;
  double factor;
  bool esCompra;
  bool esVenta;

  /// Los PDF de inventario salen en esta presentacion y no en unidad base. Hay
  /// que llevarlo en la fila: el endpoint reemplaza la presentacion con lo que
  /// le llega, y si la fila no lo recordara se borraria el que puso la web.
  bool precioPorPresentacion;
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

  late final _codigo = TextEditingController(
    text: widget.producto?.codigo ?? '',
  );
  late final _nombre = TextEditingController(
    text: widget.producto?.nombre ?? '',
  );
  late final _descripcion = TextEditingController(
    text: widget.producto?.descripcion ?? '',
  );

  /// El costo llega TAL CUAL, sin redondear: es por unidad base y se guarda
  /// con ocho decimales —S/ 289 el saco de 45.6 kg son 6.33771930 el kilo—.
  /// Lo que este campo muestra es lo que se vuelve a enviar al guardar, asi
  /// que recortarlo a dos decimales cambiaria el costo puesto desde la web
  /// solo por haber abierto el formulario.
  late final _costoReferencia = TextEditingController(
    text: widget.producto?.costoReferencia == null
        ? ''
        : _sinCerosDeMas(widget.producto!.costoReferencia!),
  );

  /// Igual que el costo: por unidad base y sin redondear, para que abrir el formulario y guardar no
  /// cambie lo que se puso desde la web.
  late final _precioReferencia = TextEditingController(
    text: widget.producto?.precioReferencia == null
        ? ''
        : _sinCerosDeMas(widget.producto!.precioReferencia!),
  );
  late final _stockMinimo = TextEditingController(
    text: widget.producto == null
        ? ''
        : formatoNumero(widget.producto!.stockMinimo),
  );
  late final _peso = TextEditingController(
    text: widget.producto?.pesoUnidadBase == null
        ? ''
        : _sinCerosDeMas(widget.producto!.pesoUnidadBase!),
  );

  late int? _categoriaId = widget.producto?.categoriaId;
  late int? _marcaId = widget.producto?.marcaId;
  late int? _unidadBaseId = widget.producto?.unidadBaseId;

  /// El precio de venta ya incluye el IGV cuando el producto es afecto: no se
  /// le suma nada encima al cobrar.
  late bool _afectoIgv = widget.producto?.afectoIgv ?? false;

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
          precioPorPresentacion: p.precioPorPresentacion,
        ),
  ];

  /// Si la unidad base se compra / se vende. Hay productos que solo se
  /// compran y venden por caja o saco: la base sirve para llevar el stock y
  /// descontar (rotos, mermas), no para vender sueltas.
  late bool _baseSeCompra =
      widget.producto?.presentaciones
          .where((p) => p.esBase)
          .firstOrNull
          ?.esCompra ??
      true;
  late bool _baseSeVende =
      widget.producto?.presentaciones
          .where((p) => p.esBase)
          .firstOrNull
          ?.esVenta ??
      true;

  bool _guardando = false;
  String? _error;
  String? _errorCodigo;
  String? _errorNombre;
  String? _errorUnidad;

  bool get _esNuevo => widget.producto == null;

  /// Un numero para teclear encima: 50 y no 50.0, pero 6.3377193 completo.
  static String _sinCerosDeMas(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    // Para que "Valor sin IGV" se recalcule mientras se teclea el precio, no
    // solo al elegir la presentación (que ya dispara un setState propio).
    _precioReferencia.addListener(_repintar);
  }

  void _repintar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _codigo,
      _nombre,
      _descripcion,
      _costoReferencia,
      _precioReferencia,
      _stockMinimo,
      _peso,
    ]) {
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

  double? _numero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

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
    final mensajero = Aviso.de(context);
    final api = ref.read(maestrosApiProvider);

    final cuerpo = <String, dynamic>{
      'codigo': _codigo.text.trim(),
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'categoriaId': _categoriaId,
      'marcaId': _marcaId,
      'unidadBaseId': _unidadBaseId,
      'costoReferencia': _numero(_costoReferencia.text),
      // Viaja SIEMPRE, igual que el peso: el endpoint reemplaza el producto con lo que le llega.
      'precioReferencia': _numero(_precioReferencia.text),
      'afectoIgv': _afectoIgv,
      // Todo producto controla stock: el formulario ya no pregunta, igual que
      // en la web. El campo sigue viajando porque el backend lo espera.
      'controlaStock': true,
      'stockMinimo': _numero(_stockMinimo.text) ?? 0,
      // Viaja SIEMPRE, tambien cuando nadie lo toco: el endpoint REEMPLAZA el
      // producto con lo que le llega, asi que no mandarlo borraria el peso
      // puesto desde la web solo por haber corregido el nombre aqui.
      'pesoUnidadBase': _numero(_peso.text),
      if (!_esNuevo) 'activo': widget.producto!.activo,
    };

    try {
      if (_esNuevo) {
        cuerpo['presentaciones'] = [
          for (final f in _filas) _cuerpoPresentacion(f),
        ];
        final creado = await api.crearProducto(cuerpo);
        // El alta crea la base comprable y vendible: se aplica lo desmarcado.
        final base = creado.presentaciones.where((p) => p.esBase).firstOrNull;
        if (base != null && (!_baseSeCompra || !_baseSeVende)) {
          await _guardarBase(api, base);
        }
      } else {
        await api.actualizarProducto(widget.producto!.id, cuerpo);
        await _sincronizarPresentaciones(api);
      }

      await ref.read(productosProvider.notifier).recargar();

      navegador.pop();
      mensajero.mostrar(_esNuevo ? 'Producto creado' : 'Producto actualizado');
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
    'precioPorPresentacion': f.precioPorPresentacion,
  };

  /// Solo cambia si la base se compra / se vende: lo demas viaja tal como esta
  /// —incluido `precioPorPresentacion`— para que el PUT no lo pise.
  Future<void> _guardarBase(MaestrosApi api, Presentacion base) =>
      api.actualizarPresentacion(base.id, {
        ...base.aJson(),
        'esCompra': _baseSeCompra,
        'esVenta': _baseSeVende,
        'activo': true,
      });

  /// Las presentaciones se guardan una a una: las nuevas se agregan, las que
  /// ya tenian id se actualizan y las que faltan (se borraron en pantalla) se
  /// eliminan.
  Future<void> _sincronizarPresentaciones(MaestrosApi api) async {
    final base = widget.producto!.presentaciones
        .where((p) => p.esBase)
        .firstOrNull;
    if (base != null &&
        (base.esCompra != _baseSeCompra || base.esVenta != _baseSeVende)) {
      await _guardarBase(api, base);
    }

    final previas = widget.producto!.presentaciones.where((p) => !p.esBase);
    final actualesIds = _filas.map((f) => f.id).whereType<int>().toSet();

    for (final previa in previas) {
      if (!actualesIds.contains(previa.id)) {
        await api.eliminarPresentacion(previa.id);
      }
    }

    for (final f in _filas) {
      if (f.id == null) {
        await api.agregarPresentacion(
          widget.producto!.id,
          _cuerpoPresentacion(f),
        );
      } else {
        await api.actualizarPresentacion(f.id!, _cuerpoPresentacion(f));
      }
    }
  }

  Future<void> _agregarPresentacion() async {
    final unidades =
        ref.read(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];
    if (unidades.isEmpty) {
      Aviso.de(context).mostrar('Todavía no hay unidades registradas.');
      return;
    }
    final fila = await _mostrarHojaPresentacion(context, unidades: unidades);
    if (fila != null) setState(() => _filas.add(fila));
  }

  Future<void> _editarPresentacion(_FilaPresentacion original) async {
    final unidades =
        ref.read(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];
    final fila = await _mostrarHojaPresentacion(
      context,
      unidades: unidades,
      existente: original,
    );
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
      (context) => Scaffold(
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
                        onPressed: _guardando
                            ? null
                            : () => Navigator.of(context).pop(),
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

  /*
   * Las presentaciones sobre las que se puede escribir un valor: la base y las que tiene el
   * formulario ahora mismo, aunque todavía no estén guardadas.
   *
   * El costo se escribe sobre las que SE COMPRAN y el precio sobre las que SE VENDEN: ofrecer las
   * otras invita a poner el precio del saco en un producto que solo sale por kilo. El peso no
   * distingue —un saco pesa lo mismo se compre o se venda—.
   */
  List<_OpcionValor> _opcionesDePresentacion(
    List<UnidadMedida> unidades, {
    bool compra = false,
    bool venta = false,
  }) {
    final base =
        unidades.where((u) => u.id == _unidadBaseId).firstOrNull?.codigo ??
        'unidad base';
    bool sirve(bool esCompra, bool esVenta) =>
        (!compra && !venta) || (compra && esCompra) || (venta && esVenta);

    return [
      if (sirve(_baseSeCompra, _baseSeVende)) _OpcionValor(base, 1),
      for (final f in _filas)
        if (f.factor > 0 && sirve(f.esCompra, f.esVenta))
          _OpcionValor(f.nombre, f.factor),
    ];
  }

  Widget _datosTab() {
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? const <Categoria>[];
    final marcas = ref.watch(marcasProvider).valueOrNull ?? const <Marca>[];
    final unidades =
        ref.watch(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];

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
                etiquetaCrear: 'Nueva categoría',
                onCrear: () => _crearRapido(
                  titulo: 'Nueva categoría',
                  etiqueta: 'Nombre',
                  crear: (nombre, _) async {
                    final creada = await ref
                        .read(maestrosApiProvider)
                        .crearCategoria({'nombre': nombre});
                    // Esperar la lista nueva: si se elige lo recien creado antes
                    // de que llegue, el desplegable no lo encuentra.
                    ref.invalidate(categoriasProvider);
                    await ref.read(categoriasProvider.future);
                    return creada.id;
                  },
                  elegir: (id) => _categoriaId = id,
                ),
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
                etiquetaCrear: 'Nueva marca',
                onCrear: () => _crearRapido(
                  titulo: 'Nueva marca',
                  etiqueta: 'Nombre',
                  crear: (nombre, _) async {
                    final creada = await ref
                        .read(maestrosApiProvider)
                        .crearMarca({'nombre': nombre});
                    // Esperar la lista nueva: si se elige lo recien creado antes
                    // de que llegue, el desplegable no lo encuentra.
                    ref.invalidate(marcasProvider);
                    await ref.read(marcasProvider.future);
                    return creada.id;
                  },
                  elegir: (id) => _marcaId = id,
                ),
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
          habilitado: !_guardando,
          error: _errorUnidad,
          etiquetaCrear: 'Nueva unidad',
          onCrear: () => _crearRapido(
            titulo: 'Nueva unidad de medida',
            etiqueta: 'Nombre',
            conCodigo: true,
            crear: (nombre, codigo) async {
              final creada = await ref.read(maestrosApiProvider).crearUnidad({
                'nombre': nombre,
                'codigo': codigo,
                // Conteo y no fraccionable: es lo que vale para casi todo
                // —sacos, cajas, unidades— y el catalogo deja afinarlo.
                'tipo': 'CONTEO',
                'fraccionable': false,
              });
              // Esperar la lista nueva: si se elige lo recien creado antes
              // de que llegue, el desplegable no lo encuentra.
              ref.invalidate(unidadesProvider);
              await ref.read(unidadesProvider.future);
              return creada.id;
            },
            elegir: (id) => _unidadBaseId = id,
          ),
          opciones: [
            for (final u in unidades) Opcion(u.id, '${u.nombre} (${u.codigo})'),
          ],
          onCambio: (v) => setState(() => _unidadBaseId = v),
        ),
        // Cambiarla no reescribe el pasado: lo que ya se movio se conto en la
        // unidad anterior y de UND a KG no hay factor que convierta.
        if (!_esNuevo &&
            (widget.producto?.tieneMovimientos ?? false) &&
            _unidadBaseId != widget.producto?.unidadBaseId) ...[
          const SizedBox(height: Dimen.espacio2),
          const AppAlerta(
            'Lo ya registrado (stock, kardex y costos) se queda como está: '
            'se contó en la unidad anterior y no se convierte.',
            tono: AlertaTono.aviso,
          ),
        ],
        const SizedBox(height: Dimen.espacio4),

        // Se escribe como se dice en el almacén —S/ 170 el saco— y se guarda por unidad base.
        _ValorPorPresentacion(
          controladorBase: _costoReferencia,
          etiqueta: 'Costo de referencia',
          pista: '170.00',
          icono: Icons.payments_outlined,
          decimales: 2,
          opciones: _opcionesDePresentacion(unidades, compra: true),
          habilitado: !_guardando,
        ),
        const SizedBox(height: Dimen.espacio3),

        // A cuánto se vende, como respaldo: sale cuando el pedido no lleva lista o la lista no
        // tiene esa presentación. La lista manda sobre él.
        _ValorPorPresentacion(
          controladorBase: _precioReferencia,
          etiqueta: 'Precio de venta',
          pista: '310.00',
          icono: Icons.sell_outlined,
          decimales: 2,
          opciones: _opcionesDePresentacion(unidades, venta: true),
          habilitado: !_guardando,
        ),
        // El precio se escribe TAL COMO SE COBRA: si el producto paga IGV, ya
        // viene incluido, no se le suma nada encima al vender.
        CheckboxListTile(
          value: _afectoIgv,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Afecto a IGV', style: TextStyle(fontSize: 13.5)),
          onChanged: _guardando
              ? null
              : (v) => setState(() => _afectoIgv = v ?? false),
        ),
        if (_afectoIgv && (_numero(_precioReferencia.text) ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Valor sin IGV: S/ '
              '${(_numero(_precioReferencia.text)! / 1.18).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colores.tinta),
            ),
          ),
        const SizedBox(height: Dimen.espacio3),

        AppCampo(
          controlador: _stockMinimo,
          etiqueta: 'Stock mínimo',
          icono: Icons.warning_amber_outlined,
          tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
          habilitado: !_guardando,
        ),
        const SizedBox(height: Dimen.espacio2),

        // Cuánto pesa, escrito sobre la presentación que se tiene delante (50 kg el saco). Se
        // guarda por unidad base, y de ahí sale lo que pesa cualquier cantidad: una caja, un
        // pedido, el camión entero.
        _ValorPorPresentacion(
          controladorBase: _peso,
          etiqueta: 'Peso (kg)',
          pista: '50',
          icono: Icons.scale_outlined,
          decimales: 3,
          opciones: _opcionesDePresentacion(unidades),
          habilitado: !_guardando,
        ),
        const SizedBox(height: Dimen.espacio5),
      ],
    );
  }

  /*
   * Dar de alta un catalogo sin salir del formulario.
   *
   * El caso es siempre el mismo: se esta creando un producto y su categoria no
   * existe todavia. Sin esto hay que abandonar lo escrito, ir al catalogo,
   * crearla y volver a empezar. Se pide lo minimo —el nombre, y el codigo si
   * es una unidad— y lo recien creado queda elegido.
   */
  Future<void> _crearRapido({
    required String titulo,
    required String etiqueta,
    bool conCodigo = false,
    required Future<int> Function(String nombre, String codigo) crear,
    required void Function(int id) elegir,
  }) async {
    final nombre = TextEditingController();
    final codigo = TextEditingController();
    var guardando = false;
    String? error;

    final creadoId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setHoja) => Padding(
          padding: EdgeInsets.only(
            left: Dimen.espacio4,
            right: Dimen.espacio4,
            top: Dimen.espacio4,
            bottom: MediaQuery.of(contexto).viewInsets.bottom + Dimen.espacio4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Dimen.espacio4),
              if (error != null) ...[
                AppAlerta(error!),
                const SizedBox(height: Dimen.espacio3),
              ],
              AppCampo(
                controlador: nombre,
                etiqueta: etiqueta,
                habilitado: !guardando,
              ),
              if (conCodigo) ...[
                const SizedBox(height: Dimen.espacio3),
                AppCampo(
                  controlador: codigo,
                  etiqueta: 'Código',
                  pista: 'KG, UND, SAC',
                  habilitado: !guardando,
                ),
              ],
              const SizedBox(height: Dimen.espacio4),
              AppBoton(
                texto: 'Crear',
                cargando: guardando,
                onPressed: () async {
                  if (nombre.text.trim().isEmpty) {
                    setHoja(() => error = 'Ingresa el nombre.');
                    return;
                  }
                  if (conCodigo && codigo.text.trim().isEmpty) {
                    setHoja(() => error = 'Ingresa el código.');
                    return;
                  }

                  setHoja(() {
                    guardando = true;
                    error = null;
                  });

                  try {
                    final id = await crear(
                      nombre.text.trim(),
                      codigo.text.trim(),
                    );
                    if (contexto.mounted) Navigator.pop(contexto, id);
                  } on ApiExcepcion catch (e) {
                    setHoja(() {
                      guardando = false;
                      error = e.mensaje;
                    });
                  }
                },
              ),
              const SizedBox(height: Dimen.espacio2),
            ],
          ),
        ),
      ),
    );

    nombre.dispose();
    codigo.dispose();

    if (creadoId != null && mounted) setState(() => elegir(creadoId));
  }

  Widget _presentacionesTab() {
    final unidades =
        ref.watch(unidadesProvider).valueOrNull ?? const <UnidadMedida>[];
    final unidadBase = _buscarUnidad(unidades, _unidadBaseId);

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        // La presentacion base la arma sola el backend con la unidad elegida
        // en Datos: aqui solo se ven y editan las presentaciones extra.
        Container(
          padding: const EdgeInsets.all(Dimen.espacio3),
          decoration: BoxDecoration(
            color: Acento.de(context).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: Acento.de(context),
              ),
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
        CheckboxListTile(
          value: _baseSeCompra,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'La unidad base se compra',
            style: TextStyle(fontSize: 13.5),
          ),
          onChanged: _guardando
              ? null
              : (v) => setState(() => _baseSeCompra = v ?? true),
        ),
        CheckboxListTile(
          value: _baseSeVende,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'La unidad base se vende',
            style: TextStyle(fontSize: 13.5),
          ),
          subtitle: const Text(
            'Desmárcala si solo se vende por caja o saco: la unidad suelta '
            'queda para llevar el stock y descontar rotos.',
            style: TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
          ),
          onChanged: _guardando
              ? null
              : (v) => setState(() => _baseSeVende = v ?? true),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.tintaSuave,
                  ),
                ),
                // Solo cuando esta puesto: apagado es lo normal y no hace falta
                // decirlo en cada tarjeta.
                if (fila.precioPorPresentacion)
                  const Text(
                    'PDF por presentación',
                    style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                  ),
              ],
            ),
          ),
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
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Quitar',
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
  int? unidadId =
      existente?.unidadId ?? (unidades.length == 1 ? unidades.first.id : null);
  bool esCompra = existente?.esCompra ?? true;
  bool esVenta = existente?.esVenta ?? true;
  bool precioPorPresentacion = existente?.precioPorPresentacion ?? false;
  String? errorNombre;
  String? errorUnidad;
  String? errorFactor;

  return showModalBottomSheet<_FilaPresentacion>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void guardar() {
            final factor = double.tryParse(
              factorCtrl.text.trim().replaceAll(',', '.'),
            );

            setSheetState(() {
              errorNombre = nombreCtrl.text.trim().isEmpty
                  ? 'Ingresa un nombre.'
                  : null;
              errorUnidad = unidadId == null ? 'Elige la unidad.' : null;
              errorFactor = factor == null || factor <= 0
                  ? 'Debe ser mayor que cero.'
                  : null;
            });
            if (errorNombre != null ||
                errorUnidad != null ||
                errorFactor != null)
              return;

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
                // Se arma una fila nueva: sin pasarlo aqui, editar el nombre o
                // el factor de una presentacion apagaria el marcador.
                precioPorPresentacion: precioPorPresentacion,
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
            // Con scroll: con el teclado abierto sobre el factor y la linea de
            // "Por presentación (PDF)" de mas, la hoja ya no entra en pantallas
            // chicas y el boton de guardar quedaria tapado.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existente == null
                        ? 'Nueva presentación'
                        : 'Editar presentación',
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
                    opciones: [
                      for (final u in unidades)
                        Opcion(u.id, '${u.nombre} (${u.codigo})'),
                    ],
                    onCambio: (v) => setSheetState(() => unidadId = v),
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  AppCampo(
                    controlador: factorCtrl,
                    etiqueta: 'Factor',
                    pista: 'Cuántas unidades base equivale',
                    icono: Icons.calculate_outlined,
                    tipoTeclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    error: errorFactor,
                  ),
                  const SizedBox(height: Dimen.espacio2),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: esCompra,
                          onChanged: (v) =>
                              setSheetState(() => esCompra = v ?? true),
                          title: const Text(
                            'Compra',
                            style: TextStyle(fontSize: 13),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: esVenta,
                          onChanged: (v) =>
                              setSheetState(() => esVenta = v ?? true),
                          title: const Text(
                            'Venta',
                            style: TextStyle(fontSize: 13),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  // Solo en las presentaciones extra: esta hoja nunca edita la
                  // base, donde "por presentacion" y "por unidad base" son lo mismo.
                  CheckboxListTile(
                    value: precioPorPresentacion,
                    onChanged: (v) =>
                        setSheetState(() => precioPorPresentacion = v ?? false),
                    title: const Text(
                      'Por presentación (PDF)',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: const Text(
                      'En los PDF (pedidos, ventas, compras, ajustes, transferencias y '
                      'préstamos) la línea sale en esta presentación. Sin marcar, '
                      'sale en unidad base.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colores.tintaSuave,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  AppBoton(
                    texto: existente == null ? 'Agregar' : 'Guardar cambios',
                    onPressed: guardar,
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Una forma de decir el valor: "Saco 50 kg" pesa 50 veces la unidad base.
class _OpcionValor {
  const _OpcionValor(this.nombre, this.factor);

  final String nombre;
  final double factor;
}

/// Un valor del producto escrito por presentación y guardado por unidad base.
///
/// Se escribe como se dice en el almacén —S/ 170 el saco, 50 kg el saco— y se guarda por unidad
/// base —S/ 3.40 el kilo, 1 kg el kilo—, que es como lo necesita todo lo demás. Arranca en la
/// presentación MÁS GRANDE, que es la que se tiene en la cabeza: escribir 310 sobre el kilo y que
/// quede en 15 500 el saco es el error que esto evita.
///
/// El controlador que recibe guarda SIEMPRE el valor por unidad base: el resto del formulario lo lee
/// y lo envía tal cual, sin saber que aquí se escribe distinto.
class _ValorPorPresentacion extends StatefulWidget {
  const _ValorPorPresentacion({
    required this.controladorBase,
    required this.etiqueta,
    required this.pista,
    required this.icono,
    required this.decimales,
    required this.opciones,
    required this.habilitado,
  });

  final TextEditingController controladorBase;
  final String etiqueta;
  final String pista;
  final IconData icono;

  /// Con cuántos decimales vuelve exacto el número a la presentación: dos para la plata, tres para
  /// el peso (un sobre de 30 g pesa 0.03 kg).
  final int decimales;
  final List<_OpcionValor> opciones;
  final bool habilitado;

  @override
  State<_ValorPorPresentacion> createState() => _ValorPorPresentacionState();
}

class _ValorPorPresentacionState extends State<_ValorPorPresentacion> {
  final _texto = TextEditingController();
  String? _elegida;

  static String _limpio(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  _OpcionValor? get _opcion {
    for (final o in widget.opciones) {
      if (o.nombre == _elegida) return o;
    }
    return null;
  }

  double get _factor => _opcion?.factor ?? 1;

  /// La más grande de las que se ofrecen; a igualdad, la primera.
  _OpcionValor? _masGrande() {
    _OpcionValor? mayor;
    for (final o in widget.opciones) {
      if (mayor == null || o.factor > mayor.factor) mayor = o;
    }
    return mayor;
  }

  @override
  void initState() {
    super.initState();
    _elegida = _masGrande()?.nombre;
    _texto.text = _deBaseAPresentacion();
    _texto.addListener(_alEscribir);
  }

  @override
  void didUpdateWidget(covariant _ValorPorPresentacion anterior) {
    super.didUpdateWidget(anterior);
    // La presentación elegida ya no existe (la quitaron en la otra pestaña): se vuelve a la más
    // grande y el número escrito se conserva.
    if (_opcion == null && widget.opciones.isNotEmpty) {
      _elegida = _masGrande()?.nombre;
      _alEscribir();
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  String _deBaseAPresentacion() {
    final base = double.tryParse(
      widget.controladorBase.text.replaceAll(',', '.'),
    );
    if (base == null) return '';
    // Sin ceros de más: 280 y no 280.00.
    return _limpio(
      double.parse((base * _factor).toStringAsFixed(widget.decimales)),
    );
  }

  void _alEscribir() {
    final n = double.tryParse(_texto.text.replaceAll(',', '.'));
    widget.controladorBase.text = n == null ? '' : _limpio(n / _factor);
  }

  /// Cambiar de presentación conserva el número y cambia a qué se refiere: si tecleaste 170 pensando
  /// en el saco y estaba el kilo, corriges el selector y sigue siendo 170 el saco.
  void _cambiar(String? nombre) {
    setState(() => _elegida = nombre);
    _alEscribir();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: AppCampo(
            controlador: _texto,
            etiqueta: widget.etiqueta,
            pista: widget.pista,
            icono: widget.icono,
            opcional: true,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            habilitado: widget.habilitado,
          ),
        ),
        const SizedBox(width: Dimen.espacio2),
        Expanded(
          flex: 6,
          child: AppSelector<String>(
            valor: _elegida,
            etiqueta: 'Por',
            icono: Icons.straighten,
            habilitado: widget.habilitado && widget.opciones.length > 1,
            opciones: [
              for (final o in widget.opciones) Opcion(o.nombre, o.nombre),
            ],
            onCambio: _cambiar,
          ),
        ),
      ],
    );
  }
}
