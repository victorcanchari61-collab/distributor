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
/// Es el espejo de `navigation.ts` del panel web, con dos diferencias pensadas
/// para el telefono:
///
///   - No se listan las vistas que solo tienen sentido en escritorio (importar
///     archivos, matrices de permisos).
///   - El orden pone primero lo que un vendedor usa en la calle.
const menuGrupos = <MenuGrupo>[
  MenuGrupo(
    id: 'dms',
    titulo: 'Mi ruta',
    icono: Icons.storefront_outlined,
    items: [
      MenuItem(id: 'dms.visitas', titulo: 'Visitas', icono: Icons.pin_drop_outlined),
      MenuItem(id: 'dms.cobranzas', titulo: 'Cobranzas', icono: Icons.payments_outlined),
      MenuItem(id: 'dms.devoluciones', titulo: 'Devoluciones', icono: Icons.undo),
    ],
  ),
  MenuGrupo(
    id: 'fact',
    titulo: 'Ventas',
    icono: Icons.receipt_long_outlined,
    items: [
      MenuItem(id: 'fact.pedidos', titulo: 'Pedidos', icono: Icons.list_alt_outlined),
      MenuItem(id: 'fact.notaventa', titulo: 'Notas de venta', icono: Icons.description_outlined),
    ],
  ),
  MenuGrupo(
    id: 'maestros',
    titulo: 'Maestros',
    icono: Icons.grid_view_outlined,
    items: [
      MenuItem(id: 'maestros.clientes', titulo: 'Clientes', icono: Icons.contacts_outlined),
      MenuItem(id: 'maestros.proveedores', titulo: 'Proveedores', icono: Icons.business_outlined),
      MenuItem(id: 'maestros.productos', titulo: 'Productos', icono: Icons.inventory_2_outlined),
    ],
  ),
  MenuGrupo(
    id: 'inv',
    titulo: 'Inventario',
    icono: Icons.inventory_outlined,
    items: [
      MenuItem(id: 'inv.stock', titulo: 'Stock por almacén', icono: Icons.warehouse_outlined),
      MenuItem(id: 'inv.movimientos', titulo: 'Movimientos', icono: Icons.swap_horiz),
    ],
  ),
  MenuGrupo(
    id: 'finanzas',
    titulo: 'Finanzas',
    icono: Icons.account_balance_outlined,
    items: [
      MenuItem(id: 'finanzas.miscobros', titulo: 'Mis cobros', icono: Icons.savings_outlined),
      MenuItem(id: 'finanzas.arqueo', titulo: 'Arqueo diario', icono: Icons.calculate_outlined),
    ],
  ),
  MenuGrupo(
    id: 'tms',
    titulo: 'TMS',
    icono: Icons.local_shipping_outlined,
    items: [
      MenuItem(id: 'tms.rutas', titulo: 'Rutas', icono: Icons.route_outlined),
      MenuItem(id: 'tms.tracking', titulo: 'Tracking', icono: Icons.my_location_outlined),
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
