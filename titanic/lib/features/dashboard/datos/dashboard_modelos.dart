/// Modelos de los cinco dashboards.
///
/// Espejo de `Backend/Dtos/Responses/DashboardResponses.cs` (JSON en camelCase).
/// Todo se lee con tolerancia: un campo que no llega es un cero o una lista
/// vacía, no una excepción — el tablero tiene que poder pintarse aunque la base
/// no tenga un solo dato, que es justo cuando más listas vacías hay.

/// Un día de calle: "2026-09-05T00:00:00Z" es el 5 de septiembre.
///
/// El backend serializa sus `Date` con esa "Z", pero no son instantes sino
/// días: pasarlos por la zona horaria (`fechaDeJson` lo haría) corre el 5 de
/// septiembre al 4 a las 7 p. m. de Lima. Se toman los diez primeros caracteres
/// tal cual.
DateTime diaDeJson(Object? valor) {
  if (valor is String && valor.length >= 10) {
    final dia = DateTime.tryParse(valor.substring(0, 10));
    if (dia != null) return dia;
  }
  return DateTime(1970);
}

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _numOpc(Object? v) => (v as num?)?.toDouble();
int _entero(Object? v) => (v as num?)?.toInt() ?? 0;

List<T> _lista<T>(Object? v, T Function(Map<String, dynamic>) desdeJson) =>
    ((v as List?) ?? const [])
        .map((e) => desdeJson(e as Map<String, dynamic>))
        .toList();

List<double> _numeros(Object? v) =>
    ((v as List?) ?? const []).map(_num).toList();

/// Un valor con nombre: una barra, una porción de dona.
class DashItem {
  const DashItem({required this.nombre, required this.valor, this.cantidad = 0});

  final String nombre;
  final double valor;

  /// Cuántos documentos o unidades hay detrás del valor, cuando importa.
  final int cantidad;

  factory DashItem.desdeJson(Map<String, dynamic> j) => DashItem(
    nombre: j['nombre'] as String? ?? '',
    valor: _num(j['valor']),
    cantidad: _entero(j['cantidad']),
  );
}

// ------------------------------------------------------------------ Ventas

class DashTotalesVentas {
  const DashTotalesVentas({
    this.importe = 0,
    this.notas = 0,
    this.clientes = 0,
    this.ticket = 0,
  });

  final double importe;
  final int notas;
  final int clientes;

  /// Lo que deja una venta en promedio.
  final double ticket;

  factory DashTotalesVentas.desdeJson(Map<String, dynamic>? j) =>
      DashTotalesVentas(
        importe: _num(j?['importe']),
        notas: _entero(j?['notas']),
        clientes: _entero(j?['clientes']),
        ticket: _num(j?['ticket']),
      );
}

class DashDiaVenta {
  const DashDiaVenta({
    required this.fecha,
    this.importe = 0,
    this.notas = 0,
    this.importeAnterior = 0,
  });

  final DateTime fecha;
  final double importe;
  final int notas;

  /// Lo vendido el mismo día del período anterior, para superponerlo.
  final double importeAnterior;

  factory DashDiaVenta.desdeJson(Map<String, dynamic> j) => DashDiaVenta(
    fecha: diaDeJson(j['fecha']),
    importe: _num(j['importe']),
    notas: _entero(j['notas']),
    importeAnterior: _num(j['importeAnterior']),
  );
}

/// Un día que se sale de lo normal de ese período.
class DashAtipico {
  const DashAtipico({required this.indice, required this.tipo});

  /// Posición dentro de la serie.
  final int indice;

  /// PICO o CAIDA.
  final String tipo;

  bool get esPico => tipo == 'PICO';

  factory DashAtipico.desdeJson(Map<String, dynamic> j) => DashAtipico(
    indice: _entero(j['indice']),
    tipo: j['tipo'] as String? ?? 'PICO',
  );
}

