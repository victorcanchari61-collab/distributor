import 'package:flutter/material.dart';

import '../../../compartido/fechas.dart';

// ----------------------------------------------------------------- Estados

/// El estado de un cliente (o vendedor, o zona) por cuánto cayó lo que compra:
/// la escala de siempre del negocio. Es la misma del panel web.
enum EstadoCaida {
  critico('CRITICO', 'Crítico', '71 % o más', Color(0xFFDC2626)),
  riesgo('RIESGO', 'En riesgo', '26 - 70 %', Color(0xFFEA580C)),
  seguimiento('SEGUIMIENTO', 'En seguimiento', '11 - 25 %', Color(0xFF2563EB)),
  normal('NORMAL', 'Normal', '0 - 10 %', Color(0xFF16A34A)),
  sinBase(
    'SIN_BASE',
    'Sin comparación',
    'Sin ventas el año anterior',
    Color(0xFF64748B),
  );

  const EstadoCaida(this.clave, this.etiqueta, this.rango, this.color);

  final String clave;
  final String etiqueta;

  /// Qué rango de caída cubre.
  final String rango;
  final Color color;

  static EstadoCaida desdeClave(String? clave) => values.firstWhere(
    (e) => e.clave == clave,
    orElse: () => EstadoCaida.sinBase,
  );
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// Un día escrito como "2026-10-27" o "2026-10-27T00:00:00".
DateTime _dia(Object? v) => fechaDeJson(v as String);
DateTime? _diaOpc(Object? v) => fechaDeJsonOpcional(v);

class RangoDias {
  const RangoDias(this.desde, this.hasta);

  final DateTime desde;
  final DateTime hasta;

  factory RangoDias.desdeJson(Map<String, dynamic> j) =>
      RangoDias(_dia(j['desde']), _dia(j['hasta']));
}

/// Qué se mide y contra qué: el tramo pedido y el mismo tramo del año anterior.
class PeriodoCaida {
  const PeriodoCaida({
    required this.actual,
    required this.anterior,
    required this.etiqueta,
    required this.etiquetaAnterior,
  });

  final RangoDias actual;
  final RangoDias anterior;

  /// "1 ene - 27 oct 2026"
  final String etiqueta;
  final String etiquetaAnterior;

  factory PeriodoCaida.desdeJson(Map<String, dynamic> j) => PeriodoCaida(
    actual: RangoDias.desdeJson(j['actual'] as Map<String, dynamic>),
    anterior: RangoDias.desdeJson(j['anterior'] as Map<String, dynamic>),
    etiqueta: j['etiqueta'] as String? ?? '',
    etiquetaAnterior: j['etiquetaAnterior'] as String? ?? '',
  );
}

/// Una tarjeta de un reporte: cuántos hay en un estado y cuánta venta está en
/// juego.
class ResumenEstado {
  const ResumenEstado(this.estado, this.clientes, this.monto);

  final EstadoCaida estado;
  final int clientes;
  final double monto;

  factory ResumenEstado.desdeJson(Map<String, dynamic> j) => ResumenEstado(
    EstadoCaida.desdeClave(j['estado'] as String?),
    _i(j['clientes']),
    _d(j['monto']),
  );
}

List<ResumenEstado> _resumenes(Object? v) => [
  for (final e in (v as List?) ?? const [])
    ResumenEstado.desdeJson(e as Map<String, dynamic>),
];

// ----------------------------------------------------------- Clientes con caída

class FilaCaida {
  const FilaCaida({
    required this.id,
    required this.codigo,
    required this.cliente,
    required this.documento,
    required this.telefono,
    required this.vendedor,
    required this.mercado,
    required this.ruta,
    required this.categoriaCodigo,
    required this.categoriaColor,
    required this.ultimaCompra,
    required this.diasSinCompra,
    required this.ventaAnterior,
    required this.ventaActual,
    required this.variacion,
    required this.caidaPct,
    required this.montoRiesgo,
    required this.estado,
    required this.gestionEtiqueta,
    required this.proximoSeguimiento,
    required this.seguimientoVencido,
  });

  final int id;
  final String codigo;
  final String cliente;
  final String documento;
  final String? telefono;
  final String? vendedor;
  final String? mercado;
  final String? ruta;
  final String? categoriaCodigo;
  final String? categoriaColor;
  final DateTime? ultimaCompra;
  final int? diasSinCompra;
  final double ventaAnterior;
  final double ventaActual;

