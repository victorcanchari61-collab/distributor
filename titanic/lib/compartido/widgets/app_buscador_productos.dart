import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/maestros/datos/producto.dart';
import '../formato.dart';
import '../presentaciones_uso.dart';
import 'app_boton.dart';
import 'app_buscador.dart';
import 'app_selector.dart';
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

/// Estado de una fila mientras la hoja esta abierta.
class _Marcado {
  _Marcado({
    required this.presentacionId,
    required this.cantidad,
    required this.importe,
  });

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
/// [paraVenta] decide si el importe se llama Precio o Costo y qué se propone
/// (un producto puede venderse por unidad y comprarse solo por saco).
///
/// [uso] decide qué unidades se ofrecen, la base incluida, y qué productos: uno
/// que en ese uso no tiene ninguna presentación disponible no aparece. Sin
/// [uso] (documentos de inventario) la base siempre se ofrece y las demás
/// siguen la marca de [paraVenta], como antes de que la base tuviera marcas.
Future<List<SeleccionProducto>?> mostrarBuscadorProductos({
  required BuildContext context,
  required List<Producto> productos,
  bool paraVenta = true,
  UsoPresentacion? uso,
  Map<int, double>? stock,

  /// Lo que ya apartan pedidos pendientes, por producto — solo informativo.
  Map<int, double>? reservado,
}) {
  // El acento se captura ANTES de abrir: la hoja cuelga del Navigator, no de
  // la pantalla, asi que ahi dentro ya no hay de quien heredarlo y saldria
  // azul aunque se haya abierto desde Compras.
  final acento = Acento.de(context);

  return showModalBottomSheet<List<SeleccionProducto>>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (context) => Acento(
      color: acento,
      child: _HojaBuscadorProductos(
        productos: productos,
        paraVenta: paraVenta,
        uso: uso,
        stock: stock,
        reservado: reservado,
      ),
    ),
  );
}

class _HojaBuscadorProductos extends StatefulWidget {
  const _HojaBuscadorProductos({
    required this.productos,
    required this.paraVenta,
    required this.uso,
    this.stock,
    this.reservado,
  });

  final List<Producto> productos;
  final bool paraVenta;
  final UsoPresentacion? uso;
  final Map<int, double>? stock;
  final Map<int, double>? reservado;

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

  /// Cuantos filtros hay puestos, para la insignia del boton.
  int get _activos => (_categoria != null ? 1 : 0) + (_marca != null ? 1 : 0);

  /// La regla con la que se ofrecen las unidades. Sin `uso` (inventario) la base
  /// va siempre y las demás siguen la marca de paraVenta.
  UsoPresentacion get _uso =>
      widget.uso ??
      (widget.paraVenta ? UsoPresentacion.venta : UsoPresentacion.compra);
  bool get _baseSiempre => widget.uso == null;

  /// Solo los productos que tienen con qué armar la línea en este documento: uno
  /// que no se vende (o no se compra) en ninguna presentación no se ofrece. Se
  /// calcula una vez, la lista de la hoja no cambia mientras está abierta.
  late final List<Producto> _ofrecidos = productosConOpcion(
    widget.productos,
    widget.uso,
    baseSiempre: _baseSiempre,
  );

  List<Producto> get _visibles {
    final texto = _texto.trim().toLowerCase();

    return _ofrecidos.where((p) {
      if (texto.isNotEmpty && !p.buscable.contains(texto)) return false;
      if (_categoria != null && p.categoria != _categoria) return false;
      if (_marca != null && p.marca != _marca) return false;
      return true;
    }).toList();
  }

  /// Las unidades que se pueden elegir para el producto, con la base primero si
  /// se puede usar.
  List<OpcionPresentacion> _opcionesDe(Producto p) => opcionesPresentacion(
    unidadBase: p.unidadBase,
    presentaciones: p.presentaciones,
    uso: _uso,
    baseSiempre: _baseSiempre,
  );

