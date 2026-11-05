-- ============================================================================
-- UN SOLO DESPACHO para las rutas de Linda y de Braulio
-- ============================================================================
--
-- Arma UN despacho (el mismo camión, el mismo reparto) con las rutas de los dos vendedores y todos
-- sus pedidos pendientes. Es lo que haría la pantalla Despachos al elegir las dos rutas a la vez (el
-- sistema anterior lo hacía así: el lunes del camión 1 es la ruta 1 y la 7).
--
-- QUÉ ES "LA RUTA DE" ELLOS: las rutas que cada uno tiene a cargo en Configuración → Usuarios. Se
-- buscan por NOMBRE del vendedor (@VENDEDOR_A, @VENDEDOR_B), no por id de ruta, porque los ids pueden
-- ser distintos en producción. Cada nombre tiene que coincidir con UN solo usuario activo; si no, el
-- script se detiene y lo dice.
--
-- QUÉ ENTRA: los pedidos PENDIENTES de los clientes de esas rutas que todavía no viajan en otro
-- despacho armado. Mismas reglas que la pantalla.
--
-- EL DÍA DE VISITA: por defecto NO se filtra (@DIA = NULL), porque los clientes de cada ruta se visitan
-- en días distintos y con el filtro uno de los dos vendedores quedaría sin pedidos. Para llevar solo
-- los clientes de un día, pon por ejemplo @DIA = 'LUNES'.
--
-- NO TOCA NADA POR DEFECTO: con @CONFIRMAR = 0 solo MUESTRA lo que haría (rutas, camión, conductor y la
-- lista de pedidos). Revísalo y recién entonces cambia @CONFIRMAR a 1 y vuelve a correrlo.
--
-- NO SE DUPLICA: si ya hay un despacho armado de ese día con exactamente esas rutas, se detiene.
--
-- CÓMO CORRERLO (desde la carpeta Backend/sql; en el VPS, con sudo mysql):
--
--     mysql -u root distributor < despachar-rutas-linda-y-braulio.sql
--
-- No hace falta reiniciar nada. Un despacho no mueve stock ni dinero: es solo "qué se carga hoy".
-- ============================================================================

-- ------------------------------ Lo que se puede cambiar ------------------------------
SET @VENDEDOR_A  = 'LINDA';              -- parte del nombre del primer vendedor
SET @VENDEDOR_B  = 'BRAULIO';            -- parte del nombre del segundo
SET @PLACA       = 'CAMION-1';           -- el camión; sale con su conductor habitual
SET @FECHA       = NULL;                 -- el día del reparto (AAAA-MM-DD). NULL = hoy (hora de Perú)
SET @DIA         = 'LUNES';              -- día de visita (LUNES ... SABADO). NULL = todos los días
SET @OBSERVACION = 'Rutas de Linda y Braulio en un solo despacho';
SET @CONFIRMAR   = 0;                    -- 0 = solo mostrar · 1 = crear el despacho

-- ------------------------- Ajustes a los pedidos (opcional) --------------------------
-- Para AUMENTAR lo que lleva un pedido antes de salir: sumar un producto nuevo o subir la cantidad
-- de uno que el cliente ya había pedido. Una fila por cambio; vacío = no se toca ningún pedido.
--
--   Pedido        el número del pedido (PD-0015). Tiene que ser uno de los que entran al despacho.
--   Codigo        el código del producto.
--   PresentacionId  NULL = la misma presentación de la línea que ya tiene el pedido (si es producto
--                 nuevo, la unidad base). Un Id = esa presentación (Id de ProductoPresentaciones).
--   Cantidad      cuánto SE SUMA, en esa presentación (3 = tres más). Siempre positivo.
--   Precio        precio por presentación. En una línea que ya existe, NULL conserva el precio que ya
--                 tenía; en un producto nuevo es OBLIGATORIO (los pedidos se cotizan a mano).
--
--   Si el pedido ya tiene ese producto, SE SUMA a su línea (no se duplica); si no, se agrega una línea.
--
-- Ejemplos (quita los dos guiones y cambia los datos):
--   INSERT INTO tmp_ajustes (Pedido, Codigo, PresentacionId, Cantidad, Precio) VALUES
--       ('PD-0015', '7678', NULL, 2, NULL),        -- 2 bolsas más de lo que ya pidió
--       ('PD-0016', '7655', NULL, 1, 17.50);       -- 1 más de ese producto, o línea nueva a 17.50
DROP TEMPORARY TABLE IF EXISTS tmp_ajustes;
CREATE TEMPORARY TABLE tmp_ajustes (
    Id             INT AUTO_INCREMENT PRIMARY KEY,
    Pedido         VARCHAR(20)   NOT NULL,
    Codigo         VARCHAR(30)   NOT NULL,
    PresentacionId INT           NULL,
    Cantidad       DECIMAL(18,4) NOT NULL,
    Precio         DECIMAL(18,4) NULL
);
-- INSERT INTO tmp_ajustes (Pedido, Codigo, PresentacionId, Cantidad, Precio) VALUES
--     ('PD-0015', '7678', NULL, 2, NULL);
-- --------------------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS despachar_rutas_de_vendedores;

