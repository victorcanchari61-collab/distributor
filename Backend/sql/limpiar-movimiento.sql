/*
 * Deja el sistema en cero: borra todo lo registrado operando y también el
 * catálogo de productos, presentaciones, listas de precios y precios.
 *
 * Conserva lo que no es "movimiento" ni "catálogo de productos": clientes,
 * proveedores, almacenes, rutas, usuarios y permisos.
 *
 * Las cuentas por cobrar y por pagar no tienen tabla propia: son las ventas a
 * crédito y las compras a crédito con saldo, así que desaparecen al vaciar
 * esas dos.
 *
 * El orden importa: primero lo que referencia a un producto (compras, ventas,
 * kardex...), recién después el producto mismo — no se puede borrar lo que
 * algo más todavía señala.
 *
 * Se desactivan las llaves foráneas porque TRUNCATE no admite el orden que sí
 * permitiría DELETE, y se vuelven a activar al final. Reinicia además los
 * correlativos: la próxima compra vuelve a ser la 1.
 *
 * Uso:
 *   mysql -u root distributor < Backend/sql/limpiar-movimiento.sql
 *
 * OJO: no se puede deshacer. Es para bases de prueba.
 */

SET FOREIGN_KEY_CHECKS = 0;

-- --- Inventario: kardex, costos y documentos ---
TRUNCATE TABLE consumoscapa;
TRUNCATE TABLE capascosto;
TRUNCATE TABLE movimientosinventario;
TRUNCATE TABLE documentosinventario;

-- --- Compras y cuentas por pagar ---
TRUNCATE TABLE comprapago;
TRUNCATE TABLE compradetalle;
TRUNCATE TABLE compras;
TRUNCATE TABLE ordencompradetalle;
TRUNCATE TABLE ordenescompra;

-- --- Ventas, devoluciones y cuentas por cobrar ---
TRUNCATE TABLE devoluciondetalles;
TRUNCATE TABLE devoluciones;
TRUNCATE TABLE pagoventa;
TRUNCATE TABLE notaventadetalle;
TRUNCATE TABLE notasventa;
TRUNCATE TABLE pedidodetalle;
TRUNCATE TABLE pedidos;

-- --- Préstamos y despachos ---
TRUNCATE TABLE prestamodetalle;
TRUNCATE TABLE prestamos;
TRUNCATE TABLE despachodetalles;
TRUNCATE TABLE despachos;

-- --- Caja del día ---
TRUNCATE TABLE arqueogastos;
TRUNCATE TABLE arqueopagosdigitales;
TRUNCATE TABLE arqueocaja;

-- --- Catálogo: productos, presentaciones y listas de precios ---
TRUNCATE TABLE precios;
TRUNCATE TABLE listasprecio;
TRUNCATE TABLE productopresentaciones;
TRUNCATE TABLE productos;

SET FOREIGN_KEY_CHECKS = 1;

/*
 * Lo que queda en pie, para comprobarlo de un vistazo.
 */
SELECT 'productos' AS catalogo, COUNT(*) AS quedan FROM productos
UNION ALL SELECT 'presentaciones', COUNT(*) FROM productopresentaciones
UNION ALL SELECT 'precios', COUNT(*) FROM precios
UNION ALL SELECT 'listasprecio', COUNT(*) FROM listasprecio
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'proveedores', COUNT(*) FROM proveedores
UNION ALL SELECT 'almacenes', COUNT(*) FROM almacenes;
