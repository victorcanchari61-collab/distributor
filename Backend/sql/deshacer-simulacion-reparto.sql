-- ============================================================================
-- DESHACER UNA SIMULACIÓN DE REPARTO (simular-reparto-lunes.sql)
-- ============================================================================
--
-- Borra SOLO lo que creó la simulación de UN lunes: su despacho (con sus rutas y su detalle) y los
-- pedidos con la marca "SIMULACIÓN reparto AAAA-MM-DD", con sus líneas. No toca ningún otro lunes ni
-- ningún pedido que no lleve esa marca.
--
-- ES UN BORRADO DEFINITIVO, así que antes de borrar comprueba que sea seguro y se detiene si no lo es:
--   - el despacho existe, tiene esa fecha de reparto y su observación empieza con "SIMULACIÓN";
--   - todos los pedidos del despacho llevan la marca de ESE lunes (no hay ninguno ajeno colado);
--   - ningún pedido se convirtió en venta (notas de venta) ni tiene novedades de entrega;
--   - todos siguen PENDIENTES.
-- Si algo de eso falla, no borra nada y dice qué pasó.
--
-- NO BORRA NADA POR DEFECTO: con @CONFIRMAR = 0 hace todo dentro de una transacción, MUESTRA lo que
-- borraría y lo deshace. Revisa, y recién entonces cambia @CONFIRMAR a 1.
--
-- Después de borrar, el siguiente pedido y el siguiente despacho retoman el número que dejaron libre
-- (la numeración sigue al último que exista).
--
-- CÓMO CORRERLO (desde la carpeta Backend/sql; en el VPS, con sudo mysql). Haz antes un respaldo:
--
--     sudo mysqldump distributor > /root/respaldo-antes-de-deshacer.sql
--     sudo mysql --default-character-set=utf8mb4 distributor < deshacer-simulacion-reparto.sql
-- ============================================================================

-- ------------------------------ Lo que se puede cambiar ------------------------------
SET @LUNES     = '2026-11-09';   -- el lunes de la simulación que se quiere deshacer (AAAA-MM-DD)
SET @CONFIRMAR = 0;              -- 0 = solo mostrar (se deshace) · 1 = borrar de verdad
-- --------------------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS deshacer_simulacion_reparto;

DELIMITER $$

CREATE PROCEDURE deshacer_simulacion_reparto()
BEGIN
    DECLARE v_lunes    DATE;
    DECLARE v_marca    VARCHAR(60);
    DECLARE v_n_desp   INT;
    DECLARE v_despacho INT;
    DECLARE v_numero   VARCHAR(20);
    DECLARE v_n_ped    INT;
    DECLARE v_n_lin    INT;

    SET v_lunes = CAST(@LUNES AS DATE);
    IF v_lunes IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indica el lunes de la simulación en @LUNES';
    END IF;
    SET v_marca = CONCAT('SIMULACIÓN reparto ', v_lunes);

    -- El despacho: uno solo, de esa fecha, y de una simulación.
    SELECT COUNT(*) INTO v_n_desp FROM Despachos WHERE Fecha = v_lunes AND Observacion LIKE 'SIMULACIÓN%';
    IF v_n_desp = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay un despacho de simulación con esa fecha de reparto';
    END IF;
    IF v_n_desp > 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hay más de un despacho de simulación con esa fecha: revísalos a mano';
    END IF;
    SELECT Id, Numero INTO v_despacho, v_numero
      FROM Despachos WHERE Fecha = v_lunes AND Observacion LIKE 'SIMULACIÓN%' LIMIT 1;

    -- Los pedidos que se borrarían: los del despacho y los que llevan la marca de ese lunes.
    DROP TEMPORARY TABLE IF EXISTS tmp_borrar;
    CREATE TEMPORARY TABLE tmp_borrar (PedidoId INT PRIMARY KEY);
    INSERT IGNORE INTO tmp_borrar (PedidoId) SELECT PedidoId FROM DespachoDetalles WHERE DespachoId = v_despacho;
    INSERT IGNORE INTO tmp_borrar (PedidoId) SELECT Id FROM Pedidos WHERE Observacion LIKE CONCAT(v_marca, '%');

    SELECT COUNT(*) INTO v_n_ped FROM tmp_borrar;

    -- ----- Comprobaciones: nada de lo que se borra puede ser de verdad -----
    IF EXISTS (SELECT 1 FROM Pedidos p JOIN tmp_borrar b ON b.PedidoId = p.Id
                WHERE p.Observacion IS NULL OR p.Observacion NOT LIKE CONCAT(v_marca, '%')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El despacho lleva un pedido que NO es de esa simulación: no se borra nada';
    END IF;
    IF EXISTS (SELECT 1 FROM Pedidos p JOIN tmp_borrar b ON b.PedidoId = p.Id WHERE p.Estado <> 'PENDIENTE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Algún pedido ya no está PENDIENTE: no se borra nada';
    END IF;
    IF EXISTS (SELECT 1 FROM NotasVenta n JOIN tmp_borrar b ON b.PedidoId = n.PedidoId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Algún pedido ya se convirtió en venta: no se borra nada';
    END IF;
    IF EXISTS (SELECT 1 FROM NovedadesEntrega ne WHERE ne.DespachoId = v_despacho)
       OR EXISTS (SELECT 1 FROM NovedadesEntrega ne JOIN tmp_borrar b ON b.PedidoId = ne.PedidoId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hay novedades de entrega registradas en este reparto: no se borra nada';
    END IF;

    SELECT COUNT(*) INTO v_n_lin FROM PedidoDetalle d JOIN tmp_borrar b ON b.PedidoId = d.PedidoId;

    -- ============================ Dentro de una transacción ============================
    START TRANSACTION;

    DELETE FROM DespachoDetalles WHERE DespachoId = v_despacho;
    DELETE FROM DespachoRutas WHERE DespachoId = v_despacho;
    DELETE FROM Despachos WHERE Id = v_despacho;
    DELETE d FROM PedidoDetalle d JOIN tmp_borrar b ON b.PedidoId = d.PedidoId;
    DELETE p FROM Pedidos p JOIN tmp_borrar b ON b.PedidoId = p.Id;

    SELECT IF(@CONFIRMAR = 1, 'SE BORRÓ', 'VISTA PREVIA (se deshace, no se borró nada)') AS Modo,
           v_lunes AS Reparto_lunes, v_numero AS Despacho, v_n_ped AS Pedidos, v_n_lin AS Lineas,
           (SELECT MIN(Numero) FROM Pedidos WHERE Observacion IS NULL OR Observacion NOT LIKE 'SIMULACIÓN%') AS Pedidos_reales_desde,
           (SELECT COUNT(*) FROM Despachos) AS Despachos_que_quedan,
           (SELECT COUNT(*) FROM Pedidos) AS Pedidos_que_quedan;

    IF @CONFIRMAR = 1 THEN
        COMMIT;
        SELECT CONCAT('Listo: se borró el despacho ', v_numero, ' y sus ', v_n_ped, ' pedidos.') AS Resultado;
    ELSE
        ROLLBACK;
        SELECT 'No se borró nada. Si es lo que quieres, cambia @CONFIRMAR a 1 y vuelve a correr el script.' AS Resultado;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_borrar;
END$$

DELIMITER ;

CALL deshacer_simulacion_reparto();
DROP PROCEDURE IF EXISTS deshacer_simulacion_reparto;
