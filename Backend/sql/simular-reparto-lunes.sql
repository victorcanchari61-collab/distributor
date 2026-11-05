-- ============================================================================
-- SIMULACIÓN DEL REPARTO DEL LUNES: rutas de Linda y de Braulio
-- ============================================================================
--
-- Simula cómo se trabaja de verdad la semana para el reparto del LUNES:
--
--   VIERNES    Los vendedores toman los pedidos de los clientes que se visitan el LUNES.
--   SÁBADO     Se carga el camión: se arma UN despacho (fecha del reparto = lunes) con las dos rutas.
--              Ese día, antes de cargar, los clientes todavía agregan: suben la cantidad de lo que ya
--              pidieron o piden productos nuevos.
--   LUNES      Se reparte. Con el camión ya cargado hay más aumentos: otra vez más cantidad de lo
--              pedido y productos nuevos.
--
-- SOLO entran clientes con día de visita LUNES, de las rutas que tienen a cargo los dos vendedores
-- (se buscan por NOMBRE, no por id de ruta, porque los ids cambian entre bases).
--
-- LOS PRODUCTOS salen de la LISTA DE PRECIOS con la que se vende a esos clientes (la del cliente o, si no
-- tiene, la predeterminada): solo presentaciones que se venden y que tienen precio cargado. Si la lista trae
-- pocos productos, con @COMPLETAR_CON_PRECIO_REFERENCIA = 1 se suman los que tienen precio de referencia. El precio de
-- cada línea es el de la lista según la cantidad (precio por volumen), y nunca por debajo del costo —
-- el sistema no deja vender así—, para que los pedidos se puedan seguir editando desde la pantalla.
--
-- ES DATA DE PRUEBA. Cada pedido queda con la observación "SIMULACIÓN reparto AAAA-MM-DD" y los aumentos se
-- anotan ahí mismo ("aumento sábado", "aumento lunes"), para encontrarlos y anularlos después. No lo corras
-- en una base con pedidos reales sin saber lo que haces.
--
-- NO TOCA NADA POR DEFECTO: con @CONFIRMAR = 0 hace todo dentro de una transacción, MUESTRA el resultado y
-- lo deshace. Si te gusta, cambia @CONFIRMAR a 1 y vuelve a correrlo.
--
-- NO SE REPITE: si ya se simuló ese lunes (hay pedidos con su marca) o ya hay un despacho de ese lunes con
-- esas rutas, se detiene.
--
-- CÓMO CORRERLO (desde la carpeta Backend/sql; en el VPS, con sudo mysql):
--
--     mysql -u root --default-character-set=utf8mb4 distributor < simular-reparto-lunes.sql
-- ============================================================================

-- ------------------------------ Lo que se puede cambiar ------------------------------
SET @VENDEDOR_A      = 'LINDA';          -- parte del nombre del primer vendedor
SET @VENDEDOR_B      = 'BRAULIO';        -- parte del nombre del segundo
SET @PLACA           = 'CAMION-1';       -- el camión; sale con su conductor habitual
SET @LUNES           = NULL;             -- el lunes del reparto (AAAA-MM-DD). NULL = el lunes de esta semana
SET @POR_MERCADO     = 2;                -- cuántos clientes de cada mercado piden (los primeros que se visitan)
SET @LINEAS_MIN      = 4;                -- productos por pedido: de ... (mínimo)
SET @LINEAS_MAX      = 9;                -- ... a (máximo)
SET @PROB_SABADO     = 0.35;             -- qué parte de los pedidos aumenta el sábado, antes de cargar (0 a 1)
SET @PROB_LUNES      = 0.25;             -- qué parte aumenta el lunes, con el camión ya cargado (0 a 1)
SET @COMPLETAR_CON_PRECIO_REFERENCIA = 0;  -- 0 = SOLO productos que tienen precio en la lista · 1 = además los que
                                            --     solo tienen precio de referencia (como hace el sistema cuando la
                                            --     lista no trae esa presentación). Útil si la lista tiene pocos productos
