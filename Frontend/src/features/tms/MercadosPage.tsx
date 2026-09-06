import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, ShieldCheck, ShieldOff, Store, Trash2 } from 'lucide-react'
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
import { mercadoApi } from './mercadoApi'
import type { MercadoRequest, MercadoResponse } from './mercadoApi'

const VACIO: MercadoRequest = { nombre: '', direccion: '', distrito: '' }

/**
 * Dónde se entrega: un mercado de abastos, pero también puede ser una zona
 * con tiendas o empresas. Lo elige cada cliente en Maestros → Clientes; acá
 * solo se mantiene el catálogo.
 */
export function MercadosPage() {
  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MercadoResponse | null>(null)
  const [form, setForm] = useState<MercadoRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setMercados(await mercadoApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los mercados.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('mercados', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (m: MercadoResponse) => {
    setEditando(m)
    setForm({ nombre: m.nombre, direccion: m.direccion ?? '', distrito: m.distrito ?? '' })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    setErrorForm('')
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        direccion: form.direccion?.trim() || null,
        distrito: form.distrito?.trim() || null,
      }
      if (editando) await mercadoApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      else await mercadoApi.create(cuerpo)
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el mercado.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (m: MercadoResponse) =>
    confirmar({
      titulo: `${m.activo ? 'Desactivar' : 'Activar'} ${m.nombre}`,
      mensaje: m.activo
        ? 'Deja de ofrecerse al dar de alta clientes nuevos. Los que ya lo usan lo conservan.'
        : 'Vuelve a estar disponible para elegirse.',
      confirmar: m.activo ? 'Desactivar' : 'Activar',
      tono: m.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await mercadoApi.update(m.id, {
            nombre: m.nombre,
            direccion: m.direccion,
            distrito: m.distrito,
            activo: !m.activo,
          })
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const eliminar = (m: MercadoResponse) =>
    confirmar({
      titulo: `Eliminar ${m.nombre}`,
      mensaje:
        m.clientes > 0
          ? `Lo usan ${m.clientes} cliente(s), así que no se podrá eliminar. Desactívalo en su lugar.`
          : 'Se borra definitivamente.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await mercadoApi.remove(m.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el mercado.')
        }
      },
    })

  const columns: DataTableColumn<MercadoResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    {
      key: 'direccion',
      label: 'Dirección',
      render: (row) => row.direccion ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'distrito',
      label: 'Distrito',
      render: (row) => row.distrito ?? <span className="text-ink-soft">—</span>,
    },
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

  const activos = mercados.filter((m) => m.activo)

  return (
    <ListPage
      icon={<Store size={20} />}
      title="Mercados"
      description="Dónde se entrega: un mercado de abastos, una zona con tiendas o una empresa."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo mercado
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Mercados" value={String(mercados.length)} icon={<Store size={18} />} />
          <StatCard
            label="Activos"
            value={String(activos.length)}
            icon={<ShieldCheck size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={mercados}
      cardIcon={Store}
      searchPlaceholder="Buscar por nombre, dirección, distrito..."
      empty={cargando ? 'Cargando mercados...' : 'Todavía no hay mercados registrados.'}
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
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo mercado'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear mercado'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre"
            placeholder="Mercado Central, Tienda Norte..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Dirección"
            optional
            value={form.direccion ?? ''}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />

          <Input
            label="Distrito"
            optional
            value={form.distrito ?? ''}
            onChange={(e) => setForm({ ...form, distrito: e.target.value })}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