/// Cómo va el mes en curso frente al pasado, y a dónde llega si sigue así.
class DashMes {
  const DashMes({
    this.nombre = '',
    this.diaActual = 0,
    this.diasMes = 0,
    this.acumulado = 0,
    this.proyectado = 0,
    this.mesAnterior = 0,
    this.mesAnteriorMismoPunto = 0,
    this.serieActual = const [],
    this.serieAnterior = const [],
    this.serieProyeccion = const [],
  });

  final String nombre;
  final int diaActual;
  final int diasMes;
  final double acumulado;
  final double proyectado;
  final double mesAnterior;

  /// Lo que llevaba el mes pasado a este mismo día.
  final double mesAnteriorMismoPunto;

  /// Lo acumulado día a día del mes en curso y del pasado.
  final List<double> serieActual;
  final List<double> serieAnterior;

  /// Lo que se espera acumular, un valor por día del mes. Null hasta hoy;
  /// desde hoy arranca en lo acumulado para que la línea se una a la real.
  final List<double?> serieProyeccion;

  factory DashMes.desdeJson(Map<String, dynamic>? j) => DashMes(
    nombre: j?['nombre'] as String? ?? '',
    diaActual: _entero(j?['diaActual']),
    diasMes: _entero(j?['diasMes']),
    acumulado: _num(j?['acumulado']),
    proyectado: _num(j?['proyectado']),
    mesAnterior: _num(j?['mesAnterior']),
    mesAnteriorMismoPunto: _num(j?['mesAnteriorMismoPunto']),
    serieActual: _numeros(j?['serieActual']),
    serieAnterior: _numeros(j?['serieAnterior']),
    serieProyeccion: ((j?['serieProyeccion'] as List?) ?? const [])
        .map(_numOpc)
        .toList(),
  );
}

/// Un cliente dentro de la curva de Pareto.
class DashPareto {
  const DashPareto({
    required this.nombre,
    required this.valor,
    required this.acumulado,
  });

  final String nombre;
  final double valor;

  /// Qué parte del total llevan él y todos los de arriba, en %.
  final double acumulado;

  factory DashPareto.desdeJson(Map<String, dynamic> j) => DashPareto(
    nombre: j['nombre'] as String? ?? '',
    valor: _num(j['valor']),
    acumulado: _num(j['acumulado']),
  );
}

/// Un casillero del mapa de calor: día de la semana × hora.
class DashCalor {
  const DashCalor({
    required this.dia,
    required this.hora,
    this.importe = 0,
    this.notas = 0,
  });

  /// 0 = lunes … 6 = domingo.
  final int dia;
  final int hora;
  final double importe;
  final int notas;

  factory DashCalor.desdeJson(Map<String, dynamic> j) => DashCalor(
    dia: _entero(j['dia']),
    hora: _entero(j['hora']),
    importe: _num(j['importe']),
    notas: _entero(j['notas']),
  );
}

class DashboardVentas {
  const DashboardVentas({
    required this.desde,
    required this.hasta,
    this.soloPropio = false,
    this.actual = const DashTotalesVentas(),
    this.anterior = const DashTotalesVentas(),
    this.serie = const [],
    this.atipicos = const [],
    this.mes = const DashMes(),
    this.porVendedor = const [],
    this.porCategoria = const [],
    this.porFormaPago = const [],
    this.topProductos = const [],
    this.pareto = const [],
    this.clientesAl80 = 0,
    this.clientesTotal = 0,
    this.calor = const [],
  });

  final DateTime desde;
  final DateTime hasta;
  final bool soloPropio;
  final DashTotalesVentas actual;
  final DashTotalesVentas anterior;
  final List<DashDiaVenta> serie;
  final List<DashAtipico> atipicos;
  final DashMes mes;
  final List<DashItem> porVendedor;
  final List<DashItem> porCategoria;
  final List<DashItem> porFormaPago;
  final List<DashItem> topProductos;
  final List<DashPareto> pareto;

  /// Cuántos clientes hacen el 80 % de lo vendido.
  final int clientesAl80;
  final int clientesTotal;
  final List<DashCalor> calor;

