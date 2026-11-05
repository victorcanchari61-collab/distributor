-- ============================================================================
-- PEDIDOS DE PRUEBA: uno por mercado en las rutas de Linda y de Braulio
-- ============================================================================
--
-- Para ver un despacho "de verdad" sin tener que cargar pedidos a mano: crea UN pedido pendiente por cada
-- mercado de cada ruta (al primer cliente de ese mercado que se visita el @DIA), con dos productos. Es
-- lo que verías en la Hoja de ruta: cada mercado con por lo menos un pedido.
--
-- Es DATA DE PRUEBA. No lo corras en producción con pedidos reales: crea ventas pendientes que no existen.
-- Cada pedido queda a nombre del vendedor dueño de la ruta, con la observación 'PRUEBA por mercado' para
-- poder encontrarlos y anularlos después.
--
-- Un mercado que ya tiene un pedido pendiente de ese día se salta: no se duplica. Y correrlo dos veces no
-- repite nada por lo mismo.
--
-- Después arma el despacho con despachar-rutas-linda-y-braulio.sql (con @DIA = el mismo día).
--
-- CÓMO CORRERLO (desde la carpeta Backend/sql):
--
--     mysql -u root distributor < sembrar-pedidos-por-mercado.sql
-- ============================================================================

-- ------------------------------ Lo que se puede cambiar ------------------------------
SET @VENDEDOR_A  = 'LINDA';
SET @VENDEDOR_B  = 'BRAULIO';
SET @DIA         = 'LUNES';              -- el día de visita de los clientes a los que se les pone pedido
SET @PRODUCTO_1  = '7442';               -- código de producto (2 unidades de este)
SET @PRODUCTO_2  = '7486';               -- código de producto (1 unidad de este)
SET @CONFIRMAR   = 0;                    -- 0 = solo mostrar · 1 = crear los pedidos
-- --------------------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS sembrar_pedidos_por_mercado;

DELIMITER $$

