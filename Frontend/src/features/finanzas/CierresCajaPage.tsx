import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, Ban, ClipboardCheck, UserX } from 'lucide-react'
import { Alert, Badge, ListPage, RowAction, StatCard, useConfirmacion, useToast } from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { cierreCajaApi } from './cierreCajaApi'
import type { CierreCajaResponse } from './cierreCajaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

type Resultado = 'FALTANTE' | 'SOBRANTE' | 'CUADRO'

const resultadoDe = (c: CierreCajaResponse): Resultado =>
  c.diferencia < 0 ? 'FALTANTE' : c.diferencia > 0 ? 'SOBRANTE' : 'CUADRO'

const RESULTADOS: { value: Resultado; label: string; tono: BadgeTone }[] = [
  { value: 'FALTANTE', label: 'Faltante', tono: 'danger' },
  { value: 'SOBRANTE', label: 'Sobrante', tono: 'warning' },
  { value: 'CUADRO', label: 'Cuadró', tono: 'success' },
]

const DESCUENTOS = [
  { value: 'PENDIENTE', label: 'Pendiente' },
  { value: 'DESCONTADO', label: 'Descontado' },
  { value: 'ANULADO', label: 'Anulado' },
  { value: 'NINGUNO', label: 'Sin descuento' },
]

/**
 * Los cierres de caja de todos los trabajadores. Cada faltante se descuenta
 * solo en la planilla semanal del trabajador; aquí se ve cómo va ese descuento
 * y se anula un cierre mal contado.
 */
export function CierresCajaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [cierres, setCierres] = useState<CierreCajaResponse[]>([])
  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setCierres(await cierreCajaApi.listar(desde, hasta))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los cierres.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['cierrescaja', 'planillas'], cargar)

  const anular = (c: CierreCajaResponse) =>
    confirmar({
      titulo: `Anular el cierre de ${c.usuario}`,
      mensaje: 'La plata vuelve a su caja como estaba antes de cerrar, y su faltante deja de descontarse. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await cierreCajaApi.anular(c.id)
          await cargar()
          toast.exito('Cierre anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el cierre.')
        }
      },
    })

  const vigentes = cierres.filter((c) => !c.anulado)
  const faltantePendiente = vigentes.reduce(
    (s, c) => s + (c.descuento?.estado === 'PENDIENTE' ? c.descuento.saldo : 0),
    0,
  )
  const sinEmpleado = vigentes.filter((c) => c.sinEmpleado && c.descuento?.estado === 'PENDIENTE').length
  const trabajadores = [...new Set(cierres.map((c) => c.usuario))].sort((a, b) => a.localeCompare(b, 'es'))

  const columns: DataTableColumn<CierreCajaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    {
      key: 'usuario',
      label: 'Trabajador',
      filterType: 'select',
      filterOptions: trabajadores.map((t) => ({ value: t, label: t })),
      render: (row) => (
        <span className="inline-flex items-center gap-1.5">
          {row.usuario}
          {row.sinEmpleado && (
            <span title="Sin empleado vinculado: su faltante no entra en la planilla">
              <UserX size={14} className="text-amber-600" />
            </span>
          )}
        </span>
      ),
    },
    { key: 'caja', label: 'Caja', filterable: false },
    { key: 'saldoSistema', label: 'Debía tener', align: 'right', filterable: false, render: (row) => soles(row.saldoSistema) },
    { key: 'contado', label: 'Contado', align: 'right', filterable: false, render: (row) => soles(row.contado) },
    {
      key: 'diferencia',
      label: 'Diferencia',
      align: 'right',
      filterType: 'select',
      filterOptions: RESULTADOS.map(({ value, label }) => ({ value, label })),
      value: (row) => resultadoDe(row),
      render: (row) => {
        const r = RESULTADOS.find((x) => x.value === resultadoDe(row))!
        return (
          <span className="inline-flex items-center gap-2">
            <Badge tone={r.tono}>{r.label}</Badge>
            {row.diferencia !== 0 && <span>{row.diferencia > 0 ? '+' : ''}{soles(row.diferencia)}</span>}
          </span>
        )
      },
    },
    { key: 'cuentaDestino', label: 'Entregado a', filterable: false },
    {
      key: 'descuento',
      label: 'Descuento',
      filterType: 'select',
      filterOptions: DESCUENTOS,
      value: (row) => row.descuento?.estado ?? 'NINGUNO',
      render: (row) => {
        const d = row.descuento
        if (!d) return <span className="text-ink-soft">—</span>
        if (d.estado === 'PENDIENTE') {
          return <Badge tone="warning">Pendiente {soles(d.saldo)}</Badge>
        }
        return <Badge tone={d.estado === 'DESCONTADO' ? 'success' : 'neutral'}>{d.estado === 'DESCONTADO' ? 'Descontado' : 'Anulado'}</Badge>
      },
    },
    { key: 'observacion', label: 'Observación', filterable: false, render: (row) => row.observacion ?? '—' },
    {
      key: 'anulado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Vigente', label: 'Vigente' },
        { value: 'Anulado', label: 'Anulado' },
      ],
      value: (row) => (row.anulado ? 'Anulado' : 'Vigente'),
      render: (row) => <Badge tone={row.anulado ? 'neutral' : 'success'}>{row.anulado ? 'Anulado' : 'Vigente'}</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<ClipboardCheck size={20} />}
      title="Cierres de caja"
      description="Los cierres de todas las cajas. Cada faltante se descuenta solo en la planilla semanal del trabajador."
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : sinEmpleado > 0 ? (
          <Alert tone="warning">
            {sinEmpleado} faltante(s) de usuarios sin empleado vinculado: no entran en ninguna planilla hasta vincularlos en
            Configuración → Usuarios.
          </Alert>
        ) : undefined
      }
      stats={
        <>
          <StatCard label="Faltantes por descontar" value={soles(faltantePendiente)} icon={<AlertTriangle size={18} />} tono="danger" />
          <StatCard label="Cierres del periodo" value={String(vigentes.length)} icon={<ClipboardCheck size={18} />} tono="sys" />
        </>
      }
      columns={columns}
      rows={cierres}
      onConsulta={(q) => {
        const fecha = q.filtros.find((f) => f.columna === 'fecha')
        setDesde(fecha?.valor || desplazarDias(-30))
        setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
      }}
      cardIcon={ClipboardCheck}
      searchPlaceholder="Buscar por trabajador..."
      empty={cargando ? 'Cargando cierres...' : 'No hay cierres en este periodo.'}
      rowActions={(row) =>
        !row.anulado && puede('finanzas.cierres', 'anular') ? (
          <RowAction
            label="Anular cierre"
            tone="danger"
            disabled={(row.descuento?.montoAplicado ?? 0) > 0}
            disabledReason="Su faltante ya se descontó en una planilla pagada"
            onClick={() => anular(row)}
          >
            <Ban size={15} />
          </RowAction>
        ) : null
      }
    >
      {dialogo}
    </ListPage>
  )
}
