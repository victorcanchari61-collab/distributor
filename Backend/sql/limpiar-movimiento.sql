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
 * Los nombres van en el PascalCase que usa EF Core (entity.ToTable("..."),
 * en Backend/Backend/Data/AppDbContext.cs) y NO en minúsculas.
 *
 * MySQL en Windows guarda los nombres de tabla en minúsculas sin que
 * importe cómo se pidan (lower_case_table_names=1); en Linux —como el
 * VPS— se guardan tal como EF Core los creó, en PascalCase, y truncar con
 * otro case revienta con "no existe" aunque la tabla sí esté. Por eso
 * truncate_si_existe busca el nombre TAL CUAL está guardado en
 * information_schema y trunca con ese, en vez de confiar en el case con el
 * que se lo llama.
 *
 * Tolera además tablas que de verdad no existen (bases con migraciones más
 * viejas o más nuevas que esta): truncate_si_existe mira information_schema
 * antes de vaciar cada una, en vez de reventar en la primera que falte.
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
  /*
   * Se busca el nombre TAL COMO ESTA GUARDADO, sin asumir un case fijo.
   *
   * En Windows (lower_case_table_names=1) EF Core igual pide "Despachos"
   * pero el motor lo guarda como "despachos"; en Linux se guarda tal cual
   * se creo, "Despachos". Comparar sin BINARY encuentra la tabla en los
   * dos casos (la coleccion de information_schema no distingue mayusculas
   * aunque el disco si), y de ahi se saca el nombre real para el TRUNCATE
   * — truncar con el nombre real nunca falla por diferencia de case.
   */
  SELECT table_name INTO @nombre_real
  FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = nombre_tabla
  LIMIT 1;

  IF @nombre_real IS NOT NULL THEN
    SET @sql = CONCAT('TRUNCATE TABLE `', @nombre_real, '`');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('vaciada: ', @nombre_real) AS resultado;
  ELSE
    SELECT CONCAT('no existe, se saltó: ', nombre_tabla) AS resultado;
  END IF;

  SET @nombre_real = NULL;
END$$
DELIMITER ;

-- --- Inventario: kardex, costos y documentos ---
CALL truncate_si_existe('ConsumosCapa');
CALL truncate_si_existe('CapasCosto');
CALL truncate_si_existe('MovimientosInventario');
CALL truncate_si_existe('DocumentosInventario');

-- --- Compras y cuentas por pagar ---
CALL truncate_si_existe('CompraPago');
CALL truncate_si_existe('CompraDetalle');
CALL truncate_si_existe('Compras');
CALL truncate_si_existe('OrdenCompraDetalle');
CALL truncate_si_existe('OrdenesCompra');

-- --- Ventas, devoluciones y cuentas por cobrar ---
CALL truncate_si_existe('DevolucionDetalles');
CALL truncate_si_existe('Devoluciones');
CALL truncate_si_existe('PagoVenta');
CALL truncate_si_existe('NotaVentaDetalle');
CALL truncate_si_existe('NotasVenta');
CALL truncate_si_existe('PedidoDetalle');
CALL truncate_si_existe('Pedidos');

-- --- Préstamos y despachos ---
CALL truncate_si_existe('PrestamoDetalle');
CALL truncate_si_existe('Prestamos');
CALL truncate_si_existe('DespachoDetalles');
CALL truncate_si_existe('Despachos');

-- --- Caja del día ---
CALL truncate_si_existe('ArqueoGastos');
CALL truncate_si_existe('ArqueoPagosDigitales');
CALL truncate_si_existe('ArqueoCaja');

-- --- Catálogo: productos, presentaciones y listas de precios ---
CALL truncate_si_existe('Precios');
CALL truncate_si_existe('ListasPrecio');
CALL truncate_si_existe('ProductoPresentaciones');
CALL truncate_si_existe('Productos');

DROP PROCEDURE truncate_si_existe;

SET FOREIGN_KEY_CHECKS = 1;

/*
 * Lo que queda en pie, para comprobarlo de un vistazo.
 */
SELECT 'productos' AS catalogo, COUNT(*) AS quedan FROM Productos
UNION ALL SELECT 'presentaciones', COUNT(*) FROM ProductoPresentaciones
UNION ALL SELECT 'precios', COUNT(*) FROM Precios
UNION ALL SELECT 'listasprecio', COUNT(*) FROM ListasPrecio
UNION ALL SELECT 'clientes', COUNT(*) FROM Clientes
UNION ALL SELECT 'proveedores', COUNT(*) FROM Proveedores
UNION ALL SELECT 'almacenes', COUNT(*) FROM Almacenes;