  /// Actual menos anterior: negativa es plata que se dejó de vender.
  final double variacion;

  /// Positiva si cayó. Nula si el año anterior no compró.
  final double? caidaPct;

  /// Lo que dejó de comprar (cero si compra igual o más).
  final double montoRiesgo;
  final EstadoCaida estado;
  final String? gestionEtiqueta;
  final DateTime? proximoSeguimiento;
  final bool seguimientoVencido;

  String get buscable =>
      '$cliente $documento $codigo ${vendedor ?? ''} ${mercado ?? ''}'
          .toLowerCase();

  factory FilaCaida.desdeJson(Map<String, dynamic> j) => FilaCaida(
    id: _i(j['id']),
    codigo: j['codigo'] as String? ?? '',
    cliente: j['cliente'] as String? ?? '',
    documento: j['documento'] as String? ?? '',
    telefono: j['telefono'] as String?,
    vendedor: j['vendedor'] as String?,
    mercado: j['mercado'] as String?,
    ruta: j['ruta'] as String?,
    categoriaCodigo: j['categoriaCodigo'] as String?,
    categoriaColor: j['categoriaColor'] as String?,
    ultimaCompra: _diaOpc(j['ultimaCompra']),
    diasSinCompra: (j['diasSinCompra'] as num?)?.toInt(),
    ventaAnterior: _d(j['ventaAnterior']),
    ventaActual: _d(j['ventaActual']),
    variacion: _d(j['variacion']),
    caidaPct: (j['caidaPct'] as num?)?.toDouble(),
    montoRiesgo: _d(j['montoRiesgo']),
    estado: EstadoCaida.desdeClave(j['estado'] as String?),
    gestionEtiqueta: j['gestionEtiqueta'] as String?,
    proximoSeguimiento: _diaOpc(j['proximoSeguimiento']),
    seguimientoVencido: j['seguimientoVencido'] as bool? ?? false,
  );
}

class CaidaClientes {
  const CaidaClientes({
    required this.periodo,
    required this.estados,
    required this.ventaAnterior,
    required this.ventaActual,
    required this.soloPropios,
    required this.items,
  });

  final PeriodoCaida periodo;
  final List<ResumenEstado> estados;
  final double ventaAnterior;
  final double ventaActual;
  final bool soloPropios;
  final List<FilaCaida> items;

  factory CaidaClientes.desdeJson(Map<String, dynamic> j) => CaidaClientes(
    periodo: PeriodoCaida.desdeJson(j['periodo'] as Map<String, dynamic>),
    estados: _resumenes(j['estados']),
    ventaAnterior: _d(j['ventaAnterior']),
    ventaActual: _d(j['ventaActual']),
    soloPropios: j['soloPropios'] as bool? ?? false,
    items: [
      for (final e in (j['items'] as List?) ?? const [])
        FilaCaida.desdeJson(e as Map<String, dynamic>),
    ],
  );
}

/// Qué pasó con un producto del cliente entre los dos tramos.
enum SituacionProducto {
  dejo('DEJO', 'Dejó de comprarlo', Color(0xFFDC2626)),
  nuevo('NUEVO', 'Nuevo', Color(0xFF2563EB)),
  igual('IGUAL', 'Igual', Color(0xFF64748B)),
  mas('MAS', 'Compra más', Color(0xFF16A34A)),
  menos('MENOS', 'Compra menos', Color(0xFFEA580C));

  const SituacionProducto(this.clave, this.etiqueta, this.color);

  final String clave;
  final String etiqueta;
  final Color color;

  static SituacionProducto desdeClave(String? c) => values.firstWhere(
    (s) => s.clave == c,
    orElse: () => SituacionProducto.igual,
  );
}

class ProductoSituacion {
  const ProductoSituacion({
    required this.codigo,
    required this.producto,
    required this.ventaAnterior,
    required this.ventaActual,
    required this.variacion,
    required this.situacion,
  });

  final String codigo;
  final String producto;
  final double ventaAnterior;
  final double ventaActual;
  final double variacion;
  final SituacionProducto situacion;

