import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, Route, ShieldCheck, ShieldOff, Trash2 } from 'lucide-react'
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
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { rutaApi } from './rutaApi'
import type { RutaRequest, RutaResponse } from './rutaApi'

const VACIO: RutaRequest = { nombre: '' }

/**
 * Rutas de reparto a las que pertenece un cliente. Se elige en Maestros →
 * Clientes; acá solo se mantiene el catálogo.
 */
export function RutasPage() {
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

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
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const eliminar = (r: RutaResponse) =>
    confirmar({
      titulo: `Eliminar ${r.nombre}`,
      mensaje:
        r.clientes > 0
          ? `La usan ${r.clientes} cliente(s), así que no se podrá eliminar. Desactívala en su lugar.`
          : 'Se borra definitivamente.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await rutaApi.remove(r.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar la ruta.')
        }
      },
    })

  const columns: DataTableColumn<RutaResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'clientes', label: 'Clientes', align: 'right' },
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
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nueva ruta
        </Button>
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
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
            tone={row.activo ? 'warning' : 'success'}
            onClick={() => cambiarEstado(row)}
          >
            {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
          </RowAction>
          <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
            <Trash2 size={15} />
          </RowAction>
        </>
      )}
    >
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