SET @CONFIRMAR       = 0;                -- 0 = solo mostrar (se deshace) · 1 = dejarlo hecho
-- --------------------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS aumentar_pedidos_simulados;
DROP PROCEDURE IF EXISTS simular_reparto_lunes;

DELIMITER $$

-- Los aumentos de un día: a una parte de los pedidos se les sube la cantidad de un producto que ya
-- tenían, o se les agrega un producto nuevo. El precio de lo que ya estaba no se toca.
CREATE PROCEDURE aumentar_pedidos_simulados(IN p_dia VARCHAR(12), IN p_prob DOUBLE)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_aum;
    DROP TEMPORARY TABLE IF EXISTS tmp_mas;
    DROP TEMPORARY TABLE IF EXISTS tmp_nc;

    -- Qué pedidos aumentan, y de qué manera.
    CREATE TEMPORARY TABLE tmp_aum (PedidoId INT PRIMARY KEY, Tipo VARCHAR(5) NOT NULL);
    INSERT INTO tmp_aum (PedidoId, Tipo)
    SELECT t.PedidoId, IF(RAND() < 0.5, 'MAS', 'NUEVO') FROM tmp_ped t WHERE RAND() < p_prob;

    -- MÁS CANTIDAD: una línea que el pedido ya tenía.
    CREATE TEMPORARY TABLE tmp_mas (
        LineaId INT PRIMARY KEY, PedidoId INT NOT NULL, CantAntes DECIMAL(18,4) NOT NULL,
        Factor DECIMAL(18,4) NOT NULL, Suma INT NOT NULL
    );
    INSERT INTO tmp_mas (LineaId, PedidoId, CantAntes, Factor, Suma)
    SELECT x.Id, x.PedidoId, x.CantidadPresentacion, x.Cantidad / x.CantidadPresentacion, 1 + FLOOR(RAND() * 3)
      FROM (SELECT d.Id, d.PedidoId, d.CantidadPresentacion, d.Cantidad,
                   ROW_NUMBER() OVER (PARTITION BY d.PedidoId ORDER BY RAND()) AS rn
              FROM PedidoDetalle d
              JOIN tmp_aum a ON a.PedidoId = d.PedidoId AND a.Tipo = 'MAS'
             WHERE d.Anulado = 0 AND d.CantidadPresentacion > 0) x
     WHERE x.rn = 1;

    -- Los dos valores salen de lo que había ANTES (CantAntes) y no de la misma fila que se está actualizando:
    -- en un UPDATE con varias tablas el orden de las asignaciones no está garantizado.
    UPDATE PedidoDetalle d
      JOIN tmp_mas m ON m.LineaId = d.Id
       SET d.CantidadPresentacion = m.CantAntes + m.Suma,
           d.Cantidad             = (m.CantAntes + m.Suma) * m.Factor;

    -- PRODUCTO NUEVO: uno de la lista que el pedido todavía no lleva, con el precio de la lista por cantidad.
    CREATE TEMPORARY TABLE tmp_nc (
        PedidoId INT NOT NULL, ListaId INT NOT NULL, PresentacionId INT NOT NULL, ProductoId INT NOT NULL,
        Factor DECIMAL(18,4) NOT NULL, AfectoIgv TINYINT NOT NULL, Costo DECIMAL(18,8) NULL,
        Qty INT NOT NULL, Rnd DOUBLE NOT NULL, Precio DECIMAL(18,4) NULL, PrecioRef DECIMAL(18,4) NULL
    );
    INSERT INTO tmp_nc (PedidoId, ListaId, PresentacionId, ProductoId, Factor, AfectoIgv, Costo, Qty, Rnd, PrecioRef)
    SELECT a.PedidoId, c.ListaPrecioId, c.PresentacionId, c.ProductoId, c.Factor, c.AfectoIgv, c.Costo,
           1 + FLOOR(RAND() * 3), RAND(), c.PrecioRef
      FROM tmp_aum a
      JOIN tmp_ped t ON t.PedidoId = a.PedidoId
      JOIN tmp_catalogo c ON c.ListaPrecioId = t.ListaId
     WHERE a.Tipo = 'NUEVO'
       AND NOT EXISTS (SELECT 1 FROM PedidoDetalle d
                        WHERE d.PedidoId = a.PedidoId AND d.ProductoId = c.ProductoId AND d.Anulado = 0);

    UPDATE tmp_nc n
       SET n.Precio = COALESCE((SELECT pr.Precio FROM Precios pr
                                 WHERE pr.ListaPrecioId = n.ListaId AND pr.PresentacionId = n.PresentacionId
                                   AND pr.Activo = 1 AND pr.CantidadMinima <= n.Qty
                                 ORDER BY pr.CantidadMinima DESC LIMIT 1), n.PrecioRef);
    DELETE FROM tmp_nc
     WHERE Precio IS NULL OR (Costo IS NOT NULL AND Costo > 0 AND Precio < Costo * Factor - 0.0001);

    -- Un producto por pedido, y a veces un segundo (un producto por presentación, no repetido).
    INSERT INTO PedidoDetalle
        (PedidoId, ProductoId, PresentacionId, CantidadPresentacion, Cantidad, PrecioUnitario, Anulado,
         PrecioPresentacion, AfectoIgv)
    SELECT y.PedidoId, y.ProductoId, y.PresentacionId, y.Qty, y.Qty * y.Factor, ROUND(y.Precio / y.Factor, 4), 0,
           y.Precio, y.AfectoIgv
      FROM (SELECT n.*, ROW_NUMBER() OVER (PARTITION BY n.PedidoId ORDER BY n.Rnd) AS rk FROM tmp_nc n) y
     WHERE y.rk = 1 OR (y.rk = 2 AND RAND() < 0.4);

    -- La anotación en el pedido, para poder rastrear qué se aumentó y cuándo.
    UPDATE Pedidos p
      JOIN tmp_aum a ON a.PedidoId = p.Id
       SET p.Observacion = LEFT(CONCAT(COALESCE(p.Observacion, ''), ' · aumento ', LOWER(p_dia),
                                       IF(a.Tipo = 'MAS', ' (más cantidad)', ' (producto nuevo)')), 250);

    INSERT INTO tmp_log (Dia, Tipo, Pedidos)
    SELECT p_dia, a.Tipo, COUNT(*) FROM tmp_aum a GROUP BY a.Tipo;

    DROP TEMPORARY TABLE IF EXISTS tmp_nc;
    DROP TEMPORARY TABLE IF EXISTS tmp_mas;
    DROP TEMPORARY TABLE IF EXISTS tmp_aum;
