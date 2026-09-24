# Diseño: módulo de Finanzas / Tesorería

> Estado: secciones 0, 1, 1.b, 2 y 4 **implementadas de punta a punta (backend
> verificado con harness + frontend) y funcionando**: `CuentaFinanciera` +
> `MovimientoCuenta`, extensión de `ArqueoCaja` con fondo de ruta, corrección
> de `MetodoPago` (Efectivo único/fijo, enlace a Cuenta Financiera), pantalla
> "Bancos" (cuentas + movimientos + conciliación), y "Gastos operativos"
> (pendientes/recurrentes/movimientos). Secciones 3 (Cuentas por pagar) y 5
> (Tesorería) siguen sin diseñar — son las que quedan.

## Por qué hace falta

Hoy el sistema registra "quién pagó qué, con qué etiqueta" por documento
(`PagoVenta`, `CompraPago`, referenciando `MetodoPago`), pero **no existe
ningún libro mayor con saldo real**: ni Caja ni Banco tienen un número que
diga "ahora mismo hay S/ X". `ArqueoCaja` es una foto de reconciliación
(contado físico vs. lo esperado calculado al vuelo), no una cuenta con saldo
persistente. Cuentas por Cobrar/Pagar se calculan al vuelo (total del
documento menos suma de pagos), no hay tabla de "deuda" propia.

## Submódulos a crear/modificar

| Submódulo (permiso) | Estado | Qué hace |
|---|---|---|
| `finanzas.caja` | 🆕 nuevo | La Caja General (única), sus movimientos, transferencias internas. Ver sección 1 — CERRADO |
| `finanzas.bancos` | 🆕 nuevo | Cuentas bancarias, sus movimientos, conciliación contra extracto. Ver sección 2 — CERRADO |
| `finanzas.operativos` | 🆕 nuevo | Ingresos no ligados a venta y egresos operativos, con plantillas recurrentes para lo mensual (alquiler, luz, etc.). Ver sección 4 — CERRADO |
| `finanzas.tesoreria` | 🆕 nuevo | Consolidado de saldos (caja + bancos), proyección de flujo, alertas. Los reportes (aging CxP, flujo histórico) van aquí como pestañas, no como submódulo aparte |
| `finanzas.metodospago` | ✏️ se modifica | Se le agrega el enlace a la cuenta financiera que recibe cada método |
| `finanzas.arqueo` | ✏️ se modifica | Al cerrar, postea el ingreso real a la Caja General (hoy solo calcula la diferencia, no toca ningún saldo) |
| `finanzas.pagar` | ✏️ se modifica | Los pagos empiezan a postear contra saldo real, no solo a quedar como registro informativo |
| `finanzas.cobrar`, `finanzas.miscobros`, `finanzas.ganancias` | sin cambios | No los toca este diseño |

## Decisiones de negocio (actualizado tras cerrar Caja)

> La primera versión de esto asumía una "apertura de caja" con posible saldo
> sin origen. Eso se descartó y luego se corrigió: la apertura real que
> existe es solo el fondo de gastos de ruta (peaje, comida, combustible), no
> una cuenta bancaria del vendedor. Ver sección 1 completa.

- El saldo de la Caja General **es continuo**, no se resetea nunca por un
  cierre de turno — no hay turnos para ella. El dinero vive en el libro mayor
  (`MovimientoCuenta`), igual que ya pasa con inventario (`CapaCosto` /
  `MovimientoInventario`).
- Si alguna vez hace falta inyectar dinero a la Caja General que no viene de
  un arqueo, una transferencia o una venta cobrada directo, se registra como
  `MovimientoOperativo` de tipo `AporteCapital` con descripción obligatoria —
  no como un ajuste de saldo libre.
- El faltante/sobrante de un arqueo **no ajusta el saldo del sistema
  automáticamente** — queda como responsabilidad del usuario
  (`FaltanteSaldado`, ya existente). Un ajuste real requeriría una entrada
  explícita aparte, todavía no diseñada (retomar si hace falta).

