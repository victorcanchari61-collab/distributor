/*
 * Deja Finanzas en cero, menos las categorías.
 *
 * Borra todo lo que movió plata: el libro de cajas y bancos, los cierres de
 * caja con su desglose y sus descuentos, los ingresos y egresos, las
 * plantillas recurrentes, los préstamos recibidos, la conciliación bancaria y
 * las planillas semanales (se pagan desde una cuenta).
 *
 * También los cobros de las ventas y los pagos de las compras: son la plata
 * que entró o salió por ellas. Las ventas y compras se conservan y quedan con
 * todo su saldo, por cobrar y por pagar.
 *
 * Los métodos de pago se borran todos menos Efectivo: es fijo, sembrado por el
 * sistema, y sin él no se puede cobrar al contado.
 *
 * Se conservan:
 *   - Las categorías (MotivosGasto).
 *   - Las cuentas —cajas de cada vendedor, bancos, la Bóveda— con saldo 0.
 *   - El método Efectivo y el catálogo de bancos.
 *   - Ventas, compras, pedidos, stock y todo lo demás.
 *
 * Los nombres van en el PascalCase de EF Core: en Linux —como el VPS— MySQL
 * distingue mayúsculas en los nombres de tabla. truncate_si_existe busca el
 * nombre tal cual está guardado y salta las tablas que no existan (una base
 * con migraciones más viejas), en vez de reventar en la primera que falte.
 *
 * Uso:
 *   sudo mysql -u root distributor < Backend/sql/limpiar-finanzas.sql
 *
 * OJO: no se puede deshacer. Es para bases de prueba.
 */

SET FOREIGN_KEY_CHECKS = 0;

DROP PROCEDURE IF EXISTS truncate_si_existe;

DELIMITER $$
CREATE PROCEDURE truncate_si_existe(IN nombre_tabla VARCHAR(128))
BEGIN
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

-- --- Planillas semanales ---
CALL truncate_si_existe('PlanillaDescuentos');
CALL truncate_si_existe('PlanillaDetalles');
CALL truncate_si_existe('PlanillasSemanales');

-- --- Cierres de caja ---
CALL truncate_si_existe('CierreCajaDenominaciones');
CALL truncate_si_existe('DescuentosFaltante');
CALL truncate_si_existe('CierresCaja');

-- --- Cobros de ventas y pagos de compras ---
CALL truncate_si_existe('PagoVenta');
CALL truncate_si_existe('CompraPago');

-- --- Préstamos recibidos ---
CALL truncate_si_existe('PagosFinanciamiento');
CALL truncate_si_existe('Financiamientos');

-- --- Ingresos, egresos y plantillas recurrentes ---
CALL truncate_si_existe('MovimientosOperativos');
CALL truncate_si_existe('GastosRecurrentes');

-- --- Libro de cajas y bancos ---
CALL truncate_si_existe('ConciliacionesBancarias');
CALL truncate_si_existe('MovimientosCuenta');

DROP PROCEDURE truncate_si_existe;

-- Las cuentas se quedan, pero sin plata: su saldo salía de los movimientos.
UPDATE CuentasFinancieras SET SaldoActual = 0;

-- Métodos de pago: solo Efectivo. Los cobros y pagos que los usaban ya se
-- vaciaron arriba, así que no queda nada que los señale.
DELETE FROM MetodosPago WHERE Tipo <> 'EFECTIVO';

SET FOREIGN_KEY_CHECKS = 1;
