import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/maestros/datos/producto.dart';
import '../formato.dart';
import '../presentaciones_uso.dart';
import 'app_boton.dart';
import 'app_buscador_productos.dart';
import 'app_campo_busqueda.dart';

/// Una línea lista para agregarse al documento.
class LineaElegida {
  const LineaElegida({
    required this.producto,
    required this.presentacionId,
    required this.presentacion,
    required this.cantidad,
    required this.importe,
  });

  final Producto producto;

  /// 0 = la unidad base. Es lo que espera el backend cuando no hay presentación.
  final int presentacionId;
  final String presentacion;

  final double cantidad;

  /// Precio si se vende, costo si se compra.
  final double importe;
}

/// Panel para agregar productos a un documento, uno a uno o varios de golpe.
///
/// Sustituye al botón suelto que abría directamente la hoja de selección
/// múltiple. Esa hoja sigue ahí, en la lupa, porque es la buena para cargar
/// diez productos de un pedido; pero tapaba la pantalla también cuando lo que
/// hacía falta era añadir UNO cuyo nombre ya se conoce, que es la mitad de las
/// veces. Ahora eso se hace escribiendo aquí mismo.
class AppPanelProducto extends StatefulWidget {
  const AppPanelProducto({
    super.key,
    required this.productos,
    this.cargando = false,
    required this.onAgregar,
    this.paraVenta = true,
    this.uso,
    this.stock,
    this.habilitado = true,
    this.resolverPrecio,
  });

  final List<Producto> productos;

  /// El catálogo todavía viene del servidor.
  final bool cargando;

  /// Se llama con una línea (desde el panel) o con varias (desde la hoja).
  final void Function(List<LineaElegida>) onAgregar;

  /// Decide si el importe se llama Precio o Costo y qué se propone como
  /// importe: un producto puede venderse por unidad y comprarse solo por saco.
  final bool paraVenta;

  /// Para qué se arma la línea: decide qué unidades se ofrecen, la base
  /// incluida (un producto puede venderse solo por caja). Lo pasan pedidos,
  /// notas de venta, órdenes de compra y compras.
  ///
  /// Se separa de [paraVenta] porque los documentos de inventario también
  /// piden "Costo" y no deben filtrarse por estas marcas: sin [uso] la unidad
  /// base siempre se ofrece y las demás siguen la marca de [paraVenta], como
  /// antes de que la base tuviera marcas.
  final UsoPresentacion? uso;

  /// Stock disponible por producto en el almacén del documento.
  ///
  /// Es el del almacén desde donde se despacha, no el de toda la empresa:
  /// prometerle a un cliente algo que está en otro depósito es prometer lo
  /// que no hay.
  final Map<int, double>? stock;

  final bool habilitado;

  /// De dónde sale el precio, cuando lo pone una lista y no el vendedor.
  ///
  /// Recibe la presentación real y la cantidad, porque el precio depende de
  /// cuánto se lleva —el tramo "desde 5 sacos" es más barato—. Devuelve null
  /// si esa forma de vender no tiene precio cargado.
  ///
  /// Sin esto el vendedor teclea el precio de memoria, que es como se cobra de
  /// menos sin que nadie se entere.
  final Future<double?> Function(int presentacionId, double cantidad)? resolverPrecio;

  @override
  State<AppPanelProducto> createState() => _AppPanelProductoState();
}

class _AppPanelProductoState extends State<AppPanelProducto> {
  Producto? _producto;
  int _presentacionId = 0;
  final _cantidad = TextEditingController(text: '1');
  final _importe = TextEditingController(text: '0');

  /// Qué dijo la lista: para avisar cuando no hay precio o cuando se cambió.
  double? _precioLista;
  bool _buscandoPrecio = false;
  bool _sinPrecioEnLista = false;

  @override
  void initState() {
    super.initState();
    // La cantidad manda sobre el tramo: 4 sacos y 5 sacos no valen lo mismo.
    _cantidad.addListener(_pedirPrecio);
  }

  @override
  void dispose() {
    _cantidad.removeListener(_pedirPrecio);
    _cantidad.dispose();
    _importe.dispose();
    super.dispose();
  }

