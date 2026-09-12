import { useCallback, useEffect, useState } from 'react'
import { Eye, Pencil, Plus, Route, ShieldCheck, ShieldOff } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { rutaApi } from './rutaApi'
import type { RutaRequest, RutaResponse } from './rutaApi'

const VACIO: RutaRequest = { nombre: '' }

/**
 * Rutas de reparto a las que pertenece un cliente. Se elige en Maestros →
 * Clientes; acá solo se mantiene el catálogo.
 */
export function RutasPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<RutaResponse | null>(null)
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<RutaResponse | null>(null)
  const [form, setForm] = useState<RutaRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setRutas(await rutaApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las rutas.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('rutas', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (r: RutaResponse) => {
    setEditando(r)
    setForm({ nombre: r.nombre })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    setErrorForm('')
    try {
      const cuerpo = { nombre: form.nombre.trim() }
      if (editando) await rutaApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      else await rutaApi.create(cuerpo)
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Ruta actualizada' : 'Ruta creada')
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar la ruta.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (r: RutaResponse) =>
    confirmar({
      titulo: `${r.activo ? 'Desactivar' : 'Activar'} ${r.nombre}`,
      mensaje: r.activo
        ? 'Deja de ofrecerse al dar de alta clientes nuevos. Los que ya la usan la conservan.'
        : 'Vuelve a estar disponible para elegirse.',
      confirmar: r.activo ? 'Desactivar' : 'Activar',
      tono: r.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await rutaApi.update(r.id, { nombre: r.nombre, activo: !r.activo })
          await cargar()
          toast.exito(`${r.nombre} ${r.activo ? 'desactivada' : 'activada'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<RutaResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    // Un contador no se busca por texto: no hay control numerico en el panel.
    { key: 'clientes', label: 'Clientes', align: 'right', filterable: false },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>
      ),
    },
  ]

  const activas = rutas.filter((r) => r.activo)

  return (
    <ListPage
      icon={<Route size={20} />}
      title="Rutas"
      description="Rutas de reparto a las que pertenece cada cliente."
      actions={
        puede('tms.rutas', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nueva ruta
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Rutas" value={String(rutas.length)} icon={<Route size={18} />} />
          <StatCard
            label="Activas"
            value={String(activas.length)}
            icon={<ShieldCheck size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={rutas}
      cardIcon={Route}
      searchPlaceholder="Buscar por nombre..."
      empty={cargando ? 'Cargando rutas...' : 'Todavía no hay rutas registradas.'}
      rowActions={(row) => (
        <>
          {/* Sin permiso: quien llega a la pantalla ya puede leer la ficha. */}
          <RowAction tone="view" label={`Ver ${row.nombre}`} onClick={() => setDetalle(row)}>
            <Eye size={15} />
          </RowAction>
          {puede('tms.rutas', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.rutas', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => cambiarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}
        </>
      )}
    >
      {/*
        La ficha, en solo lectura. Antes la unica forma de mirarla era abrir el
        formulario de edicion, con el riesgo de guardar algo sin querer.
      */}
      <Modal
        open={detalle !== null}
        size="sm"
        title={detalle ? `Ruta ${detalle.nombre}` : ''}
        onClose={() => setDetalle(null)}
        footer={
          <Button variant="secondary" size="sm" onClick={() => setDetalle(null)}>
            Cerrar
          </Button>
        }
      >
        {detalle && (
          <div className="grid grid-cols-2 gap-3">
            <Dato etiqueta="Nombre" valor={detalle.nombre} />
            <Dato etiqueta="Clientes" valor={String(detalle.clientes)} />
            <Dato etiqueta="Estado" valor={detalle.activo ? 'Activa' : 'Inactiva'} />
          </div>
        )}
      </Modal>

      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nueva ruta'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear ruta'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre"
            placeholder="Ruta 1, Zona Norte..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}

/** Una etiqueta con su valor en la ficha; "—" cuando no hay dato. */
function Dato({ etiqueta, valor }: { etiqueta: string; valor?: string | null }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">
        {etiqueta}
      </span>
      <span className="text-sm text-ink">{valor || '—'}</span>
    </div>
  )
}
