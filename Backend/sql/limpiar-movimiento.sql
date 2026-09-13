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
 * Tolera tablas que no existen (bases con migraciones más viejas o más
 * nuevas que el local, como la del VPS): TRUNCATE_SI_EXISTE mira
 * information_schema antes de vaciar cada una, en vez de reventar en la
 * primera tabla que falte.
 *
 * Uso:
 *   mysql -u root distributor < Backend/sql/limpiar-movimiento.sql
 *
 * OJO: no se puede deshacer. Es para bases de prueba.
 */

SET FOREIGN_KEY_CHECKS = 0;

DROP PROCEDURE IF EXISTS truncate_si_existe;

DELIMITER $$
CREATE PROCEDURE truncate_si_existe(IN nombre_tabla VARCHAR(128))
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_name = nombre_tabla
  ) THEN
    SET @sql = CONCAT('TRUNCATE TABLE `', nombre_tabla, '`');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('vaciada: ', nombre_tabla) AS resultado;
  ELSE
    SELECT CONCAT('no existe, se saltó: ', nombre_tabla) AS resultado;
  END IF;
END$$
DELIMITER ;

-- --- Inventario: kardex, costos y documentos ---
CALL truncate_si_existe('consumoscapa');
CALL truncate_si_existe('capascosto');
CALL truncate_si_existe('movimientosinventario');
CALL truncate_si_existe('documentosinventario');

-- --- Compras y cuentas por pagar ---
CALL truncate_si_existe('comprapago');
CALL truncate_si_existe('compradetalle');
CALL truncate_si_existe('compras');
CALL truncate_si_existe('ordencompradetalle');
CALL truncate_si_existe('ordenescompra');

-- --- Ventas, devoluciones y cuentas por cobrar ---
CALL truncate_si_existe('devoluciondetalles');
CALL truncate_si_existe('devoluciones');
CALL truncate_si_existe('pagoventa');
CALL truncate_si_existe('notaventadetalle');
CALL truncate_si_existe('notasventa');
CALL truncate_si_existe('pedidodetalle');
CALL truncate_si_existe('pedidos');

-- --- Préstamos y despachos ---
CALL truncate_si_existe('prestamodetalle');
CALL truncate_si_existe('prestamos');
CALL truncate_si_existe('despachodetalles');
CALL truncate_si_existe('despachos');

-- --- Caja del día ---
CALL truncate_si_existe('arqueogastos');
CALL truncate_si_existe('arqueopagosdigitales');
CALL truncate_si_existe('arqueocaja');

-- --- Catálogo: productos, presentaciones y listas de precios ---
CALL truncate_si_existe('precios');
CALL truncate_si_existe('listasprecio');
CALL truncate_si_existe('productopresentaciones');
CALL truncate_si_existe('productos');

DROP PROCEDURE truncate_si_existe;

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
