import { useCallback, useEffect, useState } from 'react'
import { Eye, RefreshCw, ScrollText } from 'lucide-react'
import { Alert, Badge, Button, ListPage, Modal, RowAction, StatCard } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { auditoriaApi } from './auditoriaApi'
import type { AccionAuditoria, AuditoriaResponse, ResumenAuditoria } from './auditoriaApi'

function accionBadge(accion: AccionAuditoria) {
  const tono = accion === 'CREADO' ? 'success' : accion === 'ELIMINADO' ? 'danger' : 'warning'
  const texto = accion === 'CREADO' ? 'Creado' : accion === 'ELIMINADO' ? 'Eliminado' : 'Actualizado'
  return <Badge tone={tono}>{texto}</Badge>
}

/** Un valor de la bitácora, legible: fechas cortas, vacíos como "—". */
function formatearValor(valor: unknown): string {
  if (valor === null || valor === undefined || valor === '') return '—'
  if (typeof valor === 'boolean') return valor ? 'Sí' : 'No'
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(valor)) {
    return new Date(valor).toLocaleString('es-PE')
  }
  if (typeof valor === 'object') return JSON.stringify(valor)
  return String(valor)
}

/**
 * Auditoría: qué cambió en el sistema, quién y cuándo.
 *
 * Es solo lectura. Los registros los deja el backend al guardar cualquier
 * entidad — nada se anota desde aquí. Los filtros consultan al servidor; el
 * buscador de la tabla afina sobre lo que ya llegó.
 */
export function AuditoriaPage() {
  const [registros, setRegistros] = useState<AuditoriaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalleAbierto, setDetalleAbierto] = useState<AuditoriaResponse | null>(null)

  /*
   * La bitácora crece con CADA cambio del sistema, así que no se trae entera:
   * la tabla dice qué página necesita y solo esa se pide. Búsqueda, filtros y
   * orden se resuelven en la base.
   *
   * Los contadores de arriba salen de `resumen` y no de las filas cargadas:
   * contar sobre la página visible diría "20 registros".
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [total, setTotal] = useState(0)
  const [resumen, setResumen] = useState<ResumenAuditoria | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await auditoriaApi.listar(q)
      setRegistros(pagina.items)
      setTotal(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la auditoría.')
    } finally {
      setCargando(false)
    }
  }, [])

  const cargarResumen = useCallback(async () => {
    try {
      setResumen(await auditoriaApi.resumen())
    } catch {
      // Los contadores son secundarios: si fallan, la tabla igual sirve.
    }
  }, [])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarResumen()])
  }, [consulta, cargarPagina, cargarResumen])

  useEffect(() => {
    void cargarResumen()
  }, [cargarResumen])

  const columns: DataTableColumn<AuditoriaResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => new Date(row.fecha).toLocaleString('es-PE'),
    },
    {
      key: 'usuario',
      label: 'Usuario',
      filterType: 'select',
      filterOptions: (resumen?.usuarios ?? []).map((u) => ({ value: u, label: u })),
    },
    {
      key: 'entidad',
      label: 'Entidad',
      filterType: 'select',
      filterOptions: (resumen?.entidades ?? []).map((e) => ({ value: e, label: e })),
    },
    { key: 'entidadId', label: 'Registro', render: (row) => <Badge>#{row.entidadId}</Badge> },
    {
      key: 'accion',
      label: 'Acción',
      filterType: 'select',
      filterOptions: [
        { value: 'CREADO', label: 'Creado' },
        { value: 'ACTUALIZADO', label: 'Actualizado' },
        { value: 'ELIMINADO', label: 'Eliminado' },
      ],
      render: (row) => accionBadge(row.accion),
    },
    {
      key: 'cambios',
      label: 'Campos',
      align: 'right',
      // Se cuenta sobre el JSON ya cargado: la base no puede ordenar ni
      // filtrar por esto, asi que no se ofrece.
      sortable: false,
      filterable: false,
      value: (row) => Object.keys(row.valoresNuevos ?? row.valoresAnteriores ?? {}).length,
      render: (row) => String(Object.keys(row.valoresNuevos ?? row.valoresAnteriores ?? {}).length),
    },
  ]

  const campos = detalleAbierto
    ? Array.from(
        new Set([
          ...Object.keys(detalleAbierto.valoresAnteriores ?? {}),
          ...Object.keys(detalleAbierto.valoresNuevos ?? {}),
        ]),
      )
    : []

  return (
    <ListPage
      icon={<ScrollText size={20} />}
      title="Auditoría"
      description="Qué cambió en el sistema, quién lo hizo y cuándo. Se registra solo, al guardar cualquier dato."
      actions={
        <Button variant="secondary" size="sm" onClick={() => void cargar()} loading={cargando}>
          <RefreshCw size={15} />
          Actualizar
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Registros" value={String(resumen?.total ?? 0)} icon={<ScrollText size={18} />} />
          <StatCard
            label="Creados"
            value={String(resumen?.creados ?? 0)}
            icon={<ScrollText size={18} />}
            tono="success"
          />
          <StatCard
            label="Actualizados"
            value={String(resumen?.actualizados ?? 0)}
            icon={<ScrollText size={18} />}
            tono="warning"
          />
          <StatCard
            label="Eliminados"
            value={String(resumen?.eliminados ?? 0)}
            icon={<ScrollText size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={registros}
      servidor={{
        total,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={ScrollText}
      searchPlaceholder="Buscar por usuario, entidad, registro..."
      empty={cargando ? 'Cargando auditoría...' : 'No hay cambios registrados con esos filtros.'}
      rowActions={(row) => (
        <RowAction label={`Ver cambios de ${row.entidad} #${row.entidadId}`} tone="view" onClick={() => setDetalleAbierto(row)}>
          <Eye size={15} />
        </RowAction>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.entidad} #${detalleAbierto.entidadId}` : ''}
        description={
          detalleAbierto
            ? `${new Date(detalleAbierto.fecha).toLocaleString('es-PE')} · ${detalleAbierto.usuario}`
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            <div>{accionBadge(detalleAbierto.accion)}</div>

            <div className="overflow-x-auto rounded-field border border-line">
              <table className="w-full text-[13px]">
                <thead>
                  <tr className="border-b border-line bg-surface-alt text-left text-[10.5px] font-semibold tracking-wide text-ink-muted uppercase">
                    <th className="px-3 py-1.5">Campo</th>
                    {detalleAbierto.accion !== 'CREADO' && <th className="px-3 py-1.5">Antes</th>}
                    {detalleAbierto.accion !== 'ELIMINADO' && <th className="px-3 py-1.5">Después</th>}
                  </tr>
                </thead>
                <tbody>
                  {campos.map((campo) => (
                    <tr key={campo} className="border-b border-line last:border-0">
                      <td className="px-3 py-2 font-semibold text-ink">{campo}</td>
                      {detalleAbierto.accion !== 'CREADO' && (
                        <td className="px-3 py-2 text-ink-soft">
                          {formatearValor(detalleAbierto.valoresAnteriores?.[campo])}
                        </td>
                      )}
                      {detalleAbierto.accion !== 'ELIMINADO' && (
                        <td className="px-3 py-2 text-ink">{formatearValor(detalleAbierto.valoresNuevos?.[campo])}</td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Modal>
    </ListPage>
  )
}