  /// La regla con la que se ofrecen las unidades. Sin `uso` (inventario) la base
  /// va siempre y las demás siguen la marca de paraVenta, como antes de que la
  /// base tuviera marcas propias.
  UsoPresentacion get _uso =>
      widget.uso ?? (widget.paraVenta ? UsoPresentacion.venta : UsoPresentacion.compra);
  bool get _baseSiempre => widget.uso == null;

  /// Solo los productos que tienen con qué armar la línea en este documento.
  List<Producto> get _ofrecidos =>
      productosConOpcion(widget.productos, widget.uso, baseSiempre: _baseSiempre);

  /// Las unidades que valen para el producto elegido, con la base primero si
  /// se puede usar.
  List<OpcionPresentacion> get _opciones {
    final p = _producto;
    if (p == null) return const [];

    return opcionesPresentacion(
      unidadBase: p.unidadBase,
      presentaciones: p.presentaciones,
      uso: _uso,
      baseSiempre: _baseSiempre,
    );
  }

  /// La presentación real: 0 en el selector significa la unidad base, que sí
  /// tiene su propia presentación con precio propio.
  int get _presentacionReal {
    if (_presentacionId != 0) return _presentacionId;
    final base = _producto?.presentaciones.where((p) => p.esBase);
    return base != null && base.isNotEmpty ? base.first.id : 0;
  }

  /*
   * El precio, preguntado a la lista.
   *
   * Se vuelve a pedir al cambiar producto, unidad o cantidad, y no solo al
   * elegir el producto: resolver una sola vez dejaria el descuento por volumen
   * sin aplicarse nunca. Queda editable —un precio especial a un cliente sigue
   * siendo cosa de todos los dias— pero ya no se teclea a ciegas.
   */
  Future<void> _pedirPrecio() async {
    final resolver = widget.resolverPrecio;
    if (resolver == null || _producto == null || _presentacionReal == 0) return;

    final cantidad = _cantidadNum > 0 ? _cantidadNum : 1.0;
    setState(() => _buscandoPrecio = true);

    try {
      final precio = await resolver(_presentacionReal, cantidad);
      if (!mounted) return;

      setState(() {
        _precioLista = precio;
        _sinPrecioEnLista = precio == null;
        if (precio != null) _importe.text = formatoNumero(precio);
      });
    } finally {
      if (mounted) setState(() => _buscandoPrecio = false);
    }
  }

  void _elegir(Producto producto) {
    setState(() {
      _producto = producto;
      // Arranca con la base si esa se puede usar; si no, con la primera
      // presentación que sí. Empezar siempre en 0 dejaba una línea por unidades
      // sueltas de algo que solo se vende por caja.
      _presentacionId =
          presentacionInicial(producto, _uso, baseSiempre: _baseSiempre) ?? 0;
      _cantidad.text = '1';

      // Al comprar se propone el costo de referencia; al vender NO, porque eso
      // es lo que costó y no lo que se cobra — proponerlo invita a vender a
      // precio de compra sin darse cuenta.
      _importe.text = widget.paraVenta
          ? '0'
          : formatoNumero(producto.costoReferencia ?? 0);
      _precioLista = null;
      _sinPrecioEnLista = false;
    });

    unawaited(_pedirPrecio());
  }

  void _limpiar() {
    setState(() {
      _producto = null;
      _presentacionId = 0;
      _cantidad.text = '1';
      _importe.text = '0';
      _precioLista = null;
      _sinPrecioEnLista = false;
    });
  }

  /// Si lo escrito ya no es lo que dice la lista.
  bool get _precioPisado =>
      _precioLista != null && (_importeNum - _precioLista!).abs() > 0.001;

  String? get _avisoPrecio {
    if (widget.resolverPrecio == null || _producto == null) return null;
    if (_buscandoPrecio) return 'Buscando en la lista...';
    if (_sinPrecioEnLista) return 'Sin precio en la lista';
    if (_precioLista == null) return null;
    if (_precioPisado) return 'Lista: ${formatoSoles(_precioLista!)}';
    return 'De la lista';
  }

