/*
 * Vacía el catálogo de productos: productos, sus presentaciones, las listas
 * de precios y los precios cargados en ellas.
 *
 * Se corre DESPUÉS de limpiar-movimiento.sql (o junto), porque un producto no
 * se puede borrar mientras algo lo referencie —compras, ventas, kardex—.
 *
 * Uso:
 *   mysql -u root distributor < Backend/sql/limpiar-movimiento.sql
 *   mysql -u root distributor < Backend/sql/limpiar-catalogo.sql
 *
 * OJO: no se puede deshacer. Es para bases de prueba.
 */

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE precios;
TRUNCATE TABLE listasprecio;
TRUNCATE TABLE productopresentaciones;
TRUNCATE TABLE productos;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'productos' AS catalogo, COUNT(*) AS quedan FROM productos
UNION ALL SELECT 'presentaciones', COUNT(*) FROM productopresentaciones
UNION ALL SELECT 'precios', COUNT(*) FROM precios
UNION ALL SELECT 'listasprecio', COUNT(*) FROM listasprecio;