---

## 0. Regla transversal: Cuenta Financiera vs. Método de Pago

> Aplica a todos los submódulos de abajo (Caja, Métodos de pago, Bancos). Se
> documenta aparte porque es la raíz de un error fácil de cometer: duplicar
> plata que en realidad es una sola.

**El error a evitar**: si Yape/Plin son solo un reflejo instantáneo de una
cuenta bancaria (sin retención de fondos — la plata que entra por Yape es la
MISMA plata que aparece en el BCP), y le pones "saldo inicial" tanto a la
billetera como a la cuenta bancaria, el sistema termina con S/ 5,000 en el
BCP **más** otro saldo en "Yape" — cuando en la realidad es una sola plata en
un solo banco.

**La distinción que lo resuelve:**

- **Cuenta Financiera** = la entidad que sí tiene saldo real: Caja, Cuenta
  BCP, Cuenta Interbank.
- **Método de Pago** = solo un canal/etiqueta que se usa al registrar una
  venta o un cobro, y que **apunta** a una Cuenta Financiera. No tiene saldo
  propio.

| Método de pago | ¿A qué Cuenta Financiera apunta? |
|---|---|
| Efectivo | Caja General (resuelto según quién cobra, ver sección 1.b) |
| Yape | Cuenta BCP |
| Plin | Cuenta Interbank |
| Tarjeta VISA/Mastercard | Cuenta bancaria de liquidación de la pasarela |
| Transferencia | La cuenta bancaria que se elija al registrar |

Al crear el método de pago "Yape" **no se le pide saldo inicial** — solo a
qué cuenta bancaria está enlazado. El saldo inicial de S/ 5,000 se pone **una
sola vez**, en la Cuenta BCP. Tanto las ventas por Yape como las
transferencias directas al BCP impactan ese mismo saldo.