  double get _cantidadNum => double.tryParse(_cantidad.text.replaceAll(',', '.')) ?? 0;
  double get _importeNum => double.tryParse(_importe.text.replaceAll(',', '.')) ?? 0;

  bool get _listo => _producto != null && _cantidadNum > 0 && _importeNum > 0;

  void _agregar() {
    final p = _producto;
    if (p == null || !_listo) return;

    widget.onAgregar([
      LineaElegida(
        producto: p,
        presentacionId: _presentacionId,
        presentacion: _nombreDe(p, _presentacionId),
        cantidad: _cantidadNum,
        importe: _importeNum,
      ),
    ]);

    _limpiar();
  }

  Future<void> _abrirHoja() async {
    final elegidos = await mostrarBuscadorProductos(
      context: context,
      productos: widget.productos,
      paraVenta: widget.paraVenta,
      uso: widget.uso,
      stock: widget.stock,
    );
    if (elegidos == null || elegidos.isEmpty) return;

    /*
     * El precio se pide a la lista igual que al agregar de a uno: sin esto todo lo que entraba por
     * la búsqueda avanzada quedaba en cero y había que teclear cada precio a mano. Se piden juntos
     * y un precio que no llegue no frena a los demás.
     */
    final resolver = widget.resolverPrecio;
    final importes = await Future.wait([
      for (final e in elegidos) _precioDeLista(resolver, e),
    ]);
    if (!mounted) return;

    widget.onAgregar([
      for (var i = 0; i < elegidos.length; i++)
        LineaElegida(
          producto: elegidos[i].producto,
          presentacionId: elegidos[i].presentacionId,
          presentacion: _nombreDe(elegidos[i].producto, elegidos[i].presentacionId),
          cantidad: elegidos[i].cantidad,
          importe: importes[i] ?? elegidos[i].importe,
        ),
    ]);
  }

  /// El precio de la lista para una selección de la búsqueda avanzada, o null si no lo hay.
  Future<double?> _precioDeLista(
    Future<double?> Function(int presentacionId, double cantidad)? resolver,
    SeleccionProducto e,
  ) async {
    if (resolver == null) return null;

    var real = e.presentacionId;
    if (real == 0) {
      // La unidad base tiene su propia presentación, con su propio precio.
      final base = e.producto.presentaciones.where((p) => p.esBase);
      real = base.isNotEmpty ? base.first.id : 0;
    }
    if (real == 0) return null;

    try {
      return await resolver(real, e.cantidad);
    } catch (_) {
      return null;
    }
  }

