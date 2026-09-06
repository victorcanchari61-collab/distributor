import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/maestros/datos/producto.dart';
import 'app_boton.dart';
import 'app_buscador.dart';
import 'app_filtros_en_linea.dart';
import 'app_vacio.dart';

/// Un producto marcado en el buscador, con como se va a cargar la linea.
class SeleccionProducto {
  const SeleccionProducto({
    required this.producto,
    required this.presentacionId,
    required this.cantidad,
    required this.importe,
  });

  final Producto producto;

  /// 0 es la unidad base; cualquier otro es una presentacion del producto.
  final int presentacionId;

  final double cantidad;

  /// Precio de venta o costo de compra de UNA presentacion completa, segun
  /// para que se abrio el buscador.
  final double importe;
}

/// Un numero sin decimales de mas: 12 en vez de 12.0.
String _texto2(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Estado de una fila mientras la hoja esta abierta.
class _Marcado {
  _Marcado({required this.presentacionId, required this.cantidad, required this.importe});

  int presentacionId;
  String cantidad;
  String importe;
}

/// Buscar productos y agregar VARIOS de una sola vez.
///
/// Antes se elegia un producto, se abria otra hoja para la unidad y la
/// cantidad, y se repetia: cargar cinco productos eran diez pasos. Aca se
/// marcan todos, se les pone unidad y cantidad en la misma fila, y se agregan
/// juntos.
///
/// El importe se pide en la misma fila. En el movil no hay tabla editable como
/// en la web: cada linea se corrige abriendo otra hoja, asi que si aca no se
/// capturara el precio, agregar cinco productos seguiria costando cinco hojas
/// mas y la carga masiva no serviria de nada.
///
/// [paraVenta] cambia dos cosas: que presentaciones se ofrecen (un producto
/// puede venderse por unidad y comprarse solo por saco) y si el importe se
/// llama Precio o Costo.
Future<List<SeleccionProducto>?> mostrarBuscadorProductos({
  required BuildContext context,
  required List<Producto> productos,
  bool paraVenta = true,
  Map<int, double>? stock,
}) {
  return showModalBottomSheet<List<SeleccionProducto>>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) => _HojaBuscadorProductos(
      productos: productos,
      paraVenta: paraVenta,
      stock: stock,
    ),
  );
}

class _HojaBuscadorProductos extends StatefulWidget {
  const _HojaBuscadorProductos({
    required this.productos,
    required this.paraVenta,
    this.stock,
  });

  final List<Producto> productos;
  final bool paraVenta;
  final Map<int, double>? stock;

  @override
  State<_HojaBuscadorProductos> createState() => _HojaBuscadorProductosState();
}

class _HojaBuscadorProductosState extends State<_HojaBuscadorProductos> {
  String _texto = '';

  /// Filtros que se despliegan con el boton de al lado del buscador.
  bool _filtrosAbiertos = false;
  String? _categoria;
  String? _marca;

  /// Lo marcado, por id de producto. Se conserva aunque el filtro lo esconda:
  /// buscar otra cosa no deberia perder lo que ya se eligio.
  final Map<int, _Marcado> _marcados = {};

  List<Producto> get _visibles {
    final texto = _texto.trim().toLowerCase();

    return widget.productos.where((p) {
      if (texto.isNotEmpty && !p.buscable.contains(texto)) return false;
      if (_categoria != null && p.categoria != _categoria) return false;
      if (_marca != null && p.marca != _marca) return false;
      return true;
    }).toList();
  }

  /// Las presentaciones que aplican, con la unidad base siempre primero.
  List<Presentacion> _presentacionesDe(Producto p) => p.presentaciones
      .where((pr) => pr.activo && (widget.paraVenta ? pr.esVenta : pr.esCompra))
      .toList();

  void _alternar(Producto p) {
    setState(() {
      if (_marcados.containsKey(p.id)) {
        _marcados.remove(p.id);
      } else {
        // En una compra el costo de referencia es un punto de partida util;
        // en una venta no, porque es lo que costo, no lo que se cobra.
        final sugerido = !widget.paraVenta && p.costoReferencia != null
            ? _texto2(p.costoReferencia!)
            : '';
        _marcados[p.id] = _Marcado(presentacionId: 0, cantidad: '1', importe: sugerido);
      }
    });
  }

