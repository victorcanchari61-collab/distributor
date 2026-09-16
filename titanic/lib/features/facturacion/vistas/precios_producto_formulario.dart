import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo_busqueda.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/lista_precio.dart';
import '../estado/facturacion_controlador.dart';

/*
 * Una fila del editor.
 *
 * `desde` es la cantidad mínima a partir de la cual rige ese precio: es la
 * regla que hace que una lista Mayorista tenga sentido —el saco de camanejo a
 * un precio, y desde 5 sacos a otro más bajo—.
 */
class _Fila {
  _Fila({
    this.id,
    required this.presentacion,
    String desde = '1',
    String precio = '',
    String margen = '',
  }) : desde = TextEditingController(text: desde),
       precio = TextEditingController(text: precio),
       margen = TextEditingController(text: margen);

  /// Id del precio guardado del que salió; null si la fila es nueva.
  final int? id;
  final Presentacion presentacion;
  final TextEditingController desde;
  final TextEditingController precio;
  final TextEditingController margen;

  /// Identidad para Flutter: las filas se agregan y quitan en medio.
  final clave = UniqueKey();

  double get precioNum =>
      double.tryParse(precio.text.trim().replaceAll(',', '.')) ?? 0;
  double get desdeNum =>
      double.tryParse(desde.text.trim().replaceAll(',', '.')) ?? 0;

  void liberar() {
    desde.dispose();
    precio.dispose();
    margen.dispose();
  }
}

/// Precios de TODAS las presentaciones de un producto, de una sentada.
///
/// Un producto de abarrotes se vende en siete formas —el kilo, cinco bolsas y
/// el saco— y cargarlas de a una era abrir el formulario siete veces. Es el
/// mismo editor de la web: la misma persona tiene que encontrar lo mismo en el
/// teléfono que en la computadora.
class PreciosProductoFormulario extends ConsumerStatefulWidget {
  const PreciosProductoFormulario({
    super.key,
    required this.lista,
    required this.precios,
    this.productoId,
  });

  final ListaPrecio lista;

  /// Los precios que ya tiene la lista: de ahí salen los tramos guardados.
  final List<Precio> precios;

  /// El producto con el que se abre. Null para elegirlo.
  final int? productoId;

  @override
  ConsumerState<PreciosProductoFormulario> createState() =>
      _PreciosProductoFormularioState();
}