  factory ProductoSituacion.desdeJson(Map<String, dynamic> j) =>
      ProductoSituacion(
        codigo: j['codigo'] as String? ?? '',
        producto: j['producto'] as String? ?? '',
        ventaAnterior: _d(j['ventaAnterior']),
        ventaActual: _d(j['ventaActual']),
        variacion: _d(j['variacion']),
        situacion: SituacionProducto.desdeClave(j['situacion'] as String?),
      );
}

List<ProductoSituacion> _productos(Object? v) => [
  for (final e in (v as List?) ?? const [])
    ProductoSituacion.desdeJson(e as Map<String, dynamic>),
];

class QueDejoDeComprar {
  const QueDejoDeComprar({
    required this.cliente,
    required this.periodo,
    required this.productos,
  });

  final String cliente;
  final PeriodoCaida periodo;
  final List<ProductoSituacion> productos;

  factory QueDejoDeComprar.desdeJson(Map<String, dynamic> j) =>
      QueDejoDeComprar(
        cliente: j['cliente'] as String? ?? '',
        periodo: PeriodoCaida.desdeJson(j['periodo'] as Map<String, dynamic>),
        productos: _productos(j['productos']),
      );
}

// -------------------------------------------------------- Vendedores con caída

class FilaVendedor {
  const FilaVendedor({
    required this.usuarioId,
    required this.vendedor,
    required this.ventaAnterior,
    required this.ventaActual,
    required this.variacion,
    required this.caidaPct,
    required this.estado,
    required this.clientes,
    required this.clientesEnCaida,
    required this.clientesCriticos,
    required this.montoRiesgo,
  });

  final int usuarioId;
  final String vendedor;
  final double ventaAnterior;
  final double ventaActual;
  final double variacion;
  final double? caidaPct;
  final EstadoCaida estado;

  /// Clientes a los que vendió en alguno de los dos tramos.
  final int clientes;

  /// De esos, cuántos compran menos que antes (En seguimiento o peor).
  final int clientesEnCaida;
  final int clientesCriticos;
  final double montoRiesgo;

  factory FilaVendedor.desdeJson(Map<String, dynamic> j) => FilaVendedor(
    usuarioId: _i(j['usuarioId']),
    vendedor: j['vendedor'] as String? ?? '',
    ventaAnterior: _d(j['ventaAnterior']),
    ventaActual: _d(j['ventaActual']),
    variacion: _d(j['variacion']),
    caidaPct: (j['caidaPct'] as num?)?.toDouble(),
    estado: EstadoCaida.desdeClave(j['estado'] as String?),
    clientes: _i(j['clientes']),
    clientesEnCaida: _i(j['clientesEnCaida']),
    clientesCriticos: _i(j['clientesCriticos']),
    montoRiesgo: _d(j['montoRiesgo']),
  );
}

class VendedoresCaida {
  const VendedoresCaida({
    required this.periodo,
    required this.estados,
    required this.items,
  });

  final PeriodoCaida periodo;
  final List<ResumenEstado> estados;
  final List<FilaVendedor> items;

  factory VendedoresCaida.desdeJson(Map<String, dynamic> j) => VendedoresCaida(
    periodo: PeriodoCaida.desdeJson(j['periodo'] as Map<String, dynamic>),
    estados: _resumenes(j['estados']),
    items: [
      for (final e in (j['items'] as List?) ?? const [])
        FilaVendedor.desdeJson(e as Map<String, dynamic>),
    ],
  );
}

// ------------------------------------------------------ Gestión y seguimiento

/// Cómo se hizo un contacto.
enum TipoContacto {
  llamada('LLAMADA', 'Llamada', Icons.call_outlined),
  whatsapp('WHATSAPP', 'WhatsApp', Icons.chat_outlined),
  visita('VISITA', 'Visita', Icons.storefront_outlined),
  correo('CORREO', 'Correo', Icons.mail_outline);

  const TipoContacto(this.clave, this.etiqueta, this.icono);

  final String clave;
  final String etiqueta;
  final IconData icono;

  static TipoContacto? desdeClave(String? c) {
    for (final t in values) {
      if (t.clave == c) return t;
    }
    return null;
  }
}

/// Cómo se lee un resultado de gestión: su color.
Color colorDeTono(String? tono) => switch (tono) {
  'positivo' => const Color(0xFF16A34A),
  'espera' => const Color(0xFF2563EB),
  'objecion' => const Color(0xFFEA580C),
  'perdido' => const Color(0xFFDC2626),
  _ => const Color(0xFF64748B),
};

class ResultadoGestion {
  const ResultadoGestion(this.clave, this.etiqueta, this.tono, this.cuando);