  void _alternar(Producto p) {
    setState(() {
      if (_marcados.containsKey(p.id)) {
        _marcados.remove(p.id);
      } else {
        // En una compra el costo de referencia es un punto de partida util;
        // en una venta no, porque es lo que costo, no lo que se cobra.
        // Al centimo: el costo se guarda por unidad base con ocho decimales
        // y proponer "6.3377193" en una caja de importe es ilegible.
        final sugerido = !widget.paraVenta && p.costoReferencia != null
            ? formatoCosto(p.costoReferencia!)
            : '';
        _marcados[p.id] = _Marcado(
          // La base si se puede usar; si no, la primera presentacion que si.
          // Marcar siempre con 0 dejaba una linea por unidades sueltas de algo
          // que solo se vende por caja.
          presentacionId:
              presentacionInicial(p, _uso, baseSiempre: _baseSiempre) ?? 0,
          cantidad: '1',
          importe: sugerido,
        );
      }
    });
  }

  /// Lo marcado, ya convertido y sin las filas con cantidad invalida.
  List<SeleccionProducto> _resultado() {
    final porId = {for (final p in widget.productos) p.id: p};

    return _marcados.entries
        .map((e) {
          final cantidad =
              double.tryParse(e.value.cantidad.replaceAll(',', '.')) ?? 0;
          final importe =
              double.tryParse(e.value.importe.replaceAll(',', '.')) ?? 0;
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

    final categorias =
        _ofrecidos.map((p) => p.categoria).whereType<String>().toSet().toList()
          ..sort();
    final marcas =
        _ofrecidos.map((p) => p.marca).whereType<String>().toSet().toList()
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        BotonFiltrosEnLinea(
                          activo: _filtrosAbiertos || _activos > 0,
                          onTap: () => setState(
                            () => _filtrosAbiertos = !_filtrosAbiertos,
                          ),
                        ),
                        // Cuantos filtros hay puestos, para no tener que abrir
                        // el panel solo para comprobarlo.
                        if (_activos > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Acento.de(context),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_activos',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_filtrosAbiertos) ...[
                  const SizedBox(height: Dimen.espacio3),
                  Container(
                    padding: const EdgeInsets.all(Dimen.espacio3),
                    decoration: BoxDecoration(
                      color: Colores.fondo,
                      border: Border.all(color: Colores.linea),
                      borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppSelector<String>(
                                etiqueta: 'Categoría',
                                valor: _categoria ?? '',
                                opciones: [
                                  const Opcion('', 'Todas'),
                                  for (final c in categorias) Opcion(c, c),
                                ],
                                onCambio: (v) => setState(
                                  () =>
                                      _categoria = (v ?? '').isEmpty ? null : v,
                                ),
                              ),
                            ),
                            const SizedBox(width: Dimen.espacio3),
                            Expanded(
                              child: AppSelector<String>(
                                etiqueta: 'Marca',
                                valor: _marca ?? '',
                                opciones: [
                                  const Opcion('', 'Todas'),
                                  for (final m in marcas) Opcion(m, m),
                                ],
                                onCambio: (v) => setState(
                                  () => _marca = (v ?? '').isEmpty ? null : v,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_activos > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _categoria = null;
                                _marca = null;
                              }),
                              icon: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 16,
                              ),
                              label: const Text('Limpiar filtros'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Dimen.espacio3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${visibles.length} producto${visibles.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colores.tintaSuave,
                      ),
                    ),
                    if (_marcados.isNotEmpty)
                      Text(
                        '${_marcados.length} seleccionado${_marcados.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Acento.de(context),
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
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Dimen.espacio2),
                    itemBuilder: (context, i) {
                      final p = visibles[i];
                      return _FilaProducto(
                        producto: p,
                        marcado: _marcados[p.id],
                        // Las unidades solo se necesitan en la fila marcada,
                        // que es la que muestra el desplegable.
                        opciones: _marcados.containsKey(p.id)
                            ? _opcionesDe(p)
                            : const [],
                        stock: widget.stock?[p.id],
                        reservado: widget.reservado?[p.id] ?? 0,
                        onAlternar: () => _alternar(p),
                        onPresentacion: (id) => setState(
                          () => _marcados[p.id]?.presentacionId = id,
                        ),
                        onCantidad: (v) =>
                            setState(() => _marcados[p.id]?.cantidad = v),
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
    required this.opciones,
    required this.stock,
    required this.reservado,
    required this.onAlternar,
    required this.onPresentacion,
    required this.onCantidad,
  });

  final Producto producto;
  final _Marcado? marcado;
  final List<OpcionPresentacion> opciones;
  final double? stock;
  final double reservado;
  final VoidCallback onAlternar;
  final ValueChanged<int> onPresentacion;
  final ValueChanged<String> onCantidad;

  /// A cuántas unidades base equivale la presentación marcada — el stock se
  /// guarda en base y se muestra en la unidad que se está eligiendo.
  double get _factor {
    final id = marcado?.presentacionId;
    if (id == null || id == 0) return 1;
    for (final p in producto.presentaciones) {
      if (p.id == id) return p.factor;
    }
    return 1;
  }

  /// El nombre de la unidad en la que se muestra el stock: la marcada, o la
  /// base cuando todavía no se eligió ninguna.
  String get _unidad {
    final id = marcado?.presentacionId;
    if (id == null || id == 0) return producto.unidadBase;
    for (final p in producto.presentaciones) {
      if (p.id == id) return p.nombre;
    }
    return producto.unidadBase;
  }

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
        color: activo ? Acento.suave(context) : Colores.superficie,
        border: Border.all(color: activo ? Acento.de(context) : Colores.linea),
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
                  activeColor: Acento.de(context),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (stock != null)
                _EtiquetaStock(
                  disponible: stock! / _factor,
                  reservado: reservado / _factor,
                  unidad: _unidad,
                ),
            ],
          ),
          if (activo) ...[
            const SizedBox(height: Dimen.espacio3),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _CampoUnidad(
                    opciones: opciones,
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
  const _EtiquetaStock({
    required this.disponible,
    required this.reservado,
    required this.unidad,
  });

  final double disponible;
  final double reservado;
  final String unidad;

  static String _texto(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final hay = disponible > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimen.espacio2,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: hay ? Colores.exitoSuave : Colores.peligroSuave,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_texto(disponible)} $unidad',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hay ? Colores.exito : Colores.peligro,
            ),
          ),
        ),
        if (reservado > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${_texto(reservado)} reservados',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colores.advertencia,
              ),
            ),
          ),
      ],
    );
  }
}