  factory DashboardVentas.desdeJson(Map<String, dynamic> j) => DashboardVentas(
    desde: diaDeJson(j['desde']),
    hasta: diaDeJson(j['hasta']),
    soloPropio: j['soloPropio'] as bool? ?? false,
    actual: DashTotalesVentas.desdeJson(j['actual'] as Map<String, dynamic>?),
    anterior: DashTotalesVentas.desdeJson(
      j['anterior'] as Map<String, dynamic>?,
    ),
    serie: _lista(j['serie'], DashDiaVenta.desdeJson),
    atipicos: _lista(j['atipicos'], DashAtipico.desdeJson),
    mes: DashMes.desdeJson(j['mes'] as Map<String, dynamic>?),
    porVendedor: _lista(j['porVendedor'], DashItem.desdeJson),
    porCategoria: _lista(j['porCategoria'], DashItem.desdeJson),
    porFormaPago: _lista(j['porFormaPago'], DashItem.desdeJson),
    topProductos: _lista(j['topProductos'], DashItem.desdeJson),
    pareto: _lista(j['pareto'], DashPareto.desdeJson),
    clientesAl80: _entero(j['clientesAl80']),
    clientesTotal: _entero(j['clientesTotal']),
    calor: _lista(j['calor'], DashCalor.desdeJson),
  );
}

// --------------------------------------------------------------- Ganancias

class DashDiaGanancia {
  const DashDiaGanancia({
    required this.fecha,
    this.importe = 0,
    this.ganancia = 0,
    this.margen,
  });

  final DateTime fecha;
  final double importe;
  final double ganancia;

  /// En %; null si ese día no hubo venta.
  final double? margen;

  factory DashDiaGanancia.desdeJson(Map<String, dynamic> j) => DashDiaGanancia(
    fecha: diaDeJson(j['fecha']),
    importe: _num(j['importe']),
    ganancia: _num(j['ganancia']),
    margen: _numOpc(j['margen']),
  );
}

/// Un producto en la matriz margen × volumen.
class DashProductoGanancia {
  const DashProductoGanancia({
    required this.nombre,
    this.categoria = '',
    this.importe = 0,
    this.ganancia = 0,
    this.margen,
  });

  final String nombre;
  final String categoria;
  final double importe;
  final double ganancia;
  final double? margen;

  factory DashProductoGanancia.desdeJson(Map<String, dynamic> j) =>
      DashProductoGanancia(
        nombre: j['nombre'] as String? ?? '',
        categoria: j['categoria'] as String? ?? '',
        importe: _num(j['importe']),
        ganancia: _num(j['ganancia']),
        margen: _numOpc(j['margen']),
      );
}

class DashboardGanancias {
  const DashboardGanancias({
    required this.desde,
    required this.hasta,
    this.soloPropio = false,
    this.importe = 0,
    this.costo = 0,
    this.ganancia = 0,
    this.margen,
    this.gananciaAnterior = 0,
    this.margenAnterior,
    this.serie = const [],
    this.productos = const [],
    this.porCategoria = const [],
    this.lineasSinCosto = 0,
  });

  final DateTime desde;
  final DateTime hasta;
  final bool soloPropio;
  final double importe;
  final double costo;
  final double ganancia;
  final double? margen;
  final double gananciaAnterior;
  final double? margenAnterior;
  final List<DashDiaGanancia> serie;
  final List<DashProductoGanancia> productos;

  /// La ganancia de cada categoría.
  final List<DashItem> porCategoria;

  /// Productos que se vendieron sin costo conocido: su ganancia no es fiable.
  final int lineasSinCosto;

