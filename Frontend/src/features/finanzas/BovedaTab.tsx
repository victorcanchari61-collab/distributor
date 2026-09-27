import { useEffect, useState } from 'react'
import { ArrowLeftRight, Landmark, TrendingDown, TrendingUp } from 'lucide-react'
import { Badge, Button, Input, ListPage, Modal, StatCard, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { cuentaFinancieraApi } from './cuentaFinancieraApi'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse } from './cuentaFinancieraApi'
import { MoverPlataModal } from './MoverPlataModal'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const CONCEPTOS: Record<string, string> = {
  SALDO_INICIAL: 'Efectivo inicial',
  CIERRE_CAJA: 'Cierre de caja',
  TRANSFERENCIA_INTERNA: 'Movimiento entre cuentas',
  MOVIMIENTO_OPERATIVO: 'Ingreso o egreso',
  PAGO_COMPRA: 'Pago a proveedor',
  FINANCIAMIENTO: 'Préstamo recibido',
  PAGO_FINANCIAMIENTO: 'Pago de préstamo',
  REVERSION: 'Anulación',
}

/**
 * La Bóveda: el efectivo de la empresa, sin responsable. Aquí llega lo de los
 * cierres de caja y de aquí sale lo que se deposita en el banco o se le da a
 * un repartidor. Solo efectivo.
 */
export function BovedaTab({
  boveda,
  cuentas,
  onCambio,
}: {
  /** Null si todavía no se creó. */
  boveda: CuentaFinancieraResponse | null
  /** Todas las cuentas activas, para mover plata. */
  cuentas: CuentaFinancieraResponse[]
  onCambio: () => void | Promise<void>
}) {
  const { puede } = usePermisos()
  const toast = useToast()
  const [movimientos, setMovimientos] = useState<MovimientoCuentaResponse[]>([])
  const [cargando, setCargando] = useState(false)
  // Por rango, el último mes por defecto: la Bóveda junta movimientos todos los días.
  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())
  const [crearAbierto, setCrearAbierto] = useState(false)
  const [monto, setMonto] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [moverAbierto, setMoverAbierto] = useState(false)

  const bovedaId = boveda?.id
  const saldo = boveda?.saldoActual

  useEffect(() => {
    if (!bovedaId) return
    let vigente = true
    setCargando(true)
    cuentaFinancieraApi
      .movimientos(bovedaId, desde, hasta)
      .then((m) => vigente && setMovimientos(m))
      .catch((e) => toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los movimientos.'))
      .finally(() => vigente && setCargando(false))
    return () => {
      vigente = false
    }
    // El saldo cambia con cada movimiento: al cambiar, se vuelve a pedir la lista.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bovedaId, desde, hasta, saldo])

  const crear = async () => {
    const inicial = monto.trim() ? Number(monto.replace(',', '.')) : 0
    if (!Number.isFinite(inicial) || inicial < 0) return toast.error('El monto inicial no puede ser negativo.')

    setGuardando(true)
    try {
      await cuentaFinancieraApi.crearBoveda(Math.round(inicial * 100) / 100)
      setCrearAbierto(false)
      await onCambio()
      toast.exito('Bóveda creada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos crear la Bóveda.')
    } finally {
      setGuardando(false)
    }
  }

  const ingresos = movimientos.filter((m) => m.tipo === 'INGRESO').reduce((s, m) => s + m.monto, 0)
  const egresos = movimientos.filter((m) => m.tipo === 'EGRESO').reduce((s, m) => s + m.monto, 0)
  const puedeMover = puede('finanzas.movimientos', 'crear') || puede('finanzas.cajas', 'editar')

  const columns: DataTableColumn<MovimientoCuentaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: [
        { value: 'INGRESO', label: 'Entra' },
        { value: 'EGRESO', label: 'Sale' },
      ],
      render: (row) => (
        <Badge tone={row.tipo === 'INGRESO' ? 'success' : 'danger'}>{row.tipo === 'INGRESO' ? 'Entra' : 'Sale'}</Badge>
      ),
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (row.tipo === 'INGRESO' ? `+${soles(row.monto)}` : `-${soles(row.monto)}`),
    },
    { key: 'saldoResultante', label: 'Saldo', align: 'right', filterable: false, render: (row) => soles(row.saldoResultante) },
    {
      key: 'documentoOrigen',
      label: 'Concepto',
      filterType: 'select',
      filterOptions: Object.entries(CONCEPTOS).map(([value, label]) => ({ value, label })),
      render: (row) => CONCEPTOS[row.documentoOrigen] ?? row.documentoOrigen,
    },
    { key: 'observacion', label: 'Detalle', filterable: false, render: (row) => row.observacion ?? '—' },
    { key: 'usuario', label: 'Registró', filterable: false, render: (row) => row.usuario ?? '—' },
  ]

  return (
    <ListPage
      icon={<Landmark size={20} />}
      title="Bóveda"
      description="El efectivo de la empresa: aquí llega lo de los cierres de caja y de aquí sale lo que se deposita o se le da a un repartidor. Solo efectivo."
      actions={
        boveda
          ? puedeMover && (
              <Button size="sm" onClick={() => setMoverAbierto(true)} iconRight={<ArrowLeftRight size={15} />}>
                Mover plata
              </Button>
            )
          : puede('finanzas.cajas', 'crear') && (
              <Button
                size="sm"
                onClick={() => {
                  setMonto('')
                  setCrearAbierto(true)
                }}
                iconRight={<Landmark size={15} />}
              >
                Crear bóveda
              </Button>
            )
      }
      stats={
        boveda ? (
          <>
            <StatCard
              label="En la Bóveda"
              value={soles(boveda.saldoActual)}
              icon={<Landmark size={18} />}
              tono="sys"
              hint="Efectivo guardado ahora"
            />
            <StatCard label="Entró" value={soles(ingresos)} icon={<TrendingUp size={18} />} tono="success" hint="En las fechas de la tabla" />
            <StatCard label="Salió" value={soles(egresos)} icon={<TrendingDown size={18} />} tono="danger" hint="En las fechas de la tabla" />
          </>
        ) : undefined
      }
      columns={columns}
      rows={boveda ? movimientos : []}
      onConsulta={(q) => {
        const fecha = q.filtros.find((f) => f.columna === 'fecha')
        setDesde(fecha?.valor || desplazarDias(-30))
        setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
      }}
      cardIcon={Landmark}
      searchPlaceholder="Buscar por detalle..."
      empty={
        !boveda
          ? 'Todavía no hay Bóveda: créala para que los cierres de caja tengan adónde entregar el efectivo.'
          : cargando
            ? 'Cargando movimientos...'
            : 'No hay movimientos en la Bóveda en estas fechas.'
      }
    >
      <Modal
        open={crearAbierto}
        size="sm"
        title="Crear la Bóveda"
        description="La caja de la empresa: no es de nadie y solo guarda efectivo. Una sola."
        onClose={() => setCrearAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setCrearAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void crear()}>
              Crear bóveda
            </Button>
          </>
        }
      >
        <Input
          label="Efectivo que ya hay"
          optional
          type="number"
          step="0.01"
          placeholder="0.00"
          value={monto}
          onChange={(e) => setMonto(e.target.value)}
        />
      </Modal>

      {moverAbierto && boveda && (
        <MoverPlataModal
          cuentas={cuentas}
          origenInicial={boveda.id}
          onClose={() => setMoverAbierto(false)}
          onHecho={async () => {
            setMoverAbierto(false)
            await onCambio()
            toast.exito('Plata movida')
          }}
        />
      )}
    </ListPage>
  )
}