END$$

CREATE PROCEDURE simular_reparto_lunes()
BEGIN
    DECLARE v_base        DATE;
    DECLARE v_lunes       DATE;
    DECLARE v_viernes     DATE;
    DECLARE v_sabado      DATE;
    DECLARE v_lista_def   INT;
    DECLARE v_vehiculo    INT;
    DECLARE v_conductor   INT;
    DECLARE v_cond_act    TINYINT;
    DECLARE v_ruta_primera INT;
    DECLARE v_n_rutas     INT;
    DECLARE v_n_ped       INT;
    DECLARE v_n_cat       INT;
    DECLARE v_ultimo_ped  VARCHAR(20);
    DECLARE v_n0          INT DEFAULT 0;
    DECLARE v_ultimo_dp   VARCHAR(20);
    DECLARE v_correl_dp   INT DEFAULT 1;
    DECLARE v_numero_dp   VARCHAR(20);
    DECLARE v_despacho    INT;
    DECLARE v_marca       VARCHAR(60);
    DECLARE v_lineas      INT;
    DECLARE v_total       DECIMAL(18,2);
    DECLARE v_productos   INT;
    DECLARE v_rutas_txt   VARCHAR(200);

    -- ------------------------------ Las fechas ------------------------------
    -- Hoy en Perú (cinco horas detrás de UTC). El lunes del reparto es el de esta semana si no se indicó otro.
    SET v_base  = DATE(UTC_TIMESTAMP() - INTERVAL 5 HOUR);
    SET v_lunes = COALESCE(CAST(@LUNES AS DATE), v_base - INTERVAL WEEKDAY(v_base) DAY);

    IF WEEKDAY(v_lunes) <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de @LUNES no cae en lunes';
    END IF;

    SET v_viernes = v_lunes - INTERVAL 3 DAY;   -- se toman los pedidos
    SET v_sabado  = v_lunes - INTERVAL 2 DAY;   -- se carga el camión
    SET v_marca   = CONCAT('SIMULACIÓN reparto ', v_lunes);

    IF @LINEAS_MIN < 1 OR @LINEAS_MAX < @LINEAS_MIN THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Revisa @LINEAS_MIN y @LINEAS_MAX';
    END IF;

    IF EXISTS (SELECT 1 FROM Pedidos WHERE Observacion LIKE CONCAT(v_marca, '%')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya se simuló ese lunes: hay pedidos con su marca de simulación';
    END IF;

    -- ------------------------------ Los vendedores y sus rutas ------------------------------
    IF (SELECT COUNT(*) FROM Usuarios WHERE Activo = 1 AND Nombre LIKE CONCAT('%', @VENDEDOR_A, '%')) <> 1
       OR (SELECT COUNT(*) FROM Usuarios WHERE Activo = 1 AND Nombre LIKE CONCAT('%', @VENDEDOR_B, '%')) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cada vendedor tiene que coincidir con UN solo usuario activo: afina el nombre';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_rutas;
    CREATE TEMPORARY TABLE tmp_rutas (RutaId INT PRIMARY KEY, UsuarioId INT NOT NULL, Orden INT NOT NULL);

    INSERT IGNORE INTO tmp_rutas (RutaId, UsuarioId, Orden)
    SELECT ur.RutaId, u.Id, CASE WHEN u.Nombre LIKE CONCAT('%', @VENDEDOR_A, '%') THEN 1 ELSE 2 END
      FROM UsuarioRutas ur
      JOIN Usuarios u ON u.Id = ur.UsuarioId AND u.Activo = 1
      JOIN Rutas r ON r.Id = ur.RutaId AND r.Activo = 1
     WHERE u.Nombre LIKE CONCAT('%', @VENDEDOR_A, '%') OR u.Nombre LIKE CONCAT('%', @VENDEDOR_B, '%');

    SELECT COUNT(*) INTO v_n_rutas FROM tmp_rutas;
    IF v_n_rutas = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ninguno de los dos vendedores tiene una ruta activa a cargo (Configuración → Usuarios)';
    END IF;
    SELECT RutaId INTO v_ruta_primera FROM tmp_rutas ORDER BY Orden, RutaId LIMIT 1;

    -- El camión y su conductor habitual.
    SELECT Id, ConductorId INTO v_vehiculo, v_conductor FROM Vehiculos WHERE Placa = @PLACA AND Activo = 1 LIMIT 1;
    IF v_vehiculo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay un vehículo activo con esa placa (@PLACA)';
    END IF;
    IF v_conductor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese camión no tiene conductor habitual: asígnalo en Flota';
    END IF;
    SELECT Activo INTO v_cond_act FROM Conductores WHERE Id = v_conductor;
    IF v_cond_act IS NULL OR v_cond_act = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El conductor habitual de ese camión está desactivado';
    END IF;

    IF EXISTS (SELECT 1 FROM Despachos d
                WHERE d.Estado = 'ARMADO' AND d.Fecha = v_lunes
                  AND (SELECT COUNT(*) FROM DespachoRutas dr WHERE dr.DespachoId = d.Id) = v_n_rutas
                  AND (SELECT COUNT(*) FROM DespachoRutas dr WHERE dr.DespachoId = d.Id
                          AND dr.RutaId IN (SELECT RutaId FROM tmp_rutas)) = v_n_rutas) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya hay un despacho armado de ese lunes con esas rutas: no se crea otro';
    END IF;

    -- ------------------------------ Los clientes del lunes ------------------------------
    SELECT Id INTO v_lista_def FROM ListasPrecio WHERE EsPredeterminada = 1 AND Activo = 1 LIMIT 1;
    IF v_lista_def IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay una lista de precios predeterminada: sin ella no hay de dónde sacar los precios';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_ped;
    CREATE TEMPORARY TABLE tmp_ped (
        N INT AUTO_INCREMENT PRIMARY KEY, ClienteId INT NOT NULL, RutaId INT NOT NULL, MercadoId INT NOT NULL,
        UsuarioId INT NOT NULL, ListaId INT NOT NULL, ListaCliente INT NULL, Lineas INT NOT NULL,
        Minutos INT NOT NULL, Cond VARCHAR(10) NOT NULL, PedidoId INT NULL
    );

    -- Solo clientes con día de visita LUNES, de las rutas de los dos vendedores y con mercado: los primeros
    -- @POR_MERCADO de cada mercado, así hay pedidos en todos.
    INSERT INTO tmp_ped (ClienteId, RutaId, MercadoId, UsuarioId, ListaId, ListaCliente, Lineas, Minutos, Cond)
    SELECT x.Id, x.RutaId, x.MercadoId, x.UsuarioId, COALESCE(x.ListaPrecioId, v_lista_def), x.ListaPrecioId,
           @LINEAS_MIN + FLOOR(RAND() * (@LINEAS_MAX - @LINEAS_MIN + 1)),
           8 * 60 + FLOOR(RAND() * 540),                      -- entre las 8:00 y las 17:00
           IF(RAND() < 0.8, 'CONTADO', 'CREDITO')
      FROM (SELECT c.Id, c.RutaId, c.MercadoId, c.ListaPrecioId, r.UsuarioId,
                   ROW_NUMBER() OVER (PARTITION BY c.RutaId, c.MercadoId ORDER BY c.Id) AS rn
              FROM Clientes c
              JOIN tmp_rutas r ON r.RutaId = c.RutaId
             WHERE c.Activo = 1 AND c.DiaVisita = 'LUNES' AND c.MercadoId IS NOT NULL) x
     WHERE x.rn <= @POR_MERCADO
     ORDER BY x.RutaId, x.MercadoId, x.Id;

    SELECT COUNT(*) INTO v_n_ped FROM tmp_ped;
    IF v_n_ped = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esas rutas no tienen clientes con día de visita LUNES y mercado';
    END IF;

    -- ------------------------------ Los productos: los de la lista de precios ------------------------------
    DROP TEMPORARY TABLE IF EXISTS tmp_catalogo;
    CREATE TEMPORARY TABLE tmp_catalogo (
        ListaPrecioId INT NOT NULL, PresentacionId INT NOT NULL, ProductoId INT NOT NULL,
        Factor DECIMAL(18,4) NOT NULL, AfectoIgv TINYINT NOT NULL, Costo DECIMAL(18,8) NULL,
        PrecioRef DECIMAL(18,4) NULL,
        PRIMARY KEY (ListaPrecioId, PresentacionId)
    );
    INSERT INTO tmp_catalogo (ListaPrecioId, PresentacionId, ProductoId, Factor, AfectoIgv, Costo, PrecioRef)
    SELECT DISTINCT pr.ListaPrecioId, pe.Id, p.Id, pe.Factor, p.AfectoIgv, p.CostoReferencia, NULL
      FROM Precios pr
      JOIN ProductoPresentaciones pe ON pe.Id = pr.PresentacionId AND pe.Activo = 1 AND pe.EsVenta = 1
      JOIN Productos p ON p.Id = pe.ProductoId AND p.Activo = 1 AND p.ControlaStock = 1
     WHERE pr.Activo = 1 AND pe.Factor > 0
       AND pr.ListaPrecioId IN (SELECT DISTINCT ListaId FROM tmp_ped);

    -- Opcional: los productos que no están en la lista pero tienen precio de referencia. El sistema los vende a ese
    -- precio (por presentación) cuando la lista no los trae.
    IF @COMPLETAR_CON_PRECIO_REFERENCIA = 1 THEN
        INSERT IGNORE INTO tmp_catalogo (ListaPrecioId, PresentacionId, ProductoId, Factor, AfectoIgv, Costo, PrecioRef)
        SELECT l.ListaId, pe.Id, p.Id, pe.Factor, p.AfectoIgv, p.CostoReferencia, ROUND(p.PrecioReferencia * pe.Factor, 2)
          FROM (SELECT DISTINCT ListaId FROM tmp_ped) l
          JOIN Productos p ON p.Activo = 1 AND p.ControlaStock = 1 AND p.PrecioReferencia > 0
          JOIN ProductoPresentaciones pe ON pe.ProductoId = p.Id AND pe.Activo = 1 AND pe.EsVenta = 1 AND pe.Factor > 0;
    END IF;

    SELECT COUNT(*) INTO v_n_cat FROM tmp_catalogo;
    IF v_n_cat = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de precios de esos clientes no tiene presentaciones vendibles con precio';
    END IF;

    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_log (Dia VARCHAR(12), Tipo VARCHAR(5), Pedidos INT);
    TRUNCATE TABLE tmp_log;

    -- ============================ Todo dentro de una transacción ============================
    START TRANSACTION;

    -- ---------------- VIERNES: se toman los pedidos ----------------
    SELECT Numero INTO v_ultimo_ped FROM Pedidos ORDER BY Id DESC LIMIT 1;
    IF v_ultimo_ped IS NOT NULL THEN
        SET v_n0 = CAST(SUBSTRING_INDEX(v_ultimo_ped, '-', -1) AS UNSIGNED);
    END IF;

    INSERT INTO Pedidos
        (Numero, ClienteId, ListaPrecioId, Fecha, Estado, Observacion, UsuarioId, FechaCreacion, AlmacenId,
         ReservaStock, CondicionPago)
    SELECT CONCAT('PD-', LPAD(v_n0 + t.N, 4, '0')), t.ClienteId, t.ListaCliente,
           v_viernes + INTERVAL t.Minutos MINUTE + INTERVAL 5 HOUR,
           'PENDIENTE', v_marca, t.UsuarioId, v_viernes + INTERVAL t.Minutos MINUTE + INTERVAL 5 HOUR,
           NULL, 0, t.Cond
      FROM tmp_ped t;

    UPDATE tmp_ped t
      JOIN Pedidos p ON p.Numero = CONCAT('PD-', LPAD(v_n0 + t.N, 4, '0'))
       SET t.PedidoId = p.Id;

    -- Las líneas: de cada pedido, algunos productos de la lista (uno por producto), con una cantidad y el precio
    -- de la lista para esa cantidad. Lo que queda bajo el costo no se ofrece.
    DROP TEMPORARY TABLE IF EXISTS tmp_cand;
    CREATE TEMPORARY TABLE tmp_cand (
        PedidoN INT NOT NULL, PedidoId INT NOT NULL, ListaId INT NOT NULL, PresentacionId INT NOT NULL,
        ProductoId INT NOT NULL, Factor DECIMAL(18,4) NOT NULL, AfectoIgv TINYINT NOT NULL,
        Costo DECIMAL(18,8) NULL, Qty INT NOT NULL, Rnd DOUBLE NOT NULL, Precio DECIMAL(18,4) NULL,
        PrecioRef DECIMAL(18,4) NULL
    );
    INSERT INTO tmp_cand (PedidoN, PedidoId, ListaId, PresentacionId, ProductoId, Factor, AfectoIgv, Costo, Qty, Rnd, PrecioRef)
    SELECT y.N, y.PedidoId, y.ListaPrecioId, y.PresentacionId, y.ProductoId, y.Factor, y.AfectoIgv, y.Costo,
           1 + FLOOR(RAND() * 5), RAND(), y.PrecioRef
      FROM (SELECT t.N, t.PedidoId, c.*,
                   ROW_NUMBER() OVER (PARTITION BY t.N, c.ProductoId ORDER BY RAND()) AS rp
              FROM tmp_ped t
              JOIN tmp_catalogo c ON c.ListaPrecioId = t.ListaId) y
     WHERE y.rp = 1;

    UPDATE tmp_cand c
       SET c.Precio = COALESCE((SELECT pr.Precio FROM Precios pr
                                 WHERE pr.ListaPrecioId = c.ListaId AND pr.PresentacionId = c.PresentacionId
                                   AND pr.Activo = 1 AND pr.CantidadMinima <= c.Qty
                                 ORDER BY pr.CantidadMinima DESC LIMIT 1), c.PrecioRef);
    DELETE FROM tmp_cand
     WHERE Precio IS NULL OR (Costo IS NOT NULL AND Costo > 0 AND Precio < Costo * Factor - 0.0001);

    INSERT INTO PedidoDetalle
        (PedidoId, ProductoId, PresentacionId, CantidadPresentacion, Cantidad, PrecioUnitario, Anulado,
         PrecioPresentacion, AfectoIgv)
    SELECT z.PedidoId, z.ProductoId, z.PresentacionId, z.Qty, z.Qty * z.Factor, ROUND(z.Precio / z.Factor, 4), 0,
           z.Precio, z.AfectoIgv
      FROM (SELECT c.*, ROW_NUMBER() OVER (PARTITION BY c.PedidoN ORDER BY c.Rnd) AS rk FROM tmp_cand c) z
      JOIN tmp_ped t ON t.N = z.PedidoN
     WHERE z.rk <= t.Lineas;

    DROP TEMPORARY TABLE IF EXISTS tmp_cand;

    -- Un pedido sin ninguna línea (si la lista casi no tuviera productos sobre el costo) no se deja a medias.
    DELETE p FROM Pedidos p
      JOIN tmp_ped t ON t.PedidoId = p.Id
     WHERE NOT EXISTS (SELECT 1 FROM PedidoDetalle d WHERE d.PedidoId = p.Id);
    DELETE FROM tmp_ped WHERE NOT EXISTS (SELECT 1 FROM Pedidos p WHERE p.Id = tmp_ped.PedidoId);
    SELECT COUNT(*) INTO v_n_ped FROM tmp_ped;

    -- ---------------- SÁBADO: aumentos y se carga el camión ----------------
    CALL aumentar_pedidos_simulados('sábado', @PROB_SABADO);

    SELECT Numero INTO v_ultimo_dp FROM Despachos ORDER BY Id DESC LIMIT 1;
    IF v_ultimo_dp IS NOT NULL THEN
        SET v_correl_dp = CAST(SUBSTRING_INDEX(v_ultimo_dp, '-', -1) AS UNSIGNED) + 1;
    END IF;
    SET v_numero_dp = CONCAT('DP-', LPAD(v_correl_dp, 4, '0'));

    -- Fecha = el día del REPARTO (lunes); se crea el sábado a las 10:30. Los pedidos son los del viernes.
    INSERT INTO Despachos
        (Numero, Fecha, RutaId, VehiculoId, ConductorId, Estado, Observacion, UsuarioId, FechaCreacion,
         PedidosDesde, PedidosHasta, DiaVisita)
    VALUES
        (v_numero_dp, v_lunes, v_ruta_primera, v_vehiculo, v_conductor, 'ARMADO',
         CONCAT('SIMULACIÓN · cargado el sábado ', v_sabado, ' para repartir el lunes'), NULL,
         v_sabado + INTERVAL (10 * 60 + 30) MINUTE + INTERVAL 5 HOUR,
         v_viernes + INTERVAL 5 HOUR, v_sabado + INTERVAL 5 HOUR - INTERVAL 1 SECOND, 'LUNES');
    SET v_despacho = LAST_INSERT_ID();

    INSERT INTO DespachoRutas (DespachoId, RutaId) SELECT v_despacho, RutaId FROM tmp_rutas ORDER BY Orden, RutaId;
    INSERT INTO DespachoDetalles (DespachoId, PedidoId) SELECT v_despacho, PedidoId FROM tmp_ped ORDER BY N;

    -- ---------------- LUNES: con el camión ya cargado, más aumentos ----------------
    CALL aumentar_pedidos_simulados('lunes', @PROB_LUNES);

    -- ============================ Lo que quedó ============================
    -- Cada tabla temporal se lee una sola vez por consulta (MySQL no deja reabrirla): los totales van aparte.
    SELECT COUNT(*), ROUND(SUM(d.CantidadPresentacion * d.PrecioPresentacion), 2), COUNT(DISTINCT d.ProductoId)
      INTO v_lineas, v_total, v_productos
      FROM PedidoDetalle d JOIN tmp_ped t ON t.PedidoId = d.PedidoId WHERE d.Anulado = 0;
    SELECT GROUP_CONCAT(CONCAT('Ruta ', r.Nombre) ORDER BY t.Orden, r.Id SEPARATOR ' + ')
      INTO v_rutas_txt FROM tmp_rutas t JOIN Rutas r ON r.Id = t.RutaId;

    SELECT IF(@CONFIRMAR = 1, 'SE CREÓ', 'VISTA PREVIA (se deshace, no queda nada)') AS Modo,
           v_lunes AS Reparto_lunes, v_viernes AS Pedidos_viernes, v_sabado AS Carga_sabado,
           v_numero_dp AS Despacho, @PLACA AS Camion, v_rutas_txt AS Rutas,
           v_n_ped AS Pedidos, v_lineas AS Lineas, v_total AS Total_soles, v_productos AS Productos_distintos;

    SELECT Dia AS Aumentos_dia, IF(Tipo = 'MAS', 'más cantidad de lo pedido', 'producto nuevo') AS Tipo, Pedidos
      FROM tmp_log ORDER BY FIELD(Dia, 'sábado', 'lunes'), Tipo;

    SELECT r.Nombre AS Ruta, m.Nombre AS Mercado, COUNT(DISTINCT t.PedidoId) AS Pedidos,
           COUNT(d.Id) AS Lineas, ROUND(SUM(d.CantidadPresentacion * d.PrecioPresentacion), 2) AS Total
      FROM tmp_ped t
      JOIN Rutas r ON r.Id = t.RutaId
      JOIN Mercados m ON m.Id = t.MercadoId
      JOIN PedidoDetalle d ON d.PedidoId = t.PedidoId AND d.Anulado = 0
     GROUP BY r.Nombre, m.Nombre, t.RutaId, t.MercadoId
     ORDER BY CAST(r.Nombre AS UNSIGNED), r.Nombre, CAST(m.Nombre AS UNSIGNED), m.Nombre;

    SELECT p.Numero AS Pedido, c.Nombre AS Cliente, c.DiaVisita,
           (SELECT COUNT(*) FROM PedidoDetalle d WHERE d.PedidoId = p.Id AND d.Anulado = 0) AS Lineas,
           (SELECT ROUND(SUM(d.CantidadPresentacion * d.PrecioPresentacion), 2)
              FROM PedidoDetalle d WHERE d.PedidoId = p.Id AND d.Anulado = 0) AS Total,
           SUBSTRING(p.Observacion, CHAR_LENGTH(v_marca) + 1) AS Aumentos
      FROM tmp_ped t JOIN Pedidos p ON p.Id = t.PedidoId JOIN Clientes c ON c.Id = p.ClienteId
     ORDER BY p.Id;

    IF @CONFIRMAR = 1 THEN
        COMMIT;
        SELECT CONCAT('Listo: ', v_n_ped, ' pedidos y el despacho ', v_numero_dp, '. Ábrelo en Despachos.') AS Resultado;
    ELSE
        ROLLBACK;
        SELECT 'No quedó nada. Si te gusta, cambia @CONFIRMAR a 1 y vuelve a correr el script.' AS Resultado;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_log;
    DROP TEMPORARY TABLE IF EXISTS tmp_catalogo;
    DROP TEMPORARY TABLE IF EXISTS tmp_ped;
    DROP TEMPORARY TABLE IF EXISTS tmp_rutas;
END$$

DELIMITER ;

CALL simular_reparto_lunes();
DROP PROCEDURE IF EXISTS simular_reparto_lunes;
DROP PROCEDURE IF EXISTS aumentar_pedidos_simulados;
