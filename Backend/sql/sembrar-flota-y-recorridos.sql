-- ============================================================================
-- Flota y recorrido semanal de los camiones (el mapa del sistema anterior)
-- ============================================================================
--
-- Carga los 3 camiones y qué rutas hace cada uno cada día, para que al armar un
-- despacho (vehículo + día de visita) las rutas se propongan solas:
--
--   Camión 1   lunes 1,7 · martes 5,7 · miércoles 5 · jueves 1,7 · viernes 6,7 · sábado 7,8
--   Camión 2   lunes 3,6 · martes 1,3 · miércoles 1,3 · jueves 3,6 · viernes 3,5 · sábado 3,6
--   Camión 3   miércoles 6,7 · viernes 2,8 · sábado 1,5
--
-- También crea el conductor habitual de cada camión y se lo deja asignado: al armar un
-- despacho, elegir el camión propone su conductor.
--
-- QUÉ NO HACE: no crea rutas ni mercados (se asume que producción ya los tiene, con
-- las rutas llamadas 1 … 8), ni usuarios, ni pedidos. Las rutas se buscan por NOMBRE,
-- no por id, porque los ids pueden ser distintos en producción.
--
-- SE PUEDE CORRER VARIAS VECES: si el camión ya existe (misma placa) no lo duplica, si el
-- conductor ya existe (mismo documento) tampoco, y un día/ruta que ya está en el
-- recorrido se deja como está. Un camión que ya tiene conductor no se le cambia.
--
-- ANTES DE CORRERLO
--   1. Aplicar las migraciones (DespachoVariasRutas crea la tabla del recorrido).
--   2. Poner abajo las PLACAS REALES y los CONDUCTORES REALES (nombre y DNI). Mientras no
--      se pongan, quedan con datos provisorios que se corrigen después en TMS → Flota y
--      TMS → Conductores. El DNI no se puede repetir entre conductores.
--
-- CÓMO CORRERLO (en el servidor):
--   sudo mysql -u root distributor < Backend/sql/sembrar-flota-y-recorridos.sql
-- ============================================================================

-- ---- Poner aquí las placas reales ------------------------------------------
SET @placa1 = 'CAMION-1';
SET @placa2 = 'CAMION-2';
SET @placa3 = 'CAMION-3';

-- El conductor habitual de cada camión: nombre y documento (DNI). Provisorios hasta que se pongan los reales.
SET @conductor1_nombre = 'Conductor Camión 1';  SET @conductor1_doc = 'PROV-0001';
SET @conductor2_nombre = 'Conductor Camión 2';  SET @conductor2_doc = 'PROV-0002';
SET @conductor3_nombre = 'Conductor Camión 3';  SET @conductor3_doc = 'PROV-0003';
-- -----------------------------------------------------------------------------

-- Falla a la vista si faltan las tablas: mejor eso que un error a medias.
SELECT COUNT(*) AS tabla_de_recorridos_existe FROM RecorridosVehiculo;

-- El tipo de vehículo. Si ya hay uno llamado Camión se reutiliza.
INSERT INTO TiposVehiculo (Nombre, Descripcion, CapacidadKgReferencia, Activo, FechaCreacion)
SELECT 'Camión', 'Camión de reparto', 5000, 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM TiposVehiculo WHERE Nombre = 'Camión');

SET @tipo = (SELECT Id FROM TiposVehiculo WHERE Nombre = 'Camión' ORDER BY Id LIMIT 1);

-- Los tres camiones, solo si no existen ya con esa placa.
INSERT INTO Vehiculos (Placa, TipoVehiculoId, Observacion, Activo, FechaCreacion)
SELECT @placa1, @tipo, 'Camión 1', 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM Vehiculos WHERE Placa = @placa1);

INSERT INTO Vehiculos (Placa, TipoVehiculoId, Observacion, Activo, FechaCreacion)
SELECT @placa2, @tipo, 'Camión 2', 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM Vehiculos WHERE Placa = @placa2);

INSERT INTO Vehiculos (Placa, TipoVehiculoId, Observacion, Activo, FechaCreacion)
SELECT @placa3, @tipo, 'Camión 3', 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM Vehiculos WHERE Placa = @placa3);

-- Los conductores, solo si no existen ya con ese documento.
INSERT INTO Conductores (Nombre, Documento, Activo, FechaCreacion)
SELECT @conductor1_nombre, @conductor1_doc, 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM Conductores WHERE Documento = @conductor1_doc);

INSERT INTO Conductores (Nombre, Documento, Activo, FechaCreacion)
SELECT @conductor2_nombre, @conductor2_doc, 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM Conductores WHERE Documento = @conductor2_doc);