CREATE PROCEDURE sembrar_pedidos_por_mercado()
BEGIN
    DECLARE v_p1 INT;
    DECLARE v_p2 INT;
    DECLARE v_precio1 DECIMAL(18,4);
    DECLARE v_precio2 DECIMAL(18,4);
    DECLARE v_ultimo INT DEFAULT 0;
    DECLARE v_n INT;

    SELECT Id, COALESCE(PrecioReferencia, 0) INTO v_p1, v_precio1 FROM Productos
     WHERE Codigo = @PRODUCTO_1 AND Activo = 1 AND ControlaStock = 1 LIMIT 1;
    SELECT Id, COALESCE(PrecioReferencia, 0) INTO v_p2, v_precio2 FROM Productos
     WHERE Codigo = @PRODUCTO_2 AND Activo = 1 AND ControlaStock = 1 LIMIT 1;
    IF v_p1 IS NULL OR v_p2 IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No existe (o no controla stock) alguno de los dos productos de prueba';
    END IF;
    IF (SELECT COUNT(*) FROM Usuarios WHERE Activo = 1 AND Nombre LIKE CONCAT('%', @VENDEDOR_A, '%')) <> 1
       OR (SELECT COUNT(*) FROM Usuarios WHERE Activo = 1 AND Nombre LIKE CONCAT('%', @VENDEDOR_B, '%')) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cada vendedor tiene que coincidir con UN solo usuario activo: afina el nombre';
    END IF;

    -- Un cliente por (ruta, mercado): el primero que se visita ese día, y solo si el mercado todavía no tiene pedido pendiente.
    DROP TEMPORARY TABLE IF EXISTS tmp_sembrar;
    CREATE TEMPORARY TABLE tmp_sembrar (
        N INT AUTO_INCREMENT PRIMARY KEY, ClienteId INT NOT NULL, RutaId INT NOT NULL, MercadoId INT NOT NULL, UsuarioId INT NOT NULL
    );

    INSERT INTO tmp_sembrar (ClienteId, RutaId, MercadoId, UsuarioId)
    SELECT MIN(c.Id), c.RutaId, c.MercadoId, ur.UsuarioId
      FROM Clientes c
      JOIN UsuarioRutas ur ON ur.RutaId = c.RutaId
      JOIN Usuarios u ON u.Id = ur.UsuarioId AND u.Activo = 1
       AND (u.Nombre LIKE CONCAT('%', @VENDEDOR_A, '%') OR u.Nombre LIKE CONCAT('%', @VENDEDOR_B, '%'))
     WHERE c.Activo = 1 AND c.DiaVisita = @DIA AND c.MercadoId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Pedidos p JOIN Clientes c2 ON c2.Id = p.ClienteId
                        WHERE p.Estado = 'PENDIENTE' AND c2.RutaId = c.RutaId AND c2.MercadoId = c.MercadoId
                          AND c2.DiaVisita = @DIA)
     GROUP BY c.RutaId, c.MercadoId, ur.UsuarioId
     ORDER BY c.RutaId, c.MercadoId;

    SELECT COUNT(*) INTO v_n FROM tmp_sembrar;

    SELECT IF(@CONFIRMAR = 1, 'SE CREAN', 'VISTA PREVIA (no se creó nada)') AS Modo, v_n AS Pedidos, @DIA AS Dia;
    SELECT r.Nombre AS Ruta, m.Nombre AS Mercado, c.Nombre AS Cliente, u.Nombre AS Vendedor
      FROM tmp_sembrar t
      JOIN Clientes c ON c.Id = t.ClienteId
      JOIN Rutas r ON r.Id = t.RutaId
      JOIN Mercados m ON m.Id = t.MercadoId
      JOIN Usuarios u ON u.Id = t.UsuarioId
     ORDER BY r.Nombre, m.Nombre;

    IF @CONFIRMAR = 1 AND v_n > 0 THEN
        START TRANSACTION;

        -- El correlativo sigue al último pedido, como hace el sistema: PD-0017, PD-0018...
        SELECT COALESCE(MAX(Id), 0) INTO v_ultimo FROM Pedidos;

        INSERT INTO Pedidos
            (Numero, ClienteId, ListaPrecioId, Fecha, Estado, Observacion, UsuarioId, FechaCreacion, AlmacenId,
             ReservaStock, CondicionPago)
        SELECT CONCAT('PD-', LPAD(v_ultimo + t.N, 4, '0')), t.ClienteId, NULL, UTC_TIMESTAMP(6), 'PENDIENTE',
               'PRUEBA por mercado', t.UsuarioId, UTC_TIMESTAMP(6), NULL, 0, 'CONTADO'
          FROM tmp_sembrar t;

        INSERT INTO PedidoDetalle
            (PedidoId, ProductoId, PresentacionId, CantidadPresentacion, Cantidad, PrecioUnitario, Anulado,
             PrecioPresentacion, AfectoIgv)
        SELECT p.Id, v_p1, NULL, 2, 2, v_precio1, 0, v_precio1, (SELECT AfectoIgv FROM Productos WHERE Id = v_p1)
          FROM Pedidos p WHERE p.Observacion = 'PRUEBA por mercado' AND p.Id > v_ultimo;

        INSERT INTO PedidoDetalle
            (PedidoId, ProductoId, PresentacionId, CantidadPresentacion, Cantidad, PrecioUnitario, Anulado,
             PrecioPresentacion, AfectoIgv)
        SELECT p.Id, v_p2, NULL, 1, 1, v_precio2, 0, v_precio2, (SELECT AfectoIgv FROM Productos WHERE Id = v_p2)
          FROM Pedidos p WHERE p.Observacion = 'PRUEBA por mercado' AND p.Id > v_ultimo;

        COMMIT;
        SELECT CONCAT('Listo: se crearon ', v_n, ' pedido(s) de prueba.') AS Resultado;
    ELSE
        SELECT 'No se creó nada. Si todo está bien, cambia @CONFIRMAR a 1 y vuelve a correr el script.' AS Resultado;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_sembrar;
END$$

DELIMITER ;

CALL sembrar_pedidos_por_mercado();
DROP PROCEDURE IF EXISTS sembrar_pedidos_por_mercado;