  final String clave;
  final String etiqueta;
  final String tono;

  /// Cuándo elegir este resultado, para ayudar a quien registra.
  final String cuando;

  factory ResultadoGestion.desdeJson(Map<String, dynamic> j) =>
      ResultadoGestion(
        j['clave'] as String? ?? '',
        j['etiqueta'] as String? ?? '',
        j['tono'] as String? ?? 'neutro',
        j['cuando'] as String? ?? '',
      );
}

class CatalogoSeguimiento {
  const CatalogoSeguimiento(this.resultados);

  final List<ResultadoGestion> resultados;

  factory CatalogoSeguimiento.desdeJson(Map<String, dynamic> j) =>
      CatalogoSeguimiento([
        for (final e in (j['resultados'] as List?) ?? const [])
          ResultadoGestion.desdeJson(e as Map<String, dynamic>),
      ]);
}

class ClienteBuscado {
  const ClienteBuscado({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.documento,
    required this.mercado,
    required this.activo,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String documento;
  final String? mercado;
  final bool activo;

  factory ClienteBuscado.desdeJson(Map<String, dynamic> j) => ClienteBuscado(
    id: _i(j['id']),
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    documento: j['documento'] as String? ?? '',
    mercado: j['mercado'] as String?,
    activo: j['activo'] as bool? ?? true,
  );
}

class Gestion {
  const Gestion({
    required this.id,
    required this.fecha,
    required this.tipoContacto,
    required this.tipoEtiqueta,
    required this.resultado,
    required this.resultadoEtiqueta,
    required this.tono,
    required this.comentario,
    required this.registradoPor,
    required this.proximoSeguimiento,
    required this.proximoTipoContacto,
    required this.proximaAccion,
    required this.seguimientoEstado,
    required this.vencida,
  });

  final int id;

  /// Cuándo se hizo el contacto.
  final DateTime fecha;
  final TipoContacto? tipoContacto;
  final String tipoEtiqueta;
  final String resultado;
  final String resultadoEtiqueta;
  final String tono;
  final String? comentario;
  final String? registradoPor;

  /// El día y la hora del siguiente contacto.
  final DateTime? proximoSeguimiento;
  final TipoContacto? proximoTipoContacto;
  final String? proximaAccion;

  /// PROGRAMADO, CUMPLIDO o nulo.
  final String? seguimientoEstado;

  /// El siguiente contacto sigue programado y su hora ya pasó.
  final bool vencida;

  bool get programado => seguimientoEstado == 'PROGRAMADO';

  factory Gestion.desdeJson(Map<String, dynamic> j) => Gestion(
    id: _i(j['id']),
    fecha: fechaDeJson(j['fecha'] as String),
    tipoContacto: TipoContacto.desdeClave(j['tipoContacto'] as String?),
    tipoEtiqueta: j['tipoEtiqueta'] as String? ?? '',
    resultado: j['resultado'] as String? ?? '',
    resultadoEtiqueta: j['resultadoEtiqueta'] as String? ?? '',
    tono: j['tono'] as String? ?? 'neutro',
    comentario: j['comentario'] as String?,
    registradoPor: j['registradoPor'] as String?,
    proximoSeguimiento: fechaDeJsonOpcional(j['proximoSeguimiento']),
    proximoTipoContacto: TipoContacto.desdeClave(
      j['proximoTipoContacto'] as String?,
    ),
    proximaAccion: j['proximaAccion'] as String?,
    seguimientoEstado: j['seguimientoEstado'] as String?,
    vencida: j['vencida'] as bool? ?? false,
  );
}

class DatosCliente {
  const DatosCliente({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.tipoDoc,
    required this.documento,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.mercado,
    required this.ruta,
    required this.vendedor,
    required this.diaVisita,
    required this.categoriaCodigo,
    required this.categoria,
    required this.categoriaColor,
    required this.activo,
    required this.estado,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String tipoDoc;
  final String documento;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? mercado;
  final String? ruta;
  final String? vendedor;
  final String? diaVisita;
  final String? categoriaCodigo;
  final String? categoria;
  final String? categoriaColor;
  final bool activo;
  final EstadoCaida estado;

  factory DatosCliente.desdeJson(Map<String, dynamic> j) => DatosCliente(
    id: _i(j['id']),
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    tipoDoc: j['tipoDoc'] as String? ?? '',
    documento: j['documento'] as String? ?? '',
    telefono: j['telefono'] as String?,
    email: j['email'] as String?,
    direccion: j['direccion'] as String?,
    mercado: j['mercado'] as String?,
    ruta: j['ruta'] as String?,
    vendedor: j['vendedor'] as String?,
    diaVisita: j['diaVisita'] as String?,
    categoriaCodigo: j['categoriaCodigo'] as String?,
    categoria: j['categoria'] as String?,
    categoriaColor: j['categoriaColor'] as String?,
    activo: j['activo'] as bool? ?? true,
    estado: EstadoCaida.desdeClave((j['estado'] as Map?)?['clave'] as String?),
  );
}

class PeriodoCliente {
  const PeriodoCliente({
    required this.etiqueta,
    required this.etiquetaAnterior,
    required this.ventas,
    required this.compras,
    required this.ticketPromedio,
    required this.ventasAnterior,
    required this.variacion,
    required this.caidaPct,
  });

  final String etiqueta;
  final String etiquetaAnterior;
  final double ventas;
  final int compras;
  final double ticketPromedio;
  final double ventasAnterior;
  final double variacion;
  final double? caidaPct;

  factory PeriodoCliente.desdeJson(Map<String, dynamic> j) => PeriodoCliente(
    etiqueta: j['etiqueta'] as String? ?? '',
    etiquetaAnterior: j['etiquetaAnterior'] as String? ?? '',
    ventas: _d(j['ventas']),
    compras: _i(j['compras']),
    ticketPromedio: _d(j['ticketPromedio']),
    ventasAnterior: _d(j['ventasAnterior']),
    variacion: _d(j['variacion']),
    caidaPct: (j['caidaPct'] as num?)?.toDouble(),
  );
}

class ProductoPrincipal {
  const ProductoPrincipal(this.producto, this.monto, this.porcentaje);

  final String producto;
  final double monto;
  final double porcentaje;
}

class MesCliente {
  const MesCliente(this.mes, this.importe);

  final String mes;
  final double importe;
}

class FichaCliente {
  const FichaCliente({
    required this.cliente,
    required this.diasSinComprar,
    required this.ultimaCompra,
    required this.ultimaCompraMonto,
    required this.saldoPorCobrar,
    required this.periodo,
    required this.ultimaGestion,
    required this.proximaGestion,
    required this.productosPrincipales,
    required this.meses,
  });

  final DatosCliente cliente;
  final int? diasSinComprar;
  final DateTime? ultimaCompra;
  final double ultimaCompraMonto;
  final double saldoPorCobrar;
  final PeriodoCliente periodo;
  final Gestion? ultimaGestion;
  final Gestion? proximaGestion;
  final List<ProductoPrincipal> productosPrincipales;

  /// Los últimos 24 meses: los primeros 12 son el año anterior y los últimos
  /// 12, el año en curso.
  final List<MesCliente> meses;

  factory FichaCliente.desdeJson(Map<String, dynamic> j) {
    final kpis = (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ultima = (kpis['ultimaCompra'] as Map?)?.cast<String, dynamic>();
    Gestion? g(Object? v) =>
        v is Map ? Gestion.desdeJson(v.cast<String, dynamic>()) : null;

    return FichaCliente(
      cliente: DatosCliente.desdeJson(j['cliente'] as Map<String, dynamic>),
      diasSinComprar: (kpis['diasSinComprar'] as num?)?.toInt(),
      ultimaCompra: _diaOpc(ultima?['fecha']),
      ultimaCompraMonto: _d(ultima?['monto']),
      saldoPorCobrar: _d(kpis['saldoPorCobrar']),
      periodo: PeriodoCliente.desdeJson(j['periodo'] as Map<String, dynamic>),
      ultimaGestion: g(j['ultimaGestion']),
      proximaGestion: g(j['proximaGestion']),
      productosPrincipales: [
        for (final e in (j['productosPrincipales'] as List?) ?? const [])
          ProductoPrincipal(
            (e as Map)['producto'] as String? ?? '',
            _d(e['monto']),
            _d(e['porcentaje']),
          ),
      ],
      meses: [
        for (final e in (j['meses'] as List?) ?? const [])
          MesCliente((e as Map)['mes'] as String? ?? '', _d(e['importe'])),
      ],
    );
  }
}

class GestionesCliente {
  const GestionesCliente({
    required this.items,
    required this.proximaGestion,
    required this.totalAnio,
  });

  final List<Gestion> items;
  final Gestion? proximaGestion;
  final int totalAnio;

  factory GestionesCliente.desdeJson(Map<String, dynamic> j) =>
      GestionesCliente(
        items: [
          for (final e in (j['items'] as List?) ?? const [])
            Gestion.desdeJson(e as Map<String, dynamic>),
        ],
        proximaGestion: j['proximaGestion'] is Map
            ? Gestion.desdeJson(
                (j['proximaGestion'] as Map).cast<String, dynamic>(),
              )
            : null,
        totalAnio: _i(j['totalAnio']),
      );
}

class VentaCliente {
  const VentaCliente({
    required this.numero,
    required this.fecha,
    required this.estado,
    required this.formaPago,
    required this.vendedor,
    required this.total,
    required this.pagado,
    required this.saldo,
  });

  final String numero;
  final DateTime fecha;
  final String estado;
  final String formaPago;
  final String? vendedor;
  final double total;
  final double pagado;
  final double saldo;
}

class ComprasCliente {
  const ComprasCliente({required this.ventas, required this.productos});

  final List<VentaCliente> ventas;
  final List<ProductoSituacion> productos;

  factory ComprasCliente.desdeJson(Map<String, dynamic> j) => ComprasCliente(
    ventas: [
      for (final e in (j['ventas'] as List?) ?? const [])
        VentaCliente(
          numero: (e as Map)['numero'] as String? ?? '',
          fecha: _dia(e['fecha']),
          estado: e['estado'] as String? ?? '',
          formaPago: e['formaPago'] as String? ?? '',
          vendedor: e['vendedor'] as String?,
          total: _d(e['total']),
          pagado: _d(e['pagado']),
          saldo: _d(e['saldo']),
        ),
    ],
    productos: _productos(j['productos']),
  );
}

class PedidoCliente {
  const PedidoCliente(this.numero, this.fecha, this.estado, this.condicionPago);

  final String numero;
  final DateTime fecha;
  final String estado;
  final String condicionPago;
}

class DevolucionCliente {
  const DevolucionCliente(
    this.numero,
    this.notaVenta,
    this.fecha,
    this.estado,
    this.motivo,
  );

  final String numero;
  final String notaVenta;
  final DateTime fecha;
  final String estado;
  final String? motivo;
}

class DocumentosCliente {
  const DocumentosCliente({required this.pedidos, required this.devoluciones});

  final List<PedidoCliente> pedidos;
  final List<DevolucionCliente> devoluciones;

  factory DocumentosCliente.desdeJson(Map<String, dynamic> j) =>
      DocumentosCliente(
        pedidos: [
          for (final e in (j['pedidos'] as List?) ?? const [])
            PedidoCliente(
              (e as Map)['numero'] as String? ?? '',
              _dia(e['fecha']),
              e['estado'] as String? ?? '',
              e['condicionPago'] as String? ?? '',
            ),
        ],
        devoluciones: [
          for (final e in (j['devoluciones'] as List?) ?? const [])
            DevolucionCliente(
              (e as Map)['numero'] as String? ?? '',
              e['notaVenta'] as String? ?? '',
              _dia(e['fecha']),
              e['estado'] as String? ?? '',
              e['motivo'] as String?,
            ),
        ],
      );
}

// ------------------------------------------- Dashboard: sin ventas y zonas

class ProductoSinVenta {
  const ProductoSinVenta({
    required this.codigo,
    required this.producto,
    required this.categoria,
    required this.marca,
    required this.unidadBase,
    required this.stock,
    required this.valorStock,
    required this.ultimaVenta,
    required this.diasSinVender,
    required this.vendidoEnOtrasZonas,
  });

  final String codigo;
  final String producto;
  final String? categoria;
  final String? marca;
  final String unidadBase;

  /// Lo que hay en todos los almacenes, en unidad base.
  final double stock;

  /// Ese stock a su costo: la plata parada.
  final double valorStock;
  final DateTime? ultimaVenta;
  final int? diasSinVender;
  final double vendidoEnOtrasZonas;

  String get buscable =>
      '$producto $codigo ${categoria ?? ''} ${marca ?? ''}'.toLowerCase();

  factory ProductoSinVenta.desdeJson(Map<String, dynamic> j) =>
      ProductoSinVenta(
        codigo: j['codigo'] as String? ?? '',
        producto: j['producto'] as String? ?? '',
        categoria: j['categoria'] as String?,
        marca: j['marca'] as String?,
        unidadBase: j['unidadBase'] as String? ?? '',
        stock: _d(j['stock']),
        valorStock: _d(j['valorStock']),
        ultimaVenta: _diaOpc(j['ultimaVenta']),
        diasSinVender: (j['diasSinVender'] as num?)?.toInt(),
        vendidoEnOtrasZonas: _d(j['vendidoEnOtrasZonas']),
      );
}

class ProductosSinVentas {
  const ProductosSinVentas({
    required this.rango,
    required this.productosActivos,
    required this.sinVentas,
    required this.conStock,
    required this.sinStock,
    required this.nuncaVendidos,
    required this.capitalParado,
    required this.items,
  });

  final RangoDias rango;
  final int productosActivos;
  final int sinVentas;
  final int conStock;
  final int sinStock;
  final int nuncaVendidos;
  final double capitalParado;
  final List<ProductoSinVenta> items;

  factory ProductosSinVentas.desdeJson(Map<String, dynamic> j) {
    final r = (j['resumen'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProductosSinVentas(
      rango: RangoDias.desdeJson(j['rango'] as Map<String, dynamic>),
      productosActivos: _i(r['productosActivos']),
      sinVentas: _i(r['sinVentas']),
      conStock: _i(r['conStock']),
      sinStock: _i(r['sinStock']),
      nuncaVendidos: _i(r['nuncaVendidos']),
      capitalParado: _d(r['capitalParado']),
      items: [
        for (final e in (j['items'] as List?) ?? const [])
          ProductoSinVenta.desdeJson(e as Map<String, dynamic>),
      ],
    );
  }
}

class ZonaCaida {
  const ZonaCaida({
    required this.nombre,
    required this.clientes,
    required this.conVentas,
    required this.criticos,
    required this.enRiesgo,
    required this.enSeguimiento,
    required this.ventaAnterior,
    required this.ventaActual,
    required this.variacion,
    required this.caidaPct,
    required this.ventaPerdida,
    required this.saldoPorCobrar,
  });

  final String nombre;
  final int clientes;
  final int conVentas;
  final int criticos;
  final int enRiesgo;
  final int enSeguimiento;
  final double ventaAnterior;
  final double ventaActual;
  final double variacion;
  final double? caidaPct;
  final double ventaPerdida;
  final double saldoPorCobrar;

  factory ZonaCaida.desdeJson(Map<String, dynamic> j) => ZonaCaida(
    nombre: j['nombre'] as String? ?? '',
    clientes: _i(j['clientes']),
    conVentas: _i(j['conVentas']),
    criticos: _i(j['criticos']),
    enRiesgo: _i(j['enRiesgo']),
    enSeguimiento: _i(j['enSeguimiento']),
    ventaAnterior: _d(j['ventaAnterior']),
    ventaActual: _d(j['ventaActual']),
    variacion: _d(j['variacion']),
    caidaPct: (j['caidaPct'] as num?)?.toDouble(),
    ventaPerdida: _d(j['ventaPerdida']),
    saldoPorCobrar: _d(j['saldoPorCobrar']),
  );
}

class ZonasCaida {
  const ZonasCaida({
    required this.periodo,
    required this.soloPropios,
    required this.items,
  });

  final PeriodoCaida periodo;
  final bool soloPropios;
  final List<ZonaCaida> items;

  factory ZonasCaida.desdeJson(Map<String, dynamic> j) => ZonasCaida(
    periodo: PeriodoCaida.desdeJson(j['periodo'] as Map<String, dynamic>),
    soloPropios: j['soloPropios'] as bool? ?? false,
    items: [
      for (final e in (j['items'] as List?) ?? const [])
        ZonaCaida.desdeJson(e as Map<String, dynamic>),
    ],
  );
}