  factory DashboardGanancias.desdeJson(Map<String, dynamic> j) =>
      DashboardGanancias(
        desde: diaDeJson(j['desde']),
        hasta: diaDeJson(j['hasta']),
        soloPropio: j['soloPropio'] as bool? ?? false,
        importe: _num(j['importe']),
        costo: _num(j['costo']),
        ganancia: _num(j['ganancia']),
        margen: _numOpc(j['margen']),
        gananciaAnterior: _num(j['gananciaAnterior']),
        margenAnterior: _numOpc(j['margenAnterior']),
        serie: _lista(j['serie'], DashDiaGanancia.desdeJson),
        productos: _lista(j['productos'], DashProductoGanancia.desdeJson),
        porCategoria: _lista(j['porCategoria'], DashItem.desdeJson),
        lineasSinCosto: _entero(j['lineasSinCosto']),
      );
}

// ---------------------------------------------------------------- Cobranza

class DashDeudor {
  const DashDeudor({
    required this.cliente,
    this.saldo = 0,
    this.notas = 0,
    this.dias = 0,
  });

  final String cliente;
  final double saldo;
  final int notas;

  /// Los días de la deuda más vieja: lo que decide el color.
  final int dias;

  factory DashDeudor.desdeJson(Map<String, dynamic> j) => DashDeudor(
    cliente: j['cliente'] as String? ?? '',
    saldo: _num(j['saldo']),
    notas: _entero(j['notas']),
    dias: _entero(j['dias']),
  );
}

class DashCobroDia {
  const DashCobroDia({required this.fecha, this.valores = const []});

  final DateTime fecha;

  /// Uno por cada método de [DashboardCobranza.metodos], en ese orden.
  final List<double> valores;

  factory DashCobroDia.desdeJson(Map<String, dynamic> j) => DashCobroDia(
    fecha: diaDeJson(j['fecha']),
    valores: _numeros(j['valores']),
  );
}

class DashboardCobranza {
  const DashboardCobranza({
    required this.desde,
    required this.hasta,
    this.totalPorCobrar = 0,
    this.cuentas = 0,
    this.clientes = 0,
    this.antiguedad = const [],
    this.deudores = const [],
    this.cobradoPeriodo = 0,
    this.metodos = const [],
    this.cobros = const [],
    this.creditoOtorgado = 0,
  });

  final DateTime desde;
  final DateTime hasta;
  final double totalPorCobrar;
  final int cuentas;
  final int clientes;

  /// La deuda repartida por antigüedad, de lo reciente a lo más viejo.
  final List<DashItem> antiguedad;
  final List<DashDeudor> deudores;
  final double cobradoPeriodo;
  final List<String> metodos;
  final List<DashCobroDia> cobros;

  /// Lo vendido a crédito en el período, para compararlo con lo cobrado.
  final double creditoOtorgado;