class _PreciosProductoFormularioState
    extends ConsumerState<PreciosProductoFormulario> {
  Producto? _producto;
  final List<_Fila> _filas = [];
  final _margenObjetivo = TextEditingController();

  bool _guardando = false;
  String? _error;
  bool _sembrado = false;

  @override
  void dispose() {
    for (final f in _filas) {
      f.liberar();
    }
    _margenObjetivo.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- calculos

  /// Costo de una presentación: el de la unidad base por su factor.
  double? _costoDe(Presentacion p) {
    final base = _producto?.costoReferencia;
    return base == null ? null : base * p.factor;
  }

  /*
   * Precio que deja el margen pedido, redondeado al céntimo de ARRIBA.
   *
   * El kilo de camanejo cuesta 3.40 y al 25% daría 4.5333, que no se puede
   * cobrar. Al redondear al más cercano quedaba 4.53, o sea 24.9%: un pelo
   * MENOS de lo pedido. Subiendo el céntimo el margen nunca queda por debajo
   * del que se escribió. La misma regla que la web.
   */
  static String _precioPorMargen(double costo, double margen) =>
      ((costo / (1 - margen / 100) * 100).ceil() / 100).toStringAsFixed(2);

  static String _margenDe(double costo, double precio) =>
      precio > 0 ? ((precio - costo) / precio * 100).toStringAsFixed(1) : '';

  // ------------------------------------------------------------- filas

  /// Abre el producto con lo que ya tiene cargado, tramos incluidos.
  void _elegirProducto(Producto producto) {
    for (final f in _filas) {
      f.liberar();
    }
    _filas.clear();

    final vendibles = producto.presentaciones.where(
      (p) => p.esVenta && p.activo,
    );

    for (final pres in vendibles) {
      final suyos =
          widget.precios.where((x) => x.presentacionId == pres.id).toList()
            ..sort((a, b) => a.cantidadMinima.compareTo(b.cantidadMinima));

      // El de "desde 1" siempre está aunque todavía no tenga precio: es el
      // renglón normal de esa forma de vender.
      if (!suyos.any((x) => x.cantidadMinima == 1)) {
        _filas.add(_Fila(presentacion: pres));
      }

      final costoBase = producto.costoReferencia;
      for (final x in suyos) {
        // El margen de lo guardado no viene del backend: se saca del costo,
        // igual que al teclear. Sin esto la columna salía vacía al editar.
        final costo = costoBase == null ? null : costoBase * pres.factor;
        _filas.add(
          _Fila(
            id: x.id,
            presentacion: pres,
            desde: formatoNumero(x.cantidadMinima),
            precio: x.precio.toStringAsFixed(2),
            margen: costo == null ? '' : _margenDe(costo, x.precio),
          ),
        );
      }
    }

    setState(() {
      _producto = producto;
      _margenObjetivo.clear();
      _error = null;
    });
  }

  /// Escriben el precio: el margen de esa fila se recalcula solo.
  void _escribirPrecio(_Fila fila) {
    final costo = _costoDe(fila.presentacion);
    fila.margen.text = costo == null ? '' : _margenDe(costo, fila.precioNum);
    setState(() {});
  }

  /// Escriben el margen: el precio de esa fila se recalcula solo.
  void _escribirMargen(_Fila fila) {
    final costo = _costoDe(fila.presentacion);
    if (costo == null) return;

    final texto = fila.margen.text.trim().replaceAll(',', '.');

    // Borrar el margen es dejarlo en cero: el precio baja al costo. Si no, se
    // quedaba el precio del margen anterior y las dos columnas se contradecían.
    if (texto.isEmpty) {
      fila.precio.text = costo.toStringAsFixed(2);
    } else {
      final margen = double.tryParse(texto);
      if (margen != null && margen < 100) {
        fila.precio.text = _precioPorMargen(costo, margen);
      }
    }
    setState(() {});
  }

  /*
   * Otro tramo de la misma presentación.
   *
   * Es la escalera por volumen: el saco suelto a un precio y desde 5 sacos a
   * otro más bajo. Va pegado a los de su presentación, no al final.
   */
  void _agregarTramo(_Fila fila) {
    final hermanas = _filas.where((f) => f.presentacion.id == fila.presentacion.id);
    final ultimo = hermanas.map((f) => f.desdeNum).fold<double>(1, math.max);
    final posicion =
        _filas.lastIndexWhere((f) => f.presentacion.id == fila.presentacion.id);

    setState(() {
      _filas.insert(
        posicion + 1,
        _Fila(presentacion: fila.presentacion, desde: formatoNumero(ultimo + 1)),
      );
    });
  }

  void _quitarTramo(_Fila fila) {
    setState(() => _filas.remove(fila));
    fila.liberar();
  }

  /// Llena la columna de precios a partir del costo: precio = costo / (1 - margen).
  void _llenarPorMargen() {
    final margen = double.tryParse(
      _margenObjetivo.text.trim().replaceAll(',', '.'),
    );
    if (margen == null || margen <= 0 || margen >= 100) {
      setState(() => _error = 'El margen va entre 1 y 99.');
      return;
    }

    setState(() {
      _error = null;
      for (final f in _filas) {
        final costo = _costoDe(f.presentacion);
        // Los tramos por volumen quedan como están: son un descuento puesto a
        // mano, y llenarlos con el mismo margen los dejaría al precio normal.
        if (costo == null || f.desdeNum > 1) continue;
        f.precio.text = _precioPorMargen(costo, margen);
        f.margen.text = margen.toStringAsFixed(1);
      }
    });
  }

  // ------------------------------------------------------------- guardar

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final producto = _producto;
    if (producto == null) {
      setState(() => _error = 'Elige el producto.');
      return;
    }

    final conPrecio = _filas.where((f) => f.precioNum > 0).toList();

    if (conPrecio.any((f) => f.desdeNum < 1)) {
      setState(() => _error = 'El "desde" de cada precio empieza en 1.');
      return;
    }

    // Dos tramos con el mismo "desde" dejarían a la venta sin saber cuál
    // cobrar, y el backend se quedaría con el último sin avisar.
    final claves = conPrecio
        .map((f) => '${f.presentacion.id}-${f.desdeNum}')
        .toList();
    if (claves.toSet().length != claves.length) {
      setState(
        () => _error =
            'Hay dos precios de la misma presentación con el mismo "desde".',
      );
      return;
    }

    if (conPrecio.isEmpty) {
      setState(() => _error = 'Pon al menos un precio.');
      return;
    }

    /*
     * Los tramos que se quitaron.
     *
     * El PUT solo crea y actualiza: quitar la fila en pantalla no bastaba, el
     * precio viejo seguía en la lista y se seguía cobrando. Vale igual para
     * la fila que se deja sin precio: si tenía uno guardado, se borra.
     */
    final vivos = conPrecio.map((f) => f.id).whereType<int>().toSet();
    final aBorrar = widget.precios.where(
      (x) => x.productoId == producto.id && !vivos.contains(x.id),
    );

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);
    final api = ref.read(facturacionApiProvider);

    try {
      await api.guardarPrecios(widget.lista.id, [
        for (final f in conPrecio)
          {
            'presentacionId': f.presentacion.id,
            'precio': f.precioNum,
            'cantidadMinima': f.desdeNum,
          },
      ]);
      for (final x in aBorrar) {
        await api.eliminarPrecio(x.id);
      }

      ref.invalidate(preciosListaActivaProvider);
      await ref.read(listasPrecioProvider.notifier).recargar();
      navegador.pop();
      mensajero.mostrar(
        conPrecio.length == 1
            ? 'Precio guardado'
            : '${conPrecio.length} precios guardados',
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  // ------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    final productos = (ref.watch(productosProvider).valueOrNull ?? const <Producto>[])
        .where((p) => p.activo)
        .toList();

    // Si se abre desde un precio, el producto ya viene elegido.
    if (!_sembrado && widget.productoId != null) {
      for (final p in productos) {
        if (p.id == widget.productoId) {
          _sembrado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _elegirProducto(p);
          });
        }
      }
    }

    final producto = _producto;
    final conCosto = producto?.costoReferencia != null;

    return Acento.modulo(
      'fact',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Precios del producto',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            Text(
              'Lista ${widget.lista.nombre}',
              style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio3),

            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],

            AppCampoBusqueda<Producto>(
              etiqueta: 'Producto',
              icono: Icons.inventory_2_outlined,
              pista: 'Escribe el nombre o el código',
              items: productos,
              cargando: ref.watch(productosProvider).isLoading,
              habilitado: !_guardando,
              textoElegido: producto?.nombre,
              titulo: (p) => p.nombre,
              subtitulo: (p) => p.codigo,
              buscable: (p) => p.buscable,
              onElegir: _elegirProducto,
            ),

            // Llenar todas de golpe desde el costo: con siete formas de vender,
            // teclear cada precio a mano es donde se cuelan los errores.
            if (conCosto) ...[
              const SizedBox(height: Dimen.espacio3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _margenObjetivo,
                      enabled: !_guardando,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Margen para todas',
                        hintText: '25',
                        suffixText: '%',
                        constraints: BoxConstraints(minHeight: Dimen.campoLg),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimen.espacio3),
                  AppBoton(
                    texto: 'Llenar',
                    variante: BotonVariante.secundario,
                    onPressed: _guardando ? null : _llenarPorMargen,
                  ),
                ],
              ),
              const SizedBox(height: Dimen.espacio1),
              Text(
                'Costo del ${producto!.unidadBase}: '
                '${formatoSoles(producto.costoReferencia!)}. Los tramos por '
                'volumen no se tocan.',
                style: const TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
              ),
            ],

            const SizedBox(height: Dimen.espacio4),

            if (producto == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio6),
                child: Text(
                  'Elige un producto para ver sus presentaciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                ),
              )
            else if (_filas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio6),
                child: Text(
                  'Este producto no tiene ninguna presentación marcada como se '
                  'vende.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                ),
              )
            else
              for (final fila in _filas) ...[
                _TarjetaFila(
                  key: fila.clave,
                  fila: fila,
                  unidadBase: producto.unidadBase,
                  costo: _costoDe(fila.presentacion),
                  habilitado: !_guardando,
                  // El renglón de "desde 1" es el precio normal: no se quita.
                  puedeQuitar:
                      _filas
                          .where((f) => f.presentacion.id == fila.presentacion.id)
                          .length >
                      1,
                  onPrecio: () => _escribirPrecio(fila),
                  onMargen: () => _escribirMargen(fila),
                  onDesde: () => setState(() {}),
                  onTramo: () => _agregarTramo(fila),
                  onQuitar: () => _quitarTramo(fila),
                ),
                const SizedBox(height: Dimen.espacio3),
              ],

            const SizedBox(height: Dimen.espacio3),
            AppBoton(
              texto: 'Guardar precios',
              cargando: _guardando,
              onPressed: _guardar,
            ),
            const SizedBox(height: Dimen.espacio3),
            AppBoton(
              texto: 'Cancelar',
              variante: BotonVariante.secundario,
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}

