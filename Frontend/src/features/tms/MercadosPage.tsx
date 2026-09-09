import { useCallback, useEffect, useState } from 'react'
import { Eye, Pencil, Plus, ShieldCheck, ShieldOff, Store } from 'lucide-react'
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
import { usePermisos } from '../../lib/permisos'
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
  const { puede } = usePermisos()
  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<MercadoResponse | null>(null)
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

  const activos = mercados.filter((m) => m.activo)

  return (
    <ListPage
      icon={<Store size={20} />}
      title="Mercados"
      description="Dónde se entrega: un mercado de abastos, una zona con tiendas o una empresa."
      actions={
        puede('tms.mercados', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo mercado
          </Button>
        ) : undefined
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
          {/* Sin permiso: quien llega a la pantalla ya puede leer la ficha. */}
          <RowAction label={`Ver ${row.nombre}`} onClick={() => setDetalle(row)}>
            <Eye size={15} />
          </RowAction>
          {puede('tms.mercados', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.mercados', 'editar') && (
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
        title={detalle ? `Mercado ${detalle.nombre}` : ''}
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
            <Dato etiqueta="Dirección" valor={detalle.direccion} />
            <Dato etiqueta="Distrito" valor={detalle.distrito} />
            <Dato etiqueta="Clientes" valor={String(detalle.clientes)} />
            <Dato etiqueta="Estado" valor={detalle.activo ? 'Activo' : 'Inactivo'} />
          </div>
        )}
      </Modal>

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
