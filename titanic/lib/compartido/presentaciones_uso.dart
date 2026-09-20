import '../features/maestros/datos/producto.dart';

/*
 * Qué presentaciones de un producto se pueden elegir según para qué se usa.
 *
 * Cada presentación dice si "se compra" y si "se vende", y la unidad base
 * también: hay productos que solo salen por caja y no por unidad suelta (la
 * base trae las dos marcas apagadas y solo la "Caja 12UND" se compra y se
 * vende). Antes los selectores ofrecían SIEMPRE la unidad base, así que se
 * podía armar un pedido por unidades sueltas de algo que no se vende así.
 *
 * Es la misma regla que la web (Frontend/src/lib/presentaciones.ts). Vive en un
 * solo lugar para que el panel, la hoja de selección múltiple y las tarjetas de
 * línea no acaben cada uno con su propia versión.
 *
 * La unidad base se representa con el valor 0 en los selectores (la línea del
 * documento no lleva presentación propia para ella); las demás, con su id.
 */

/// Para qué se arma la línea. Pedidos y notas de venta miran "se vende";
/// órdenes de compra y compras, "se compra".
enum UsoPresentacion { venta, compra }

/// Una opción de un selector de unidad.
class OpcionPresentacion {
  const OpcionPresentacion({
    required this.valor,
    required this.nombre,
    this.factor = 1,
    this.nota,
  });

  /// 0 = la unidad base; cualquier otro valor es el id de una presentación.
  final int valor;

  /// El código de la unidad base (KG, UND) o el nombre de la presentación.
  final String nombre;

  /// Cuántas unidades base equivale: 1 para la base. El selector lo usa para
  /// decir cuánto hay disponible contado en esa unidad.
  final double factor;

  /// Solo viene cuando la opción YA NO está permitida y se muestra únicamente
  /// porque la línea guardada la tiene ("ya no se vende así").
  final String? nota;
}

/// Si esa presentación sirve para ese uso. Sin uso valen todas las activas.
bool _habilitada(Presentacion p, UsoPresentacion? uso) {
  if (!p.activo) return false;

  return switch (uso) {
    UsoPresentacion.venta => p.esVenta,
    UsoPresentacion.compra => p.esCompra,
    null => true,
  };
}

/// Si la unidad base se puede elegir.
///
/// Es la presentación de factor 1 (`esBase`); si el producto trae varias, basta
/// con que una sirva. Si no trae ninguna en su lista no hay nada que la apague
/// y se ofrece, como siempre: los datos viejos y los productos sin
/// presentaciones cargadas siguen pudiéndose usar.
bool baseHabilitada(List<Presentacion> presentaciones, UsoPresentacion? uso) {
  final bases = presentaciones.where((p) => p.esBase);
  return bases.isEmpty || bases.any((p) => _habilitada(p, uso));
}

/// Las opciones de un selector de unidad, con la base primero si corresponde.
///
/// Recibe la unidad base y la lista de presentaciones por separado, y no un
/// [Producto], porque las líneas ya agregadas a un documento solo guardan esas
/// dos cosas.
///
/// [actual] es lo que ya tiene una línea guardada. Si el producto dejó de
/// venderse (o comprarse) así después, se sigue mostrando —marcada— en vez de
/// dejar el selector en blanco: quien edita ve qué pasó y la cambia.
///
/// [baseSiempre] ofrece la unidad base sin mirar sus marcas. Es lo de los
/// documentos de inventario (ajustes, transferencias, préstamos): contar o
/// ajustar unidades sueltas de algo que solo se vende por caja es legítimo, no
/// se está vendiendo, se está contando lo que hay.
List<OpcionPresentacion> opcionesPresentacion({
  required String unidadBase,
  required List<Presentacion> presentaciones,
  UsoPresentacion? uso,
  bool baseSiempre = false,
  int? actual,
}) {
  final opciones = <OpcionPresentacion>[];

  if (baseSiempre || baseHabilitada(presentaciones, uso)) {
    opciones.add(OpcionPresentacion(valor: 0, nombre: unidadBase));
  }

  for (final p in presentaciones) {
    if (p.esBase || !_habilitada(p, uso)) continue;
    opciones.add(
      OpcionPresentacion(valor: p.id, nombre: p.nombre, factor: p.factor),
    );
  }

  if (actual != null && !opciones.any((o) => o.valor == actual)) {
    Presentacion? guardada;
    for (final p in presentaciones) {
      if (p.id == actual) guardada = p;
    }

    opciones.add(
      OpcionPresentacion(
        valor: actual,
        nombre: guardada?.nombre ?? unidadBase,
        factor: guardada?.factor ?? 1,
        nota: switch (uso) {
          UsoPresentacion.venta => 'ya no se vende así',
          UsoPresentacion.compra => 'ya no se compra así',
          null => 'no disponible',
        },
      ),
    );
  }

  return opciones;
}

/// La unidad con la que arranca una línea NUEVA: la base si se puede usar y, si
/// no, la primera presentación que sí. Null cuando el producto no tiene ninguna
/// opción para ese uso.
int? presentacionInicial(
  Producto producto,
  UsoPresentacion? uso, {
  bool baseSiempre = false,
}) => opcionesPresentacion(
  unidadBase: producto.unidadBase,
  presentaciones: producto.presentaciones,
  uso: uso,
  baseSiempre: baseSiempre,
).firstOrNull?.valor;

/// Los productos que en ese uso tienen con qué armar una línea.
///
/// Un producto que no se vende (o no se compra) en ninguna presentación no se
/// ofrece en el buscador: no habría unidad que ponerle a la línea.
List<Producto> productosConOpcion(
  List<Producto> productos,
  UsoPresentacion? uso, {
  bool baseSiempre = false,
}) {
  // Sin uso, o con la base siempre disponible, todos tienen al menos una unidad.
  if (uso == null || baseSiempre) return productos;

  // Lo mismo que `presentacionInicial(p, uso) != null`, sin armar la lista de
  // opciones: esto corre sobre todo el catálogo cada vez que se redibuja el panel.
  return productos
      .where(
        (p) =>
            baseHabilitada(p.presentaciones, uso) ||
            p.presentaciones.any((pr) => !pr.esBase && _habilitada(pr, uso)),
      )
      .toList();
}