  factory DashboardCobranza.desdeJson(Map<String, dynamic> j) =>
      DashboardCobranza(
        desde: diaDeJson(j['desde']),
        hasta: diaDeJson(j['hasta']),
        totalPorCobrar: _num(j['totalPorCobrar']),
        cuentas: _entero(j['cuentas']),
        clientes: _entero(j['clientes']),
        antiguedad: _lista(j['antiguedad'], DashItem.desdeJson),
        deudores: _lista(j['deudores'], DashDeudor.desdeJson),
        cobradoPeriodo: _num(j['cobradoPeriodo']),
        metodos: ((j['metodos'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        cobros: _lista(j['cobros'], DashCobroDia.desdeJson),
        creditoOtorgado: _num(j['creditoOtorgado']),
      );
}

// -------------------------------------------------------------- Inventario

class DashCobertura {
  const DashCobertura({
    required this.producto,
    this.stock = 0,
    this.unidad = '',
    this.ventaDiaria = 0,
    this.dias = 0,
  });

  final String producto;
  final double stock;
  final String unidad;

  /// Lo que sale por día en promedio, en unidad base.
  final double ventaDiaria;

  /// Cuántos días dura lo que hay al ritmo actual.
  final double dias;

  factory DashCobertura.desdeJson(Map<String, dynamic> j) => DashCobertura(
    producto: j['producto'] as String? ?? '',
    stock: _num(j['stock']),
    unidad: j['unidad'] as String? ?? '',
    ventaDiaria: _num(j['ventaDiaria']),
    dias: _num(j['dias']),
  );
}

class DashboardInventario {
  const DashboardInventario({
    this.valorTotal = 0,
    this.productos = 0,
    this.cobertura = const [],
    this.salud = const [],
    this.valorPorCategoria = const [],
    this.dormido = const [],
    this.dormidoTotal = 0,
    this.vencimientos = const [],
  });

  final double valorTotal;
  final int productos;

  /// Los que antes se acaban, al ritmo al que se venden.
  final List<DashCobertura> cobertura;

  /// Cuántos productos hay en cada estado de salud del stock.
  final List<DashItem> salud;
  final List<DashItem> valorPorCategoria;

  /// Plata parada en productos que no se venden desde hace un mes.
  final List<DashItem> dormido;
  final double dormidoTotal;

  /// Lo que vence, por ventanas de tiempo. Valorizado a costo.
  final List<DashItem> vencimientos;

  factory DashboardInventario.desdeJson(Map<String, dynamic> j) =>
      DashboardInventario(
        valorTotal: _num(j['valorTotal']),
        productos: _entero(j['productos']),
        cobertura: _lista(j['cobertura'], DashCobertura.desdeJson),
        salud: _lista(j['salud'], DashItem.desdeJson),
        valorPorCategoria: _lista(j['valorPorCategoria'], DashItem.desdeJson),
        dormido: _lista(j['dormido'], DashItem.desdeJson),
        dormidoTotal: _num(j['dormidoTotal']),
        vencimientos: _lista(j['vencimientos'], DashItem.desdeJson),
      );
}

// ----------------------------------------------------------------- Reparto

class DashDiaPedidos {
  const DashDiaPedidos({
    required this.fecha,
    this.pendientes = 0,
    this.confirmados = 0,
    this.anulados = 0,
  });

  final DateTime fecha;
  final int pendientes;
  final int confirmados;
  final int anulados;

  factory DashDiaPedidos.desdeJson(Map<String, dynamic> j) => DashDiaPedidos(
    fecha: diaDeJson(j['fecha']),
    pendientes: _entero(j['pendientes']),
    confirmados: _entero(j['confirmados']),
    anulados: _entero(j['anulados']),
  );
}

class DashboardReparto {
  const DashboardReparto({
    required this.desde,
    required this.hasta,
    this.soloPropio = false,
    this.serie = const [],
    this.porEstado = const [],
    this.embudo = const [],
    this.novedadesPorMotivo,
    this.importeNovedades = 0,
    this.entregaCompleta,
  });

  final DateTime desde;
  final DateTime hasta;
  final bool soloPropio;
  final List<DashDiaPedidos> serie;
  final List<DashItem> porEstado;

  /// De lo pedido a lo entregado y cobrado, etapa por etapa.
  final List<DashItem> embudo;

  /// Lo que no llegó completo, por motivo. Null si quien mira no puede ver
  /// Novedades: en ese caso no se dibuja ese gráfico ni el KPI "No entregado".
  final List<DashItem>? novedadesPorMotivo;
  final double importeNovedades;

  /// De lo entregado, qué % llegó completo. Null si no hubo entregas.
  final double? entregaCompleta;

  factory DashboardReparto.desdeJson(Map<String, dynamic> j) =>
      DashboardReparto(
        desde: diaDeJson(j['desde']),
        hasta: diaDeJson(j['hasta']),
        soloPropio: j['soloPropio'] as bool? ?? false,
        serie: _lista(j['serie'], DashDiaPedidos.desdeJson),
        porEstado: _lista(j['porEstado'], DashItem.desdeJson),
        embudo: _lista(j['embudo'], DashItem.desdeJson),
        novedadesPorMotivo: j['novedadesPorMotivo'] == null
            ? null
            : _lista(j['novedadesPorMotivo'], DashItem.desdeJson),
        importeNovedades: _num(j['importeNovedades']),
        entregaCompleta: _numOpc(j['entregaCompleta']),
      );
}
