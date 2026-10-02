import { useCallback, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { ClipboardCheck, Pencil, Plus, ShieldCheck, ShieldOff } from 'lucide-react'
import { Alert, Badge, Button, ListPage, RowAction, StatCard, useConfirmacion, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { resultadoRevisionApi } from './motivoNovedadApi'
import type { ResultadoRevisionResponse } from './motivoNovedadApi'
import { ResultadoRevisionModal } from './ResultadoRevisionModal'

/**
 * Lo que el encargado puede encontrar al contar lo que volvió en el camión.
 * El dueño arma la lista; cada resultado dice si volvió todo lo que no se
 * entregó (la novedad queda Recibida) o no (se pide cuánto volvió y queda
 * Faltante).
 */
export function ResultadosRevisionTab({ cabecera }: { cabecera: ReactNode }) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [resultados, setResultados] = useState<ResultadoRevisionResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<ResultadoRevisionResponse | null>(null)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setResultados(await resultadoRevisionApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los resultados.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('novedades', cargar)

  const cambiarEstado = (r: ResultadoRevisionResponse) =>
    confirmar({
      titulo: `${r.activo ? 'Desactivar' : 'Activar'} ${r.nombre}`,
      mensaje: r.activo
        ? 'Deja de ofrecerse al revisar una novedad. Las revisiones que ya lo usan lo conservan.'
        : 'Vuelve a estar disponible para elegirse.',
      confirmar: r.activo ? 'Desactivar' : 'Activar',
      tono: r.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await resultadoRevisionApi.update(r.id, {
            nombre: r.nombre,
            descripcion: r.descripcion,
            volvioTodo: r.volvioTodo,
            activo: !r.activo,
          })
          await cargar()
          toast.exito(`${r.nombre} ${r.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<ResultadoRevisionResponse>[] = [
    { key: 'nombre', label: 'Resultado', filterable: false },
    {
      key: 'descripcion',
      label: 'Descripción',
      filterable: false,
      render: (row) => row.descripcion ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'volvioTodo',
      label: 'Queda como',
      filterType: 'select',
      filterOptions: [
        { value: 'Recibida', label: 'Recibida' },
        { value: 'Faltante', label: 'Faltante' },
      ],
      value: (row) => (row.volvioTodo ? 'Recibida' : 'Faltante'),
      render: (row) =>
        row.volvioTodo ? (
          <Badge tone="success">Recibida · volvió todo</Badge>
        ) : (
          <Badge tone="danger">Faltante · pide cuánto volvió</Badge>
        ),
    },
    { key: 'usos', label: 'Usos', align: 'right', filterable: false },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>,
    },
  ]

  return (
    <>
      {cabecera}
      <ListPage
        icon={<ClipboardCheck size={20} />}
        title="Resultados de revisión"
        description="Lo que puedes encontrar al contar lo que volvió en el camión. Los eliges al revisar una novedad de entrega."
        actions={
          puede('tms.motivos', 'crear') ? (
            <Button
              size="sm"
              onClick={() => {
                setEditando(null)
                setAbierto(true)
              }}
              iconRight={<Plus size={15} />}
            >
              Nuevo resultado
            </Button>
          ) : undefined
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard label="Resultados" value={String(resultados.length)} icon={<ClipboardCheck size={18} />} />
            <StatCard
              label="Activos"
              value={String(resultados.filter((r) => r.activo).length)}
              icon={<ShieldCheck size={18} />}
              tono="success"
            />
          </>
        }
        columns={columns}
        rows={resultados}
        cardIcon={ClipboardCheck}
        searchPlaceholder="Buscar resultado..."
        empty={cargando ? 'Cargando resultados...' : 'Todavía no hay resultados.'}
        rowActions={(row) =>
          puede('tms.motivos', 'editar') ? (
            <>
              <RowAction
                label={`Editar ${row.nombre}`}
                onClick={() => {
                  setEditando(row)
                  setAbierto(true)
                }}
              >
                <Pencil size={15} />
              </RowAction>
              <RowAction
                label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
                tone={row.activo ? 'warning' : 'success'}
                onClick={() => cambiarEstado(row)}
              >
                {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
              </RowAction>
            </>
          ) : null
        }
      >
        <ResultadoRevisionModal
          abierto={abierto}
          editando={editando}
          onClose={() => setAbierto(false)}
          onGuardado={async () => {
            setAbierto(false)
            await cargar()
          }}
        />
        {dialogo}
      </ListPage>
    </>
  )
}
