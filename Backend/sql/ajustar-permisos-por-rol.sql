-- ============================================================================
-- AJUSTAR LOS PERMISOS DE 4 ROLES: Almacenero, Vendedor, REPARTIDOR y CHOFER
-- ============================================================================
--
-- Deja cada uno de esos cuatro roles con EXACTAMENTE los permisos que se definieron según lo que hace en el
-- negocio (listados abajo). Es un REEMPLAZO: lo que el rol tenga y no esté en la lista se quita, y lo que falte
-- se agrega. Los demás roles (Administrador, TESORERIA, BODEGUERO...) no se tocan.
--
-- LA LÓGICA, en una línea por rol:
--   ALMACENERO  maneja el almacén: stock, recepciones, transferencias, ajustes, conteos, préstamos, y carga el
--               camión. Nadie firma por encima de él (no hay supervisor), así que también confirma lo suyo:
--               préstamos, devoluciones que vuelven y recojos. Pide compras con solicitudes (solo las suyas).
--   VENDEDOR    toma pedidos y vende a SUS clientes (sus rutas), hace su seguimiento y sus visitas. Sin permisos de
--               almacén: pedir mercadería no es mover el stock.
--   REPARTIDOR  entrega lo que lleva el despacho, cobra y cierra su caja. Es quien confirma la entrega.
--   CHOFER      solo maneja: ve el despacho (la hoja de carga), las rutas y los mercados. Nada más.
--
-- No se da "confirmar" de solicitudes de compra, cierres de caja ni órdenes: eso es de administración.
--
-- NO TOCA NADA POR DEFECTO: con @CONFIRMAR = 0 hace todo dentro de una transacción, MUESTRA qué se agrega y qué
-- se quita a cada rol, y lo deshace. Revísalo, y recién entonces cambia @CONFIRMAR a 1.
--
-- Se aplica por NOMBRE de rol (no por Id), así sirve igual en producción. Si un rol no existe, lo avisa y sigue.
-- Es idempotente: correrlo dos veces deja lo mismo. Los permisos se leen del servidor con un tiempo de espera de
-- 30 segundos; quien ya tenía la sesión abierta debe recargar la página o volver a entrar para ver el cambio.
--
-- CÓMO CORRERLO (desde la carpeta Backend/sql; en el VPS, con sudo mysql). Haz antes un respaldo:
--
--     sudo mysqldump distributor > /root/respaldo-antes-de-permisos.sql
--     sudo mysql --default-character-set=utf8mb4 distributor < ajustar-permisos-por-rol.sql
-- ============================================================================

SET @CONFIRMAR = 0;      -- 0 = solo mostrar (se deshace) · 1 = aplicar

DROP PROCEDURE IF EXISTS ajustar_permisos_por_rol;

DELIMITER $$