class _CampoUnidad extends StatelessWidget {
  const _CampoUnidad({
    required this.opciones,
    required this.valor,
    required this.onChanged,
  });

  final List<OpcionPresentacion> opciones;
  final int valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // La unidad base ya viene en la lista si se puede usar: hay productos que
    // solo salen por caja y no por unidad suelta.
    final items = <DropdownMenuItem<int>>[
      for (final o in opciones)
        DropdownMenuItem(value: o.valor, child: Text(o.nombre)),
    ];

    return _CajaCampo(
      etiqueta: 'Unidad',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: valor,
          isExpanded: true,
          isDense: true,
          items: items,
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
  late final TextEditingController _control = TextEditingController(
    text: widget.inicial,
  );

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
      child: SizedBox(
        // La altura de una fila de texto, igual que la del desplegable: sin
        // esto el campo trae el alto suelto de un TextField y desnivela.
        height: 24,
        child: TextField(
          controller: _control,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: widget.onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            color: Colores.tinta,
          ),
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
    // La etiqueta va recortando el borde, no encima: asi el campo ocupa una
    // sola altura y la fila marcada no crece de mas dentro de la lista.
    /*
      La altura la fija el contenido, no una caja recortada.
      
      Antes era un SizedBox de alto fijo: el desplegable y el numero no miden
      lo mismo por dentro, asi que cada uno se acomodaba a su manera dentro
      del mismo alto y la fila salia desparejo —uno mas abajo que el otro y
      con el borde a distinta altura—. Con un minimo comun y el mismo padding
      arriba y abajo, los dos se dibujan iguales por construccion.
    */
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: etiqueta,
        isDense: true,
        filled: true,
        fillColor: Colores.superficie,
        constraints: const BoxConstraints(minHeight: Dimen.campoMd + 6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Dimen.espacio3,
          vertical: Dimen.espacio2,
        ),
        labelStyle: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          borderSide: const BorderSide(color: Colores.linea),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          borderSide: const BorderSide(color: Colores.linea),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          borderSide: BorderSide(color: Acento.de(context)),
        ),
      ),
      child: child,
    );
  }
}