DELIMITER $$

CREATE PROCEDURE despachar_rutas_de_vendedores()
BEGIN
    DECLARE v_fecha         DATETIME;
    DECLARE v_dia           VARCHAR(12);
    DECLARE v_vehiculo      INT;
    DECLARE v_conductor     INT;
    DECLARE v_conductor_act TINYINT;
    DECLARE v_ruta_primera  INT;
    DECLARE v_n_rutas       INT;
    DECLARE v_n_pedidos     INT;
    DECLARE v_numero        VARCHAR(20);
    DECLARE v_ultimo        VARCHAR(20);
    DECLARE v_correlativo   INT DEFAULT 1;
    DECLARE v_despacho      INT;
    DECLARE v_existente     VARCHAR(20);
    DECLARE v_coinciden_a   INT;
    DECLARE v_coinciden_b   INT;
    DECLARE v_n_ajustes     INT DEFAULT 0;

    -- El día del reparto: hoy en Perú (cinco horas detrás de UTC) si no se indicó otro.
    SET v_fecha = COALESCE(CAST(@FECHA AS DATETIME), DATE(UTC_TIMESTAMP() - INTERVAL 5 HOUR));
    SET v_dia   = NULLIF(UPPER(TRIM(@DIA)), '');

    IF v_dia IS NOT NULL AND v_dia NOT IN ('LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El día de visita no es válido: usa LUNES, MARTES, MIERCOLES, JUEVES, VIERNES o SABADO';
    END IF;

    -- Cada nombre tiene que ser UN usuario activo: con cero no hay a quién buscarle la ruta, y con
    -- dos no se sabe cuál es.
    SELECT COUNT(*) INTO v_coinciden_a FROM Usuarios
     WHERE Activo = 1 AND Nombre LIKE CONCAT('%', @VENDEDOR_A, '%');
    SELECT COUNT(*) INTO v_coinciden_b FROM Usuarios
     WHERE Activo = 1 AND Nombre LIKE CONCAT('%', @VENDEDOR_B, '%');

    IF v_coinciden_a <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El primer vendedor (@VENDEDOR_A) no coincide con UN solo usuario activo: afina el nombre';
    END IF;
    IF v_coinciden_b <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El segundo vendedor (@VENDEDOR_B) no coincide con UN solo usuario activo: afina el nombre';
    END IF;

    -- Las rutas que cada uno tiene a cargo.
    DROP TEMPORARY TABLE IF EXISTS tmp_rutas;
    CREATE TEMPORARY TABLE tmp_rutas (RutaId INT PRIMARY KEY, Orden INT NOT NULL);

    INSERT IGNORE INTO tmp_rutas (RutaId, Orden)
    SELECT ur.RutaId,
           CASE WHEN u.Nombre LIKE CONCAT('%', @VENDEDOR_A, '%') THEN 1 ELSE 2 END
      FROM UsuarioRutas ur
      JOIN Usuarios u ON u.Id = ur.UsuarioId
      JOIN Rutas r ON r.Id = ur.RutaId
     WHERE u.Activo = 1 AND r.Activo = 1
       AND (u.Nombre LIKE CONCAT('%', @VENDEDOR_A, '%') OR u.Nombre LIKE CONCAT('%', @VENDEDOR_B, '%'));

    SELECT COUNT(*) INTO v_n_rutas FROM tmp_rutas;
    IF v_n_rutas = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ninguno de los dos vendedores tiene una ruta activa a cargo (Configuración → Usuarios)';
    END IF;

    -- La primera ruta es la del primer vendedor: es la que se guarda como "ruta" del despacho.
    SELECT RutaId INTO v_ruta_primera FROM tmp_rutas ORDER BY Orden, RutaId LIMIT 1;

    -- El camión y su conductor habitual.
    SELECT Id, ConductorId INTO v_vehiculo, v_conductor
      FROM Vehiculos WHERE Placa = @PLACA AND Activo = 1 LIMIT 1;
    IF v_vehiculo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay un vehículo activo con esa placa (@PLACA)';
    END IF;
    IF v_conductor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese camión no tiene conductor habitual: asígnalo en Flota';
    END IF;
    SELECT Activo INTO v_conductor_act FROM Conductores WHERE Id = v_conductor;
    IF v_conductor_act IS NULL OR v_conductor_act = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El conductor habitual de ese camión está desactivado';
    END IF;

    -- Ya hay uno igual: mismo día y exactamente las mismas rutas.
    SELECT d.Numero INTO v_existente
      FROM Despachos d
     WHERE d.Estado = 'ARMADO' AND d.Fecha = v_fecha
       AND (SELECT COUNT(*) FROM DespachoRutas dr WHERE dr.DespachoId = d.Id) = v_n_rutas
       AND (SELECT COUNT(*) FROM DespachoRutas dr WHERE dr.DespachoId = d.Id
               AND dr.RutaId IN (SELECT RutaId FROM tmp_rutas)) = v_n_rutas
     LIMIT 1;
    IF v_existente IS NOT NULL THEN
        SET @mensaje = CONCAT('Ya existe el despacho ', v_existente, ' de ese día con esas mismas rutas: no se crea otro');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @mensaje;
    END IF;

    -- Los pedidos que entran: pendientes, de clientes de esas rutas, que no viajan ya en otro despacho armado.
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos;
    CREATE TEMPORARY TABLE tmp_pedidos (PedidoId INT PRIMARY KEY);

    INSERT INTO tmp_pedidos (PedidoId)
    SELECT p.Id
      FROM Pedidos p
      JOIN Clientes c ON c.Id = p.ClienteId
     WHERE p.Estado = 'PENDIENTE'
       AND c.RutaId IN (SELECT RutaId FROM tmp_rutas)
       AND (v_dia IS NULL OR c.DiaVisita = v_dia)
       AND p.Id NOT IN (SELECT dd.PedidoId
                          FROM DespachoDetalles dd
                          JOIN Despachos d ON d.Id = dd.DespachoId
                         WHERE d.Estado = 'ARMADO');

    SELECT COUNT(*) INTO v_n_pedidos FROM tmp_pedidos;
    IF v_n_pedidos = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay pedidos pendientes en esas rutas (con ese día de visita) para despachar';
    END IF;

    -- ------------------------------ Ajustes a los pedidos ------------------------------
    DROP TEMPORARY TABLE IF EXISTS tmp_plan;
    CREATE TEMPORARY TABLE tmp_plan (
        AjusteId INT PRIMARY KEY, PedidoId INT NOT NULL, Pedido VARCHAR(20) NOT NULL,
        ProductoId INT NOT NULL, Producto VARCHAR(150) NOT NULL, AfectoIgv TINYINT NOT NULL,
        LineaId INT NULL, PresentacionId INT NULL, Factor DECIMAL(18,4) NOT NULL,
        CantAntes DECIMAL(18,4) NOT NULL, Suma DECIMAL(18,4) NOT NULL, Precio DECIMAL(18,4) NULL
    );

    SELECT COUNT(*) INTO v_n_ajustes FROM tmp_ajustes;
    IF v_n_ajustes > 0 THEN
        IF EXISTS (SELECT 1 FROM tmp_ajustes WHERE Cantidad <= 0) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajustes: la cantidad a sumar tiene que ser mayor que cero';
        END IF;
        IF EXISTS (SELECT 1 FROM tmp_ajustes a
                    WHERE NOT EXISTS (SELECT 1 FROM Pedidos p JOIN tmp_pedidos t ON t.PedidoId = p.Id WHERE p.Numero = a.Pedido)) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajustes: un pedido no existe, no está pendiente o no entra a este despacho';
        END IF;
        IF EXISTS (SELECT 1 FROM tmp_ajustes a WHERE NOT EXISTS (SELECT 1 FROM Productos pr WHERE pr.Codigo = a.Codigo AND pr.Activo = 1)) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajustes: un código de producto no existe o está desactivado';
        END IF;
        IF EXISTS (SELECT 1 FROM tmp_ajustes GROUP BY Pedido, Codigo HAVING COUNT(*) > 1) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajustes: hay un producto repetido en el mismo pedido: junta las cantidades en una sola fila';
        END IF;

        INSERT INTO tmp_plan (AjusteId, PedidoId, Pedido, ProductoId, Producto, AfectoIgv, LineaId, PresentacionId,
                              Factor, CantAntes, Suma, Precio)
        SELECT a.Id, p.Id, p.Numero, pr.Id, pr.Nombre, pr.AfectoIgv, l.Id,
               CASE WHEN l.Id IS NOT NULL THEN l.PresentacionId ELSE a.PresentacionId END,
               CASE WHEN l.Id IS NOT NULL THEN l.Cantidad / l.CantidadPresentacion
                    ELSE COALESCE(pe.Factor, 1) END,
               COALESCE(l.CantidadPresentacion, 0), a.Cantidad, a.Precio
          FROM tmp_ajustes a
          JOIN Pedidos p ON p.Numero = a.Pedido
          JOIN Productos pr ON pr.Codigo = a.Codigo
          LEFT JOIN PedidoDetalle l ON l.Id = (
                SELECT d.Id FROM PedidoDetalle d
                 WHERE d.PedidoId = p.Id AND d.ProductoId = pr.Id AND d.Anulado = 0
                   AND (a.PresentacionId IS NULL OR d.PresentacionId <=> a.PresentacionId)
                 ORDER BY d.Id LIMIT 1)
          LEFT JOIN ProductoPresentaciones pe ON pe.Id = a.PresentacionId;

        IF EXISTS (SELECT 1 FROM tmp_ajustes a JOIN Productos pr ON pr.Codigo = a.Codigo
                    WHERE a.PresentacionId IS NOT NULL
                      AND NOT EXISTS (SELECT 1 FROM ProductoPresentaciones pe
                                       WHERE pe.Id = a.PresentacionId AND pe.ProductoId = pr.Id
                                         AND pe.Activo = 1 AND pe.EsVenta = 1)) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajustes: la presentación no es de ese producto, está desactivada o no se vende';
        END IF;
        IF EXISTS (SELECT 1 FROM tmp_plan WHERE LineaId IS NULL AND Precio IS NULL) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ajustes: un producto NUEVO en el pedido necesita su Precio';
        END IF;
    END IF;

    -- El número que sigue: DP-0001, DP-0002... a partir del último despacho.
    SELECT Numero INTO v_ultimo FROM Despachos ORDER BY Id DESC LIMIT 1;
    IF v_ultimo IS NOT NULL THEN
        SET v_correlativo = CAST(SUBSTRING_INDEX(v_ultimo, '-', -1) AS UNSIGNED) + 1;
    END IF;
    SET v_numero = CONCAT('DP-', LPAD(v_correlativo, 4, '0'));

    -- ------------------------------ Lo que se va a hacer ------------------------------
    SELECT IF(@CONFIRMAR = 1, 'SE CREA', 'VISTA PREVIA (no se creó nada)') AS Modo,
           v_numero AS Numero,
           DATE(v_fecha) AS Fecha,
           COALESCE(v_dia, '(todos los días)') AS DiaVisita,
           (SELECT Placa FROM Vehiculos WHERE Id = v_vehiculo) AS Camion,
           (SELECT Nombre FROM Conductores WHERE Id = v_conductor) AS Conductor,
           (SELECT GROUP_CONCAT(CONCAT('Ruta ', r.Nombre) ORDER BY t.Orden, r.Id SEPARATOR ' + ')
              FROM tmp_rutas t JOIN Rutas r ON r.Id = t.RutaId) AS Rutas,
           v_n_pedidos AS Pedidos;

    SELECT p.Numero AS Pedido, c.Nombre AS Cliente, r.Nombre AS Ruta, c.DiaVisita, p.Fecha AS FechaPedido
      FROM tmp_pedidos t
      JOIN Pedidos p ON p.Id = t.PedidoId
      JOIN Clientes c ON c.Id = p.ClienteId
      JOIN Rutas r ON r.Id = c.RutaId
     ORDER BY r.Nombre, c.Nombre, p.Fecha;

    IF v_n_ajustes > 0 THEN
        SELECT t.Pedido, t.Producto,
               IF(t.LineaId IS NULL, 'LÍNEA NUEVA', 'SUBE LA CANTIDAD') AS Cambio,
               t.CantAntes AS Antes, t.CantAntes + t.Suma AS Despues,
               COALESCE(t.Precio, l.PrecioPresentacion) AS PrecioPresentacion
          FROM tmp_plan t LEFT JOIN PedidoDetalle l ON l.Id = t.LineaId
         ORDER BY t.Pedido, t.Producto;
    END IF;

    -- ------------------------------ Crearlo ------------------------------
    IF @CONFIRMAR = 1 THEN
        START TRANSACTION;

        -- Primero los pedidos: suben las cantidades que ya existían...
        UPDATE PedidoDetalle l
          JOIN tmp_plan t ON t.LineaId = l.Id
           SET l.CantidadPresentacion = l.CantidadPresentacion + t.Suma,
               l.Cantidad             = (t.CantAntes + t.Suma) * t.Factor,
               l.PrecioPresentacion   = COALESCE(t.Precio, l.PrecioPresentacion),
               l.PrecioUnitario       = ROUND(COALESCE(t.Precio, l.PrecioPresentacion) / t.Factor, 4);

        -- ...y entran los productos que el pedido no tenía.
        INSERT INTO PedidoDetalle
            (PedidoId, ProductoId, PresentacionId, CantidadPresentacion, Cantidad, PrecioUnitario, Anulado,
             PrecioPresentacion, AfectoIgv)
        SELECT t.PedidoId, t.ProductoId, t.PresentacionId, t.Suma, t.Suma * t.Factor,
               ROUND(t.Precio / t.Factor, 4), 0, t.Precio, t.AfectoIgv
          FROM tmp_plan t WHERE t.LineaId IS NULL;

        INSERT INTO Despachos
            (Numero, Fecha, RutaId, VehiculoId, ConductorId, Estado, Observacion, UsuarioId, FechaCreacion,
             PedidosDesde, PedidosHasta, DiaVisita)
        VALUES
            (v_numero, v_fecha, v_ruta_primera, v_vehiculo, v_conductor, 'ARMADO', LEFT(@OBSERVACION, 250), NULL,
             UTC_TIMESTAMP(6), NULL, NULL, v_dia);
        SET v_despacho = LAST_INSERT_ID();

        INSERT INTO DespachoRutas (DespachoId, RutaId)
        SELECT v_despacho, RutaId FROM tmp_rutas ORDER BY Orden, RutaId;

        INSERT INTO DespachoDetalles (DespachoId, PedidoId)
        SELECT v_despacho, PedidoId FROM tmp_pedidos ORDER BY PedidoId;

        COMMIT;

        SELECT CONCAT('Listo: se creó el despacho ', v_numero, ' con ', v_n_pedidos,
                      ' pedido(s). Ábrelo en Despachos.') AS Resultado;
    ELSE
        SELECT 'No se creó nada. Si todo está bien, cambia @CONFIRMAR a 1 y vuelve a correr el script.' AS Resultado;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_plan;
    DROP TEMPORARY TABLE IF EXISTS tmp_pedidos;
    DROP TEMPORARY TABLE IF EXISTS tmp_rutas;
END$$

DELIMITER ;

CALL despachar_rutas_de_vendedores();
DROP PROCEDURE IF EXISTS despachar_rutas_de_vendedores;
DROP TEMPORARY TABLE IF EXISTS tmp_ajustes;