  String _nombreDe(Producto p, int presentacionId) {
    if (presentacionId == 0) return p.unidadBase;
    for (final pr in p.presentaciones) {
      if (pr.id == presentacionId) return pr.nombre;
    }
    return p.unidadBase;
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio4),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Buscar producto',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampoBusqueda<Producto>(
            etiqueta: 'Producto',
            icono: Icons.inventory_2_outlined,
            pista: 'Escribe el nombre o el código',
            // Un producto que no se vende (o no se compra) en ninguna
            // presentación no se ofrece: no habría unidad con qué armar la línea.
            items: _ofrecidos,
            cargando: widget.cargando,
            habilitado: widget.habilitado,
            textoElegido: _producto?.nombre,
            titulo: (p) => p.nombre,
            subtitulo: (p) {
              final partes = <String>[p.codigo];
              if (p.marca != null && p.marca!.isNotEmpty) partes.add(p.marca!);
              if (p.categoria != null && p.categoria!.isNotEmpty) partes.add(p.categoria!);

              // El stock va en el subtítulo y no en una columna aparte porque
              // en el móvil no hay ancho para las dos cosas, y sin él la
              // lista serviría para elegir lo que no se puede despachar.
              final hay = stock?[p.id];
              if (hay != null) partes.add('${formatoNumero(hay)} ${p.unidadBase}');
              return partes.join(' · ');
            },
            buscable: (p) => p.buscable,
            // Sin botón de filtros aquí: el catálogo se busca escribiendo el
            // nombre o el código, que es lo que se sabe con el producto en la
            // mano. Filtrar por categoría y marca es para cuando se está
            // explorando, y eso ya vive dentro de la hoja de la lupa.
            onElegir: _elegir,
            // La lupa lleva a la hoja de selección múltiple, que es lo que
            // sirve para cargar un documento largo de una sentada.
            onBusquedaAmpliada: widget.habilitado ? _abrirHoja : null,
          ),
          const SizedBox(height: Dimen.espacio3),

          _SelectorUnidad(
            habilitado: widget.habilitado && _producto != null,
            unidadBase: _producto?.unidadBase ?? '',
            opciones: _opciones,
            valor: _presentacionId,
            onCambio: (v) => setState(() => _presentacionId = v),
          ),
          const SizedBox(height: Dimen.espacio3),

          Row(
            children: [
              Expanded(
                child: _CampoNumero(
                  etiqueta: 'Cantidad',
                  controlador: _cantidad,
                  habilitado: widget.habilitado && _producto != null,
                  onCambio: () => setState(() {}),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: _CampoNumero(
                  etiqueta: widget.paraVenta ? 'Precio S/' : 'Costo S/',
                  controlador: _importe,
                  habilitado: widget.habilitado && _producto != null,
                  onCambio: () => setState(() {}),
                ),
              ),
            ],
          ),

          // Qué dijo la lista. Sin precio cargado la venta saldría en cero sin
          // que nadie chille: mejor decirlo aquí, antes de agregar la línea.
          if (_avisoPrecio != null) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              _avisoPrecio!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _sinPrecioEnLista || _precioPisado
                    ? Colores.advertencia
                    : Colores.tintaSuave,
              ),
            ),
          ],

          const SizedBox(height: Dimen.espacio4),

          AppBoton(
            texto: 'Agregar producto',
            icono: Icons.add,
            onPressed: widget.habilitado && _listo ? _agregar : null,
          ),
        ],
      ),
    );
  }
}

/// La unidad en la que se carga la línea: la base o una presentación.
class _SelectorUnidad extends StatelessWidget {
  const _SelectorUnidad({
    required this.habilitado,
    required this.unidadBase,
    required this.opciones,
    required this.valor,
    required this.onCambio,
  });

  final bool habilitado;
  final String unidadBase;
  final List<OpcionPresentacion> opciones;
  final int valor;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Unidad',
        prefixIcon: const Icon(Icons.straighten, size: 19, color: Colores.tintaTenue),
        enabled: habilitado,
        constraints: const BoxConstraints(minHeight: Dimen.campoLg),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: valor,
          isExpanded: true,
          items: [
            // Sin producto elegido no hay opciones, pero el desplegable
            // necesita un ítem con el valor actual: se deja el rótulo genérico.
            if (opciones.isEmpty)
              DropdownMenuItem(
                value: valor,
                child: Text(unidadBase.isEmpty ? 'Unidad' : unidadBase),
              ),
            for (final o in opciones)
              DropdownMenuItem(
                value: o.valor,
                // La base es solo su código; las presentaciones dicen cuánto
                // equivalen.
                child: Text(
                  o.valor == 0
                      ? (o.nombre.isEmpty ? 'Unidad' : o.nombre)
                      : '${o.nombre} · ${formatoNumero(o.factor)} $unidadBase',
                ),
              ),
          ],
          onChanged: habilitado ? (v) => onCambio(v ?? 0) : null,
          style: const TextStyle(fontSize: 15, color: Colores.tinta),
        ),
      ),
    );
  }
}

class _CampoNumero extends StatelessWidget {
  const _CampoNumero({
    required this.etiqueta,
    required this.controlador,
    required this.habilitado,
    required this.onCambio,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final bool habilitado;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      enabled: habilitado,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onCambio(),
      style: const TextStyle(fontSize: 15, color: Colores.tinta),
      decoration: InputDecoration(
        labelText: etiqueta,
        constraints: const BoxConstraints(minHeight: Dimen.campoLg),
      ),
    );
  }
}