CREATE PROCEDURE ajustar_permisos_por_rol()
BEGIN
    DECLARE v_agregan INT DEFAULT 0;
    DECLARE v_quitan  INT DEFAULT 0;

    DROP TEMPORARY TABLE IF EXISTS tmp_deseado;
    DROP TEMPORARY TABLE IF EXISTS tmp_alcance;
    DROP TEMPORARY TABLE IF EXISTS tmp_roles;
    DROP TEMPORARY TABLE IF EXISTS tmp_actual;
    DROP TEMPORARY TABLE IF EXISTS tmp_diff;

    CREATE TEMPORARY TABLE tmp_deseado (Rol VARCHAR(60) NOT NULL, Submodulo VARCHAR(60) NOT NULL, Accion VARCHAR(30) NOT NULL);
    CREATE TEMPORARY TABLE tmp_alcance (Rol VARCHAR(60) NOT NULL, Submodulo VARCHAR(60) NOT NULL, Alcance VARCHAR(20) NOT NULL);

    -- ----------------------------------------------------------------------------------------------------
    -- ALMACENERO
    -- ----------------------------------------------------------------------------------------------------
    INSERT INTO tmp_deseado (Rol, Submodulo, Accion) VALUES
        ('Almacenero', 'dashboard.inventario', 'ver'),
        ('Almacenero', 'maestros.productos', 'ver'),
        ('Almacenero', 'maestros.proveedores', 'ver'),
        ('Almacenero', 'inv.almacenes', 'ver'),
        ('Almacenero', 'inv.ubicaciones', 'ver'), ('Almacenero', 'inv.ubicaciones', 'editar'),
        ('Almacenero', 'inv.stock', 'ver'), ('Almacenero', 'inv.stock', 'exportar'),
        ('Almacenero', 'inv.kardex', 'ver'), ('Almacenero', 'inv.kardex', 'exportar'),
        ('Almacenero', 'inv.lotes', 'ver'), ('Almacenero', 'inv.lotes', 'exportar'),
        ('Almacenero', 'inv.ajustes', 'ver'), ('Almacenero', 'inv.ajustes', 'crear'), ('Almacenero', 'inv.ajustes', 'editar'),
        ('Almacenero', 'inv.ajustes', 'exportar'),
        ('Almacenero', 'inv.transferencias', 'ver'), ('Almacenero', 'inv.transferencias', 'crear'),
        ('Almacenero', 'inv.transferencias', 'editar'), ('Almacenero', 'inv.transferencias', 'anular'),
        ('Almacenero', 'inv.transferencias', 'exportar'),
        ('Almacenero', 'inv.conteos', 'ver'), ('Almacenero', 'inv.conteos', 'crear'), ('Almacenero', 'inv.conteos', 'editar'),
        ('Almacenero', 'inv.prestamos', 'ver'), ('Almacenero', 'inv.prestamos', 'crear'),
        ('Almacenero', 'inv.prestamos', 'editar'), ('Almacenero', 'inv.prestamos', 'confirmar'),
        ('Almacenero', 'inv.prestamos', 'exportar'),
        ('Almacenero', 'compras.recepciones', 'ver'), ('Almacenero', 'compras.recepciones', 'crear'),
        ('Almacenero', 'compras.recepciones', 'editar'), ('Almacenero', 'compras.recepciones', 'exportar'),
        ('Almacenero', 'compras.ordenes', 'ver'),
        ('Almacenero', 'compras.solicitudes', 'ver'), ('Almacenero', 'compras.solicitudes', 'crear'),
        ('Almacenero', 'compras.solicitudes', 'editar'), ('Almacenero', 'compras.solicitudes', 'anular'),
        ('Almacenero', 'tms.despachos', 'ver'), ('Almacenero', 'tms.despachos', 'exportar'),
        ('Almacenero', 'tms.novedades', 'ver'), ('Almacenero', 'tms.novedades', 'confirmar'),
        ('Almacenero', 'dms.devoluciones', 'ver'), ('Almacenero', 'dms.devoluciones', 'confirmar'),
        ('Almacenero', 'fact.pedidos', 'ver');
    -- Solo ve las solicitudes de compra que él pidió.
    INSERT INTO tmp_alcance (Rol, Submodulo, Alcance) VALUES ('Almacenero', 'compras.solicitudes', 'propios');

    -- ----------------------------------------------------------------------------------------------------
    -- VENDEDOR
    -- ----------------------------------------------------------------------------------------------------
    INSERT INTO tmp_deseado (Rol, Submodulo, Accion) VALUES
        ('Vendedor', 'fact.pedidos', 'ver'), ('Vendedor', 'fact.pedidos', 'crear'), ('Vendedor', 'fact.pedidos', 'editar'),
        ('Vendedor', 'fact.pedidos', 'anular'), ('Vendedor', 'fact.pedidos', 'exportar'),
        ('Vendedor', 'fact.notaventa', 'ver'), ('Vendedor', 'fact.notaventa', 'crear'), ('Vendedor', 'fact.notaventa', 'editar'),
        ('Vendedor', 'fact.notaventa', 'exportar'),
        ('Vendedor', 'fact.precios', 'ver'),
        ('Vendedor', 'fact.facturas', 'ver'), ('Vendedor', 'fact.boletas', 'ver'),
        ('Vendedor', 'fact.notascredito', 'ver'), ('Vendedor', 'fact.notasdebito', 'ver'),
        ('Vendedor', 'finanzas.caja', 'ver'), ('Vendedor', 'finanzas.caja', 'ingreso'), ('Vendedor', 'finanzas.caja', 'egreso'),
        ('Vendedor', 'finanzas.cierres', 'ver'),
        ('Vendedor', 'finanzas.cobrar', 'ver'), ('Vendedor', 'finanzas.cobrar', 'cobrar'),
        ('Vendedor', 'finanzas.ganancias', 'ver'),
        ('Vendedor', 'inv.stock', 'ver'),
        -- Lo que le faltaba para su trabajo:
        ('Vendedor', 'maestros.clientes', 'ver'), ('Vendedor', 'maestros.clientes', 'crear'), ('Vendedor', 'maestros.clientes', 'editar'),
        ('Vendedor', 'maestros.catalogo', 'ver'),
        ('Vendedor', 'dms.visitas', 'ver'),
        ('Vendedor', 'crm.seguimiento', 'ver'), ('Vendedor', 'crm.seguimiento', 'crear'), ('Vendedor', 'crm.seguimiento', 'editar'),
        ('Vendedor', 'crm.caida', 'ver');
    INSERT INTO tmp_alcance (Rol, Submodulo, Alcance) VALUES
        ('Vendedor', 'fact.pedidos', 'misclientes'),
        ('Vendedor', 'fact.notaventa', 'misclientes'),
        ('Vendedor', 'maestros.clientes', 'misclientes'),
        ('Vendedor', 'finanzas.ganancias', 'misclientes'),
        ('Vendedor', 'crm.seguimiento', 'misclientes'),
        ('Vendedor', 'finanzas.cierres', 'propios');

    -- ----------------------------------------------------------------------------------------------------
    -- REPARTIDOR
    -- ----------------------------------------------------------------------------------------------------
    INSERT INTO tmp_deseado (Rol, Submodulo, Accion) VALUES
        ('REPARTIDOR', 'dashboard.reparto', 'ver'),
        ('REPARTIDOR', 'tms.despachos', 'ver'), ('REPARTIDOR', 'tms.despachos', 'exportar'),
        ('REPARTIDOR', 'fact.pedidos', 'ver'), ('REPARTIDOR', 'fact.pedidos', 'confirmar'),
        ('REPARTIDOR', 'fact.notaventa', 'ver'), ('REPARTIDOR', 'fact.notaventa', 'crear'), ('REPARTIDOR', 'fact.notaventa', 'cobrar'),
        ('REPARTIDOR', 'fact.notaventa', 'exportar'),
        ('REPARTIDOR', 'finanzas.cobrar', 'ver'), ('REPARTIDOR', 'finanzas.cobrar', 'cobrar'),
        ('REPARTIDOR', 'finanzas.metodospago', 'ver'),
        ('REPARTIDOR', 'dms.devoluciones', 'ver'),
        ('REPARTIDOR', 'finanzas.caja', 'ver'), ('REPARTIDOR', 'finanzas.caja', 'egreso'),
        ('REPARTIDOR', 'finanzas.cierres', 'ver');
    -- Su cierre de caja es solo el suyo. Pedidos y ventas quedan en "todos" a propósito: un despacho mezcla clientes de
    -- varias rutas que no son suyas, y con "mis clientes" no vería su propia carga.
    INSERT INTO tmp_alcance (Rol, Submodulo, Alcance) VALUES ('REPARTIDOR', 'finanzas.cierres', 'propios');

    -- ----------------------------------------------------------------------------------------------------
    -- CHOFER: solo maneja
    -- ----------------------------------------------------------------------------------------------------
    INSERT INTO tmp_deseado (Rol, Submodulo, Accion) VALUES
        ('CHOFER', 'tms.despachos', 'ver'), ('CHOFER', 'tms.despachos', 'exportar'),
        ('CHOFER', 'tms.rutas', 'ver'),
        ('CHOFER', 'tms.mercados', 'ver');

    -- ----------------------------------------------------------------------------------------------------
    -- Los roles que existen de verdad (por nombre).
    -- ----------------------------------------------------------------------------------------------------
    CREATE TEMPORARY TABLE tmp_roles (Rol VARCHAR(60) NOT NULL, RolId INT NULL);
    INSERT INTO tmp_roles (Rol, RolId)
    SELECT n.Rol, (SELECT r.Id FROM Roles r WHERE r.Nombre = n.Rol LIMIT 1)
      FROM (SELECT DISTINCT Rol FROM tmp_deseado) n;

    SELECT CONCAT('El rol ', Rol, ' no existe en esta base: se salta') AS Aviso FROM tmp_roles WHERE RolId IS NULL;

    START TRANSACTION;

    -- Lo que tienen hoy, para mostrar la diferencia antes de cambiar.
    CREATE TEMPORARY TABLE tmp_actual (Rol VARCHAR(60) NOT NULL, Submodulo VARCHAR(60) NOT NULL, Accion VARCHAR(30) NOT NULL);
    INSERT INTO tmp_actual (Rol, Submodulo, Accion)
    SELECT t.Rol, p.Submodulo, p.Accion FROM RolPermisos p JOIN tmp_roles t ON t.RolId = p.RolId;

    -- ----- Se quita lo que sobra y se agrega lo que falta -----
    DELETE p FROM RolPermisos p
      JOIN tmp_roles t ON t.RolId = p.RolId
     WHERE NOT EXISTS (SELECT 1 FROM tmp_deseado d WHERE d.Rol = t.Rol AND d.Submodulo = p.Submodulo AND d.Accion = p.Accion);

    INSERT INTO RolPermisos (RolId, Submodulo, Accion)
    SELECT t.RolId, d.Submodulo, d.Accion
      FROM tmp_deseado d JOIN tmp_roles t ON t.Rol = d.Rol AND t.RolId IS NOT NULL
     WHERE NOT EXISTS (SELECT 1 FROM RolPermisos p
                        WHERE p.RolId = t.RolId AND p.Submodulo = d.Submodulo AND p.Accion = d.Accion);

    -- ----- Alcances: los de estos roles quedan como se definió -----
    DELETE a FROM RolAlcances a
      JOIN tmp_roles t ON t.RolId = a.RolId
     WHERE NOT EXISTS (SELECT 1 FROM tmp_alcance x WHERE x.Rol = t.Rol AND x.Submodulo = a.Submodulo AND x.Alcance = a.Alcance);

    INSERT INTO RolAlcances (RolId, Submodulo, Alcance)
    SELECT t.RolId, x.Submodulo, x.Alcance
      FROM tmp_alcance x JOIN tmp_roles t ON t.Rol = x.Rol AND t.RolId IS NOT NULL
     WHERE NOT EXISTS (SELECT 1 FROM RolAlcances a WHERE a.RolId = t.RolId AND a.Submodulo = x.Submodulo);

    -- ============================ Lo que cambió ============================
    CREATE TEMPORARY TABLE tmp_diff (Rol VARCHAR(60), Cambio VARCHAR(10), Submodulo VARCHAR(60), Accion VARCHAR(30));

    INSERT INTO tmp_diff
    SELECT d.Rol, 'SE AGREGA', d.Submodulo, d.Accion FROM tmp_deseado d
     WHERE EXISTS (SELECT 1 FROM tmp_roles t WHERE t.Rol = d.Rol AND t.RolId IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM tmp_actual a WHERE a.Rol = d.Rol AND a.Submodulo = d.Submodulo AND a.Accion = d.Accion);

    INSERT INTO tmp_diff
    SELECT a.Rol, 'SE QUITA', a.Submodulo, a.Accion FROM tmp_actual a
     WHERE NOT EXISTS (SELECT 1 FROM tmp_deseado d WHERE d.Rol = a.Rol AND d.Submodulo = a.Submodulo AND d.Accion = a.Accion);

    -- MySQL no deja leer una tabla temporal dos veces en la misma consulta: los conteos van aparte.
    SELECT COUNT(*) INTO v_agregan FROM tmp_diff WHERE Cambio = 'SE AGREGA';
    SELECT COUNT(*) INTO v_quitan FROM tmp_diff WHERE Cambio = 'SE QUITA';

    SELECT IF(@CONFIRMAR = 1, 'SE APLICÓ', 'VISTA PREVIA (se deshace, no se cambió nada)') AS Modo,
           v_agregan AS Permisos_que_se_agregan, v_quitan AS Permisos_que_se_quitan;

    SELECT Rol, Cambio, Submodulo, GROUP_CONCAT(Accion ORDER BY Accion SEPARATOR ', ') AS Acciones
      FROM tmp_diff
     GROUP BY Rol, Cambio, Submodulo
     ORDER BY Rol, Cambio DESC, Submodulo;

    SELECT t.Rol, (SELECT COUNT(*) FROM RolPermisos p WHERE p.RolId = t.RolId) AS Permisos_que_quedan,
           (SELECT GROUP_CONCAT(CONCAT(a.Submodulo, '=', a.Alcance) ORDER BY a.Submodulo SEPARATOR ' · ')
              FROM RolAlcances a WHERE a.RolId = t.RolId) AS Alcances
      FROM tmp_roles t WHERE t.RolId IS NOT NULL ORDER BY t.Rol;

    IF @CONFIRMAR = 1 THEN
        COMMIT;
        SELECT 'Listo. Quien tenga la sesión abierta debe recargar la página o volver a entrar.' AS Resultado;
    ELSE
        ROLLBACK;
        SELECT 'No se cambió nada. Si te gusta, cambia @CONFIRMAR a 1 y vuelve a correr el script.' AS Resultado;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_diff;
    DROP TEMPORARY TABLE IF EXISTS tmp_actual;
    DROP TEMPORARY TABLE IF EXISTS tmp_roles;
    DROP TEMPORARY TABLE IF EXISTS tmp_alcance;
    DROP TEMPORARY TABLE IF EXISTS tmp_deseado;
END$$

DELIMITER ;

CALL ajustar_permisos_por_rol();
DROP PROCEDURE IF EXISTS ajustar_permisos_por_rol;
