import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Una vista del menu.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.titulo,
    required this.icono,
    this.pendiente = true,
  });

  /// Mismo id que en el panel web: 'maestros.clientes'.
  final String id;
  final String titulo;
  final IconData icono;

  /// Todavia no tiene pantalla en la app.
  final bool pendiente;

  /// Ruta del navegador: 'maestros.clientes' -> '/maestros/clientes'.
  String get ruta => '/${id.split('.').join('/')}';
}

/// Un modulo con sus vistas.
class MenuGrupo {
  const MenuGrupo({
    required this.id,
    required this.titulo,
    required this.icono,
    required this.items,
  });

  final String id;
  final String titulo;
  final IconData icono;
  final List<MenuItem> items;

  /// Acento del modulo, el mismo del panel web.
  Color get color => Colores.modulos[id] ?? Colores.marca;
}

/// Modulos de la app.
///
/// Espejo de `Frontend/src/components/layout/navigation.ts`: mismos modulos, en
/// el mismo orden y con los mismos nombres, para que quien usa el panel web
/// encuentre lo mismo en el telefono. Las unicas ausentes son las vistas
/// marcadas como ocultas alla (series de comprobantes y parametros).
///
/// Si el menu del web cambia, este archivo se actualiza detras.
///
/// `pendiente` marca las vistas que aun no tienen pantalla en la app: en el
/// menu salen con un punto gris.
const menuGrupos = <MenuGrupo>[
  MenuGrupo(
    id: 'maestros',
    titulo: 'Maestros',
    icono: Icons.grid_view_outlined,
    items: [
      MenuItem(
        id: 'maestros.clientes',
        titulo: 'Clientes',
        icono: Icons.contacts_outlined,
      ),
      MenuItem(
        id: 'maestros.proveedores',
        titulo: 'Proveedores',
        icono: Icons.business_outlined,
      ),
      MenuItem(
        id: 'maestros.productos',
        titulo: 'Productos',
        icono: Icons.inventory_2_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'compras',
    titulo: 'Compras',
    icono: Icons.shopping_cart_outlined,
    items: [
      MenuItem(
        id: 'compras.ordenes',
        titulo: 'Órdenes de compra',
        icono: Icons.list_alt_outlined,
      ),
      MenuItem(
        id: 'compras.compras',
        titulo: 'Mis compras',
        icono: Icons.shopping_bag_outlined,
      ),
      MenuItem(
        id: 'compras.recepciones',
        titulo: 'Recepciones',
        icono: Icons.check_box_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'inv',
    titulo: 'Inventario',
    icono: Icons.inventory_outlined,
    items: [
      MenuItem(
        id: 'inv.almacenes',
        titulo: 'Almacenes',
        icono: Icons.warehouse_outlined,
      ),
      MenuItem(
        id: 'inv.stock',
        titulo: 'Stock por almacén',
        icono: Icons.inventory_outlined,
      ),
      MenuItem(
        id: 'inv.movimientos',
        titulo: 'Movimientos',
        icono: Icons.add_box_outlined,
      ),
      MenuItem(
        id: 'inv.transferencias',
        titulo: 'Transferencias',
        icono: Icons.local_shipping_outlined,
      ),
      MenuItem(
        id: 'inv.lotes',
        titulo: 'Lotes y vencimientos',
        icono: Icons.event_outlined,
      ),
      MenuItem(
        id: 'inv.conteos',
        titulo: 'Conteos cíclicos',
        icono: Icons.fact_check_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'fact',
    titulo: 'Facturación',
    icono: Icons.receipt_long_outlined,
    items: [
      MenuItem(
        id: 'fact.pedidos',
        titulo: 'Pedidos',
        icono: Icons.list_alt_outlined,
      ),
      MenuItem(
        id: 'fact.notaventa',
        titulo: 'Notas de venta',
        icono: Icons.description_outlined,
      ),
      MenuItem(
        id: 'fact.precios',
        titulo: 'Listas de precios',
        icono: Icons.payments_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'finanzas',
    titulo: 'Finanzas',
    icono: Icons.account_balance_outlined,
    items: [
      MenuItem(
        id: 'finanzas.cobrar',
        titulo: 'Cuentas por cobrar',
        icono: Icons.account_balance_wallet_outlined,
      ),
      MenuItem(
        id: 'finanzas.pagar',
        titulo: 'Cuentas por pagar',
        icono: Icons.credit_card_outlined,
      ),
      MenuItem(
        id: 'finanzas.miscobros',
        titulo: 'Mis cobros',
        icono: Icons.savings_outlined,
      ),
      MenuItem(
        id: 'finanzas.arqueo',
        titulo: 'Arqueo diario',
        icono: Icons.calculate_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'tms',
    titulo: 'TMS',
    icono: Icons.local_shipping_outlined,
    items: [
      MenuItem(id: 'tms.rutas', titulo: 'Rutas', icono: Icons.route_outlined),
      MenuItem(
        id: 'tms.flota',
        titulo: 'Flota',
        icono: Icons.local_shipping_outlined,
      ),
      MenuItem(
        id: 'tms.conductores',
        titulo: 'Conductores',
        icono: Icons.badge_outlined,
      ),
      MenuItem(
        id: 'tms.tracking',
        titulo: 'Tracking',
        icono: Icons.my_location_outlined,
      ),
      MenuItem(
        id: 'tms.liquidacion',
        titulo: 'Liquidación de reparto',
        icono: Icons.payments_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'dms',
    titulo: 'DMS',
    icono: Icons.storefront_outlined,
    items: [
      MenuItem(
        id: 'dms.visitas',
        titulo: 'Visitas',
        icono: Icons.storefront_outlined,
      ),
      MenuItem(
        id: 'dms.cobranzas',
        titulo: 'Cobranzas',
        icono: Icons.account_balance_wallet_outlined,
      ),
      MenuItem(
        id: 'dms.devoluciones',
        titulo: 'Devoluciones',
        icono: Icons.undo,
      ),
      MenuItem(
        id: 'dms.evidencias',
        titulo: 'Evidencias',
        icono: Icons.fact_check_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'rrhh',
    titulo: 'RR. HH.',
    icono: Icons.people_outline,
    items: [
      MenuItem(
        id: 'rrhh.empleados',
        titulo: 'Empleados',
        icono: Icons.people_outline,
      ),
      MenuItem(
        id: 'rrhh.asistencia',
        titulo: 'Asistencia',
        icono: Icons.event_available_outlined,
      ),
      MenuItem(
        id: 'rrhh.vacaciones',
        titulo: 'Vacaciones',
        icono: Icons.event_outlined,
      ),
      MenuItem(
        id: 'rrhh.nomina',
        titulo: 'Nómina',
        icono: Icons.payments_outlined,
      ),
      MenuItem(
        id: 'rrhh.desempeno',
        titulo: 'Desempeño',
        icono: Icons.speed_outlined,
      ),
    ],
  ),
  MenuGrupo(
    id: 'config',
    titulo: 'Configuración',
    icono: Icons.settings_outlined,
    items: [
      MenuItem(
        id: 'config.usuarios',
        pendiente: false,
        titulo: 'Usuarios',
        icono: Icons.manage_accounts_outlined,
      ),
      MenuItem(
        id: 'config.roles',
        pendiente: false,
        titulo: 'Roles',
        icono: Icons.badge_outlined,
      ),
      MenuItem(
        id: 'config.accesos',
        titulo: 'Accesos',
        icono: Icons.verified_user_outlined,
      ),
      MenuItem(
        id: 'config.empresa',
        pendiente: false,
        titulo: 'Empresa',
        icono: Icons.business_outlined,
      ),
    ],
  ),
];

/// Busca la vista y su modulo a partir de la ruta del navegador.
({MenuGrupo? grupo, MenuItem? item}) resolverRuta(String ruta) {
  for (final grupo in menuGrupos) {
    for (final item in grupo.items) {
      if (item.ruta == ruta) return (grupo: grupo, item: item);
    }
  }
  return (grupo: null, item: null);
}