**Excepción** (queda anotada para cuando se diseñe Bancos): si una pasarela
de pagos SÍ retiene fondos antes de liquidarlos al banco (un saldo "pendiente
de retiro", como Culqi/Niubiz/Mercado Pago suelen hacer), esa pasarela deja
de ser un simple método de pago y pasa a ser su propia `CuentaFinanciera`
(`Naturaleza = PASARELA`) con saldo independiente, con un movimiento de
"transferencia a banco" cuando se liquida — igual que una `TransferenciaInterna`.

---

## 1. Caja — CERRADO

### Historia de cómo se llegó al diseño final (para no repetir el error)

1. Primer intento: Caja por "tipo" (Sucursal/Vendedor/Repartidor/General).
   **Descartado** — no hay sucursales, no aplica.
2. Segundo intento: Caja por usuario, con saldo propio y continuo ("Caja de
   Víctor"). **Descartado** — el vendedor/repartidor NO se queda con el
   dinero: lo entrega al dueño. Modelarlo con saldo propio inventaría plata
   disponible que en realidad sigue en la calle, no en una cuenta de la
   empresa.
3. Diseño final: el vendedor/repartidor no tiene `CuentaFinanciera` propia.
   Tiene una **custodia temporal** de efectivo mientras está en ruta, que se
   salda al liquidar. Y resulta que **eso ya es `ArqueoCaja`**, que ya existe
   en el sistema:
   - `ArqueoService.GetCuadresAsync` ya agrupa los cobros por `{usuario, día}`
     sumando efectivo vs. digital.
   - Ya distingue si el cobro es de una deuda antigua (`EsDeudaAnterior`) o de
     una venta del mismo día — cobrar una cuenta por cobrar vieja y cobrar un
     pedido convertido a venta son, en el sistema, la misma operación: una
     fila `PagoVenta` con `UsuarioId` y `Fecha`.
   - Lo único que falta: al **cerrar** el arqueo, el monto que el
     vendedor/repartidor entrega de verdad (`TotalEfectivoReal`) debe postear
     un `MovimientoCuenta` de Ingreso contra la Caja General. Hoy ese cierre
     calcula la diferencia pero no toca ningún saldo real, porque ese saldo
     real (la Caja General) todavía no existe como cuenta.
   - El faltante/sobrante sigue funcionando exactamente igual que hoy
     (`FaltanteSaldado`): es responsabilidad del usuario, no ajusta el saldo
     del sistema en automático.

### Corrección: sí hay una apertura real, pero es OTRA cosa (no plata de ventas)

Primera vuelta de esto: dije que ya no hacía falta apertura para
vendedor/repartidor. **Incompleto** — mezclé dos flujos de dinero distintos:

1. **Lo que cobran de clientes** (ventas + deudas antiguas) → se entrega
   completo al liquidar. Esto es lo que ya cubre `ArqueoCaja` sin cambios.
2. **El fondo para gastos de ruta** (peaje, comida, pasaje, combustible,
   parqueo) → el dueño se lo entrega **antes de que salga**, aparte de lo que
   cobra. Si no le alcanza o no le dieron nada, se cubre descontando de lo
   cobrado. **Esto sí es una apertura real y trazable** (sale de la Caja
   General en ese momento) y no estaba cubierto por nada existente.

Es **opcional por día**: no todos los días el dueño entrega fondo — puede
quedar en cero y el vendedor/repartidor se cubre solo con lo que cobra.

### Confirmado

- Existe **una sola Caja General** (`CuentaFinanciera`, `Naturaleza = CAJA`),
  sin dueño individual — es la caja de la empresa. Ella no tiene apertura ni
  cierre formal: es una cuenta continua.
- No se crea ninguna `CuentaFinanciera` propia para vendedores ni
  repartidores — su "apertura" y "cierre" del día se resuelven **extendiendo
  `ArqueoCaja`**, no con una cuenta aparte.
- `ArqueoGasto` ya tiene `MotivoGastoId` (catálogo) — ahí caben peaje,
  combustible, comida, pasaje, parqueo sin cambiar su estructura, solo
  agregando los motivos que falten.
- El modelo queda abierto a agregar más cajas reales en el futuro
  (`Naturaleza = CAJA` no es un singleton hardcodeado), aunque hoy solo hace
  falta una.

### Confirmado

- Existe **una sola Caja General** (`CuentaFinanciera`, `Naturaleza = CAJA`),
  sin dueño individual — es la caja de la empresa. No hace falta apertura ni
  cierre formal para ella: es una cuenta continua, los movimientos se postean
  en cualquier momento (ventas al contado cobradas en persona, liquidaciones
  de arqueo, pagos a proveedores, transferencias, aportes).
- No se crea ninguna `CuentaFinanciera` para vendedores ni repartidores.
- El modelo queda abierto a agregar más cajas reales en el futuro
  (`Naturaleza = CAJA` no es un singleton hardcodeado), aunque hoy solo hace
  falta una.

### Modelo final

```
CuentaFinanciera
  Id
  Nombre          -- "Caja General"
  Naturaleza      -- CAJA | BANCO | PASARELA
  SaldoActual     -- cache transaccional, igual que CapaCosto.CantidadDisponible
  Activo
  FechaCreacion

MovimientoCuenta  -- el libro mayor real (ver sección de Bancos/Tesorería para el detalle completo)
  Id, CuentaFinancieraId, Tipo (Ingreso|Egreso), Monto, SaldoResultante, Fecha,
  DocumentoOrigen, OrigenId, UsuarioId

ArqueoCaja (existente, SE EXTIENDE — no se reemplaza)
  ... campos actuales sin cambios ...
  + MontoApertura        -- decimal, default 0. Lo que el dueño entregó para gastos de ruta ese día (opcional)
  + MovimientoAperturaId? -- FK a MovimientoCuenta: el Egreso posteado en Caja General al entregar el fondo (null si MontoApertura=0)
  + MovimientoCierreId?   -- FK a MovimientoCuenta: el Ingreso posteado en Caja General al liquidar
```

Cálculo de cierre (cambia de `Cobros − Gastos` a):

```
EfectivoEsperado = MontoApertura + EfectivoSistema(cobros del día) − Σ Gastos
Diferencia       = TotalEfectivoReal (contado físico) − EfectivoEsperado   -- Faltante/Sobrante, igual que hoy
```

Flujo:
1. **Apertura (opcional)**: el dueño entrega S/ X a Víctor para gastos de
   ruta → se crea/encuentra el `ArqueoCaja` de ese usuario/día, se fija
   `MontoApertura`, se postea el Egreso en Caja General.
2. **Durante el día**: `ArqueoGasto` y `PagoVenta` se registran igual que
   hoy, sin cambios — da igual si el gasto salió del fondo o de lo cobrado,
   es un solo bolsillo.
3. **Cierre (`RegistrarAsync`, ya existe)**: se agrega `MontoApertura` a la
   fórmula, y al guardar se postea el Ingreso a Caja General por
   `TotalEfectivoReal` (lo que Víctor entrega de verdad, incluido cualquier
   remanente del fondo).

---

## 1.b Métodos de pago — ajuste encontrado al revisar

### Confirmado

- **`EFECTIVO` es único y estático.** Ya existe sembrado (`MetodoPago.Id=1,
  Nombre="Efectivo"`), pero hoy nada lo protege: se puede crear otro método
  con `Tipo=EFECTIVO`, y el registro sembrado se puede editar o desactivar
  como cualquier otro. Encaja con lo ya definido: el efectivo no apunta a una
  cuenta fija (se resuelve según la caja/arqueo de quien cobra), así que no
  tiene sentido que exista más de una instancia ni que cambie.
- Reglas a aplicar en `FinanzasService`:
  - **Crear**: rechazar si `Tipo=EFECTIVO` y ya existe uno (`ConflictException`).
  - **Editar/Eliminar/Desactivar**: rechazar sobre el registro con
    `Tipo=EFECTIVO` — es fijo, no se toca.
  - Billetera digital y Transferencia siguen siendo un catálogo normal
    (crear/editar/desactivar libremente), porque cada una sí representa una
    cuenta concreta distinta.

_(Este es un ajuste puntual sobre `finanzas.metodospago`, ya listado como "se
modifica" en la tabla de submódulos — no es un submódulo nuevo.)_

---

## 2. Bancos — CERRADO

### Confirmado

- Solo soles (PEN) — no hace falta modelar multi-moneda.
- Conciliación **por saldo total a una fecha de corte**, no línea por línea
  (más simple, cubre el caso real).
- No hay tablas nuevas para "cuenta bancaria" ni "movimiento bancario": son
  la misma `CuentaFinanciera` (con `Naturaleza = BANCO`) y el mismo
  `MovimientoCuenta` que ya se definieron en la sección 0/1. Los campos
  `Banco`/`NumeroCuenta`/`Cci`/`Titular` se mudan de `MetodoPago` a
  `CuentaFinanciera` (aplican cuando `Naturaleza = BANCO` o `PASARELA`).

### Cuándo se postea un movimiento a una cuenta bancaria

- Venta cobrada por Yape/Plin/transferencia/tarjeta → Ingreso **directo**, sin
  custodia ni arqueo de por medio (a diferencia del efectivo).
- Pago a proveedor por transferencia → Egreso.
- Depósito/retiro entre Caja General y el banco → `TransferenciaInterna`
  (dos movimientos, mismo mecanismo ya definido).
- Planilla, alquiler, aportes de capital por banco → `MovimientoOperativo`
  (submódulo 4).

### Modelo

```
ConciliacionBancaria
  Id
  CuentaFinancieraId
  Fecha             -- fecha de corte del extracto
  SaldoExtracto     -- lo que dice el banco
  SaldoContable     -- snapshot del sistema A ESA FECHA (ver nota abajo)
  Diferencia
  Observacion
  Estado            -- PENDIENTE | CONCILIADO
  UsuarioId
  FechaCreacion
```

> **Ojo al implementar**: `CuentaFinanciera.SaldoActual` es el saldo de HOY.
> `SaldoContable` de una conciliación NO es ese campo a secas — hay que
> reconstruirlo buscando el `MovimientoCuenta` más reciente con
> `Fecha ≤ Fecha de corte` y tomar su `SaldoResultante`. Usar `SaldoActual`
> directamente da mal la diferencia en cuanto exista un movimiento posterior
> a la fecha del extracto ya cargado en el sistema.

La diferencia **no ajusta el saldo del sistema automáticamente** (mismo
principio que en Caja) — queda registrada para investigar (comisión no
registrada, cheque no cobrado, etc.).

## 3. Cuentas por pagar

_Ya existe (cálculo al vuelo). Cambio de fondo: los pagos deben postear un
`MovimientoCuenta` real contra la cuenta elegida. Detalle pendiente de
retomar._

## 4. Ingresos y egresos operativos — CERRADO

### Confirmado

- Luz, agua, internet, alquiler son **egresos operativos** — no son deuda a
  un proveedor de mercadería, no van a Cuentas por Pagar.
- Se manejan con **plantilla recurrente**: se definen una vez (nombre,
  categoría, monto estimado, día de vencimiento del mes) y el sistema las
  recuerda cada mes, en vez de registrarlas sueltas cada vez. Esto además es
  lo que le da datos a las alertas de vencimiento y a la proyección de
  Tesorería (submódulo 5) — sin esto, esa proyección no tiene nada que
  anticipar.
- Reutiliza el catálogo `MotivoGasto` que ya existe (hoy solo lo usa
  `ArqueoGasto` para gastos de ruta) — ya es genérico, no hace falta un
  catálogo de categorías aparte.
- Los ingresos (préstamos recibidos, aportes de capital) **no** llevan
  plantilla recurrente — son eventos puntuales, se registran sueltos.

### Modelo

```
GastoRecurrente
  Id
  Nombre                    -- "Alquiler local", "Internet oficina"
  MotivoGastoId             -- reutiliza el catálogo existente
  MontoEstimado             -- referencia; el monto real puede variar (ej. luz)
  DiaVencimiento            -- 1-31, día del mes en que vence
  CuentaFinancieraSugeridaId? -- de qué cuenta suele salir, para pre-llenar
  Activo
  FechaCreacion

MovimientoOperativo
  Id
  CuentaFinancieraId
  Tipo                      -- INGRESO | EGRESO
  MotivoGastoId
  Monto                     -- el real, puede diferir del estimado de la plantilla
  Fecha
  Descripcion
  GastoRecurrenteId?        -- si nació de una plantilla (null si es un ingreso o un gasto suelto)
  UsuarioId
```

### Cómo se calcula "qué está pendiente" (sin generar una fila por mes)

No se crea una fila nueva cada mes para cada `GastoRecurrente` — eso
ensuciaría la tabla con filas "pendientes" que después hay que borrar o
actualizar. En su lugar, Tesorería calcula al vuelo, para cada
`GastoRecurrente` activo:

1. Próxima fecha de vencimiento = día `DiaVencimiento` del mes actual (o del
   próximo, si ya pasó).
2. ¿Existe ya un `MovimientoOperativo` con ese `GastoRecurrenteId` fechado
   este mes/año? Si no existe y ya pasó la fecha → alerta de vencido. Si no
   existe y falta poco → aparece como "por vencer". Si ya existe → ya está
   cubierto, no se muestra.

### Flujo de pago

1. Desde la lista de pendientes (Tesorería), se elige "Pagar" sobre un
   `GastoRecurrente` vencido o por vencer.
2. Se pre-llena categoría, cuenta sugerida y monto estimado — el usuario solo
   confirma o corrige el monto real y la fecha real.
3. Se crea el `MovimientoOperativo` (Egreso), enlazado a esa plantilla, y se
   postea el `MovimientoCuenta` correspondiente contra la cuenta elegida.

## 5. Tesorería / Flujo de caja

_No iniciado._