INSERT INTO Conductores (Nombre, Documento, Activo, FechaCreacion)
SELECT @conductor3_nombre, @conductor3_doc, 1, UTC_TIMESTAMP(6)
WHERE NOT EXISTS (SELECT 1 FROM Conductores WHERE Documento = @conductor3_doc);

-- Cada camión queda con su conductor habitual, salvo que ya tenga uno.
UPDATE Vehiculos SET ConductorId = (SELECT Id FROM Conductores WHERE Documento = @conductor1_doc)
WHERE Placa = @placa1 AND ConductorId IS NULL;
UPDATE Vehiculos SET ConductorId = (SELECT Id FROM Conductores WHERE Documento = @conductor2_doc)
WHERE Placa = @placa2 AND ConductorId IS NULL;
UPDATE Vehiculos SET ConductorId = (SELECT Id FROM Conductores WHERE Documento = @conductor3_doc)
WHERE Placa = @placa3 AND ConductorId IS NULL;

-- El mapa camión → día → ruta, escrito con los NOMBRES de las rutas.
DROP TEMPORARY TABLE IF EXISTS mapa_recorrido;
CREATE TEMPORARY TABLE mapa_recorrido (camion INT NOT NULL, dia VARCHAR(12) NOT NULL, ruta VARCHAR(60) NOT NULL);

INSERT INTO mapa_recorrido (camion, dia, ruta) VALUES
  (1, 'LUNES', '1'),     (1, 'LUNES', '7'),
  (1, 'MARTES', '5'),    (1, 'MARTES', '7'),
  (1, 'MIERCOLES', '5'),
  (1, 'JUEVES', '1'),    (1, 'JUEVES', '7'),
  (1, 'VIERNES', '6'),   (1, 'VIERNES', '7'),
  (1, 'SABADO', '7'),    (1, 'SABADO', '8'),

  (2, 'LUNES', '3'),     (2, 'LUNES', '6'),
  (2, 'MARTES', '1'),    (2, 'MARTES', '3'),
  (2, 'MIERCOLES', '1'), (2, 'MIERCOLES', '3'),
  (2, 'JUEVES', '6'),    (2, 'JUEVES', '3'),
  (2, 'VIERNES', '3'),   (2, 'VIERNES', '5'),
  (2, 'SABADO', '3'),    (2, 'SABADO', '6'),

  (3, 'MIERCOLES', '6'), (3, 'MIERCOLES', '7'),
  (3, 'VIERNES', '8'),   (3, 'VIERNES', '2'),
  (3, 'SABADO', '1'),    (3, 'SABADO', '5');

-- El recorrido. INSERT IGNORE + el índice único (vehículo, día, ruta) hacen que correrlo dos veces no duplique.
INSERT IGNORE INTO RecorridosVehiculo (VehiculoId, Dia, RutaId)
SELECT v.Id, m.dia, r.Id
FROM mapa_recorrido m
JOIN Vehiculos v ON v.Placa = CASE m.camion WHEN 1 THEN @placa1 WHEN 2 THEN @placa2 ELSE @placa3 END
JOIN Rutas r ON r.Nombre = m.ruta;

-- ---- Comprobación -----------------------------------------------------------

-- Rutas del mapa que NO existen en esta base: si sale alguna fila, ese día quedó sin esa ruta.
SELECT DISTINCT m.ruta AS ruta_que_no_existe_en_esta_base
FROM mapa_recorrido m
LEFT JOIN Rutas r ON r.Nombre = m.ruta
WHERE r.Id IS NULL;

-- Cada camión con su conductor.
SELECT v.Placa, c.Nombre AS conductor, c.Documento
FROM Vehiculos v
LEFT JOIN Conductores c ON c.Id = v.ConductorId
WHERE v.Placa IN (@placa1, @placa2, @placa3)
ORDER BY v.Placa;

-- Cómo quedó cada camión.
SELECT v.Placa,
       rv.Dia,
       GROUP_CONCAT(r.Nombre ORDER BY CAST(r.Nombre AS UNSIGNED) SEPARATOR ' y ') AS rutas
FROM RecorridosVehiculo rv
JOIN Vehiculos v ON v.Id = rv.VehiculoId
JOIN Rutas r ON r.Id = rv.RutaId
WHERE v.Placa IN (@placa1, @placa2, @placa3)
GROUP BY v.Placa, rv.Dia
ORDER BY v.Placa, FIELD(rv.Dia, 'LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO');

DROP TEMPORARY TABLE IF EXISTS mapa_recorrido;