/// Una presentación con su precio, en tarjeta: la tabla de la web no cabe en
/// el ancho de un teléfono, pero cada dato conserva su nombre.
class _TarjetaFila extends StatelessWidget {
  const _TarjetaFila({
    super.key,
    required this.fila,
    required this.unidadBase,
    required this.costo,
    required this.habilitado,
    required this.puedeQuitar,
    required this.onPrecio,
    required this.onMargen,
    required this.onDesde,
    required this.onTramo,
    required this.onQuitar,
  });

  final _Fila fila;
  final String unidadBase;
  final double? costo;
  final bool habilitado;
  final bool puedeQuitar;
  final VoidCallback onPrecio;
  final VoidCallback onMargen;
  final VoidCallback onDesde;
  final VoidCallback onTramo;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final factor = fila.presentacion.factor;
    final precio = fila.precioNum;
    final esTramo = fila.desdeNum > 1;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fila.presentacion.nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: Dimen.espacio2,
                      children: [
                        _Chip(texto: 'Equivale ${formatoNumero(factor)} $unidadBase'),
                        if (esTramo)
                          _Chip(
                            texto: 'Desde ${formatoNumero(fila.desdeNum)}',
                            aviso: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: habilitado ? onTramo : null,
                tooltip: 'Agregar un tramo por volumen',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Acento.de(context),
                ),
              ),
              if (puedeQuitar)
                IconButton(
                  onPressed: habilitado ? onQuitar : null,
                  tooltip: 'Quitar este tramo',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colores.peligro,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Dimen.espacio3),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _Numero(
                  controlador: fila.desde,
                  etiqueta: 'Desde',
                  habilitado: habilitado,
                  decimales: false,
                  onCambio: onDesde,
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                flex: 3,
                child: _Numero(
                  controlador: fila.precio,
                  etiqueta: 'Precio S/',
                  habilitado: habilitado,
                  onCambio: onPrecio,
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                flex: 2,
                child: _Numero(
                  controlador: fila.margen,
                  etiqueta: 'Margen %',
                  // Sin costo no hay de dónde sacar un margen.
                  habilitado: habilitado && costo != null,
                  onCambio: onMargen,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),

          Row(
            children: [
              Expanded(
                child: _Dato(
                  etiqueta: 'Costo',
                  valor: costo == null ? '—' : formatoSoles(costo!),
                ),
              ),
              // La que hace visible el negocio: el saco sale más barato por
              // kilo que el kilo suelto.
              Expanded(
                child: _Dato(
                  etiqueta: 'Por $unidadBase',
                  valor: precio > 0 && factor > 0
                      ? formatoSoles(precio / factor)
                      : '—',
                  alineado: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, this.aviso = false});

  final String texto;
  final bool aviso;

  @override
  Widget build(BuildContext context) {
    final color = aviso ? Colores.advertencia : Acento.de(context);
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    this.alineado = TextAlign.left,
  });

  final String etiqueta;
  final String valor;
  final TextAlign alineado;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$etiqueta  ',
        style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
        children: [
          TextSpan(
            text: valor,
            // En negro, no gris: es un dato que se lee, no una ayuda.
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
        ],
      ),
      textAlign: alineado,
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.controlador,
    required this.etiqueta,
    required this.habilitado,
    required this.onCambio,
    this.decimales = true,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final bool habilitado;
  final VoidCallback onCambio;
  final bool decimales;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      enabled: habilitado,
      keyboardType: TextInputType.numberWithOptions(decimal: decimales),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimales ? r'[0-9.,]' : r'[0-9]'),
        ),
      ],
      onChanged: (_) => onCambio(),
      style: const TextStyle(fontSize: 14, color: Colores.tinta),
      decoration: InputDecoration(
        labelText: etiqueta,
        isDense: true,
        constraints: const BoxConstraints(minHeight: Dimen.campoLg),
      ),
    );
  }
}
