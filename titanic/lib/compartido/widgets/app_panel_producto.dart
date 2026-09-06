import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/maestros/datos/producto.dart';
import '../formato.dart';
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
    required this.onAgregar,
    this.paraVenta = true,
    this.stock,
    this.habilitado = true,
  });

  final List<Producto> productos;

  /// Se llama con una línea (desde el panel) o con varias (desde la hoja).
  final void Function(List<LineaElegida>) onAgregar;

  /// Cambia qué presentaciones se ofrecen y si el importe se llama Precio o
  /// Costo: un producto puede venderse por unidad y comprarse solo por saco.
  final bool paraVenta;

  /// Stock disponible por producto en el almacén del documento.
  ///
  /// Es el del almacén desde donde se despacha, no el de toda la empresa:
  /// prometerle a un cliente algo que está en otro depósito es prometer lo
  /// que no hay.
  final Map<int, double>? stock;

  final bool habilitado;

  @override
  State<AppPanelProducto> createState() => _AppPanelProductoState();
}

class _AppPanelProductoState extends State<AppPanelProducto> {
  Producto? _producto;
  int _presentacionId = 0;
  final _cantidad = TextEditingController(text: '1');
  final _importe = TextEditingController(text: '0');

  @override
  void dispose() {
    _cantidad.dispose();
    _importe.dispose();
    super.dispose();
  }

  /// Las presentaciones que valen para este documento, con la base primero.
  List<Presentacion> get _presentaciones {
    final p = _producto;
    if (p == null) return const [];

    return p.presentaciones
        .where((pr) => pr.activo && (widget.paraVenta ? pr.esVenta : pr.esCompra))
        .where((pr) => !pr.esBase)
        .toList();
  }

  void _elegir(Producto producto) {
    setState(() {
      _producto = producto;
      _presentacionId = 0;
      _cantidad.text = '1';

      // Al comprar se propone el costo de referencia; al vender NO, porque eso
      // es lo que costó y no lo que se cobra — proponerlo invita a vender a
      // precio de compra sin darse cuenta.
      _importe.text = widget.paraVenta
          ? '0'
          : formatoNumero(producto.costoReferencia ?? 0);
    });
  }

  void _limpiar() {
    setState(() {
      _producto = null;
      _presentacionId = 0;
      _cantidad.text = '1';
      _importe.text = '0';
    });
  }

  double get _cantidadNum => double.tryParse(_cantidad.text.replaceAll(',', '.')) ?? 0;
  double get _importeNum => double.tryParse(_importe.text.replaceAll(',', '.')) ?? 0;

  bool get _listo => _producto != null && _cantidadNum > 0 && _importeNum > 0;

  void _agregar() {
    final p = _producto;
    if (p == null || !_listo) return;

    String nombrePresentacion = p.unidadBase;
    for (final pr in _presentaciones) {
      if (pr.id == _presentacionId) nombrePresentacion = pr.nombre;
    }

    widget.onAgregar([
      LineaElegida(
        producto: p,
        presentacionId: _presentacionId,
        presentacion: nombrePresentacion,
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
      stock: widget.stock,
    );
    if (elegidos == null || elegidos.isEmpty) return;

    widget.onAgregar([
      for (final e in elegidos)
        LineaElegida(
          producto: e.producto,
          presentacionId: e.presentacionId,
          presentacion: _nombreDe(e.producto, e.presentacionId),
          cantidad: e.cantidad,
          importe: e.importe,
        ),
    ]);
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
            items: widget.productos,
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
            presentaciones: _presentaciones,
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
    required this.presentaciones,
    required this.valor,
    required this.onCambio,
  });

  final bool habilitado;
  final String unidadBase;
  final List<Presentacion> presentaciones;
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
            DropdownMenuItem(
              value: 0,
              child: Text(unidadBase.isEmpty ? 'Unidad' : unidadBase),
            ),
            for (final p in presentaciones)
              DropdownMenuItem(
                value: p.id,
                child: Text('${p.nombre} · ${formatoNumero(p.factor)} $unidadBase'),
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