  /// Lo marcado, ya convertido y sin las filas con cantidad invalida.
  List<SeleccionProducto> _resultado() {
    final porId = {for (final p in widget.productos) p.id: p};

    return _marcados.entries
        .map((e) {
          final cantidad = double.tryParse(e.value.cantidad.replaceAll(',', '.')) ?? 0;
          final importe = double.tryParse(e.value.importe.replaceAll(',', '.')) ?? 0;
          final producto = porId[e.key];

          // Sin cantidad no hay linea; sin importe si la hay. El precio se
          // pone despues, al editar la linea: pedirlo aqui, en una fila
          // estrecha y por cada producto marcado, es justo lo que hacia lenta
          // la carga masiva que esta hoja viene a resolver.
          if (producto == null || cantidad <= 0) return null;

          return SeleccionProducto(
            producto: producto,
            presentacionId: e.value.presentacionId,
            cantidad: cantidad,
            importe: importe,
          );
        })
        .whereType<SeleccionProducto>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    final listos = _resultado().length;

    final categorias = widget.productos
        .map((p) => p.categoria)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final marcas = widget.productos.map((p) => p.marca).whereType<String>().toSet().toList()
      ..sort();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio4,
              Dimen.espacio2,
              Dimen.espacio4,
              Dimen.espacio3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Buscar productos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colores.tinta,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colores.tintaSuave),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: Dimen.espacio2),
                Row(
                  children: [
                    Expanded(
                      child: AppBuscador(
                        valor: _texto,
                        pista: 'Nombre, código, marca...',
                        onCambio: (v) => setState(() => _texto = v),
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio2),
                    BotonFiltrosEnLinea(
                      activo: _filtrosAbiertos || _categoria != null || _marca != null,
                      onTap: () => setState(() => _filtrosAbiertos = !_filtrosAbiertos),
                    ),
                  ],
                ),
                if (_filtrosAbiertos) ...[
                  const SizedBox(height: Dimen.espacio3),
                  Wrap(
                    spacing: Dimen.espacio2,
                    runSpacing: Dimen.espacio2,
                    children: [
                      FiltroEnLinea(
                        etiqueta: 'Categoría',
                        valor: _categoria,
                        opciones: categorias,
                        onChanged: (v) => setState(() => _categoria = v),
                      ),
                      FiltroEnLinea(
                        etiqueta: 'Marca',
                        valor: _marca,
                        opciones: marcas,
                        onChanged: (v) => setState(() => _marca = v),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Dimen.espacio3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${visibles.length} producto${visibles.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                    if (_marcados.isNotEmpty)
                      Text(
                        '${_marcados.length} seleccionado${_marcados.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colores.marca,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colores.linea),
          Expanded(
            child: visibles.isEmpty
                ? const AppVacio(
                    icono: Icons.search_off,
                    titulo: 'Ningún producto coincide',
                    detalle: 'Prueba con otro texto o quita los filtros.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Dimen.espacio3),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Dimen.espacio2),
                    itemBuilder: (context, i) {
                      final p = visibles[i];
                      return _FilaProducto(
                        producto: p,
                        marcado: _marcados[p.id],
                        presentaciones: _presentacionesDe(p),
                        stock: widget.stock?[p.id],
                        onAlternar: () => _alternar(p),
                        onPresentacion: (id) =>
                            setState(() => _marcados[p.id]?.presentacionId = id),
                        onCantidad: (v) => setState(() => _marcados[p.id]?.cantidad = v),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: Colores.linea),
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio4),
            child: Row(
              children: [
                Expanded(
                  child: AppBoton(
                    texto: 'Cancelar',
                    variante: BotonVariante.secundario,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  flex: 2,
                  child: AppBoton(
                    texto: listos == 0 ? 'Agregar' : 'Agregar ($listos)',
                    icono: Icons.add,
                    onPressed: listos == 0
                        ? null
                        : () => Navigator.of(context).pop(_resultado()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila del listado: el producto y, si esta marcado, unidad y cantidad.
class _FilaProducto extends StatelessWidget {
  const _FilaProducto({
    required this.producto,
    required this.marcado,
    required this.presentaciones,
    required this.stock,
    required this.onAlternar,
    required this.onPresentacion,
    required this.onCantidad,
  });

  final Producto producto;
  final _Marcado? marcado;
  final List<Presentacion> presentaciones;
  final double? stock;
  final VoidCallback onAlternar;
  final ValueChanged<int> onPresentacion;
  final ValueChanged<String> onCantidad;

  @override
  Widget build(BuildContext context) {
    final activo = marcado != null;

    final detalle = [
      producto.codigo,
      if (producto.marca != null) producto.marca!,
      if (producto.categoria != null) producto.categoria!,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: activo ? Colores.marcaSuave : Colores.superficie,
        border: Border.all(color: activo ? Colores.marca : Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      padding: const EdgeInsets.all(Dimen.espacio3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: activo,
                  onChanged: (_) => onAlternar(),
                  activeColor: Colores.marca,
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: GestureDetector(
                  onTap: onAlternar,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colores.tinta,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                      ),
                    ],
                  ),
                ),
              ),
              if (stock != null) _EtiquetaStock(stock: stock!, unidad: producto.unidadBase),
            ],
          ),
          if (activo) ...[
            const SizedBox(height: Dimen.espacio3),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _CampoUnidad(
                    producto: producto,
                    presentaciones: presentaciones,
                    valor: marcado!.presentacionId,
                    onChanged: onPresentacion,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  flex: 2,
                  child: _CampoNumero(
                    etiqueta: 'Cant.',
                    inicial: marcado!.cantidad,
                    onChanged: onCantidad,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EtiquetaStock extends StatelessWidget {
  const _EtiquetaStock({required this.stock, required this.unidad});

  final double stock;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final hay = stock > 0;
    final texto = stock == stock.roundToDouble() ? stock.toStringAsFixed(0) : stock.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio2, vertical: 3),
      decoration: BoxDecoration(
        color: hay ? Colores.exitoSuave : Colores.peligroSuave,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$texto $unidad',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: hay ? Colores.exito : Colores.peligro,
        ),
      ),
    );
  }
}

class _CampoUnidad extends StatelessWidget {
  const _CampoUnidad({
    required this.producto,
    required this.presentaciones,
    required this.valor,
    required this.onChanged,
  });

  final Producto producto;
  final List<Presentacion> presentaciones;
  final int valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // La unidad base siempre esta: es como se mide el producto por dentro.
    final opciones = <DropdownMenuItem<int>>[
      DropdownMenuItem(value: 0, child: Text(producto.unidadBase)),
      ...presentaciones
          .where((p) => !p.esBase)
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre))),
    ];

    return _CajaCampo(
      etiqueta: 'Unidad',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: valor,
          isExpanded: true,
          items: opciones,
          onChanged: (v) => onChanged(v ?? 0),
          style: const TextStyle(fontSize: 13, color: Colores.tinta),
        ),
      ),
    );
  }
}

class _CampoNumero extends StatefulWidget {
  const _CampoNumero({
    required this.etiqueta,
    required this.inicial,
    required this.onChanged,
  });

  final String etiqueta;
  final String inicial;
  final ValueChanged<String> onChanged;

  @override
  State<_CampoNumero> createState() => _CampoNumeroState();
}

class _CampoNumeroState extends State<_CampoNumero> {
  late final TextEditingController _control = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La MISMA caja que el desplegable de unidad, no un estilo propio parecido:
    // van uno al lado del otro y con dos declaraciones separadas basta que se
    // toque una para que la fila quede descuadrada, que es lo que pasaba.
    return _CajaCampo(
      etiqueta: widget.etiqueta,
      child: Center(
        child: TextField(
          controller: _control,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: widget.onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 13, color: Colores.tinta),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

/// Etiqueta chica encima y una caja de la altura del sistema.
///
/// La comparten la unidad y los numeros de la fila para que queden a la misma
/// altura y con el mismo borde sin tener que repetir el estilo en cada uno.
class _CajaCampo extends StatelessWidget {
  const _CajaCampo({required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: Colores.tintaSuave)),
        const SizedBox(height: 2),
        Container(
          height: Dimen.campoSm,
          padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
          decoration: BoxDecoration(
            color: Colores.superficie,
            border: Border.all(color: Colores.linea),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          child: child,
        ),
      ],
    );
  }
}
