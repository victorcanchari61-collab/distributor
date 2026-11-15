import { useCallback, useEffect, useState } from 'react'
import { HandCoins, Plus, ShieldCheck, Store, TrendingUp } from 'lucide-react'
import { FaBan, FaCircleCheck, FaEye, FaPencil } from 'react-icons/fa6'
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
import { mercadoApi } from './mercadoApi'
import type { MercadoRequest, MercadoResponse } from './mercadoApi'

const VACIO: MercadoRequest = { nombre: '', direccion: '', distrito: '' }

const soles = (n: number) => `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
const sinDato = <span className="text-ink-soft">—</span>
/** Por número cuando lo son ("2" antes que "10"), y por nombre si no. */
const ordenar = (lista: string[]) => [...lista].sort((a, b) => a.localeCompare(b, 'es', { numeric: true }))

/**
 * Dónde se entrega: un mercado de abastos, pero también puede ser una zona
 * con tiendas o empresas. Lo elige cada cliente en Maestros → Clientes; acá
 * solo se mantiene el catálogo.
 */
export function MercadosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<MercadoResponse | null>(null)
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MercadoResponse | null>(null)
  const [form, setForm] = useState<MercadoRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)

  // Las tarjetas llevan a lo que cuentan: "Ver los 12" pone ese filtro en "Estado".
  const [filtroPedido, setFiltroPedido] = useState<{ column: string; value: string; vez: number }>()
  const verEstado = (value: string) => setFiltroPedido((f) => ({ column: 'activo', value, vez: (f?.vez ?? 0) + 1 }))

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
    setAbierto(true)
  }

  const abrirEdicion = (m: MercadoResponse) => {
    setEditando(m)
    setForm({ nombre: m.nombre, direccion: m.direccion ?? '', distrito: m.distrito ?? '' })
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ingresa el nombre.')

    setGuardando(true)
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
      toast.exito(editando ? 'Mercado actualizado' : 'Mercado creado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el mercado.')
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
        try {
          await mercadoApi.update(m.id, {
            nombre: m.nombre,
            direccion: m.direccion,
            distrito: m.distrito,
            activo: !m.activo,
          })
          await cargar()
          toast.exito(`${m.nombre} ${m.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  /** Los valores que de verdad hay en esa columna, para elegir y no teclear. */
  const distintos = (campo: 'direccion' | 'distrito') =>
    [...new Set(mercados.map((m) => m[campo]?.trim()).filter((v): v is string => !!v))]
      .sort((a, b) => a.localeCompare(b, 'es'))
      .map((v) => ({ value: v, label: v }))

  const columns: DataTableColumn<MercadoResponse>[] = [
    // El nombre se busca con el buscador de arriba, no en el panel.
    { key: 'nombre', label: 'Nombre', filterable: false },
    {
      key: 'direccion',
      label: 'Dirección',
      filterType: 'select',
      filterOptions: distintos('direccion'),
      render: (row) => row.direccion ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'distrito',
      label: 'Distrito',
      filterType: 'select',
      filterOptions: distintos('distrito'),
      render: (row) => row.distrito ?? <span className="text-ink-soft">—</span>,
    },
    // Un contador no se busca por texto: no hay control numerico en el panel.
    { key: 'clientes', label: 'Clientes', align: 'right', filterable: false },
    {
      // Qué rutas llegan: se deduce de las rutas de sus clientes activos.
      key: 'rutas',
      label: 'Rutas',
      width: 200,
      filterType: 'select',
      filterOptions: ordenar([...new Set(mercados.flatMap((m) => m.rutas))]).map((r) => ({ value: r, label: r })),
      valores: (row) => row.rutas,
      value: (row) => ordenar(row.rutas).join(', '),
      render: (row) =>
        row.rutas.length ? (
          <span className="flex flex-wrap gap-1">
            {ordenar(row.rutas).map((r) => (
              <span key={r} className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-ink">
                {r}
              </span>
            ))}
          </span>
        ) : (
          sinDato
        ),
    },
    {
      key: 'ventasMes',
      label: 'Ventas del mes',
      align: 'right',
      filterable: false,
      value: (row) => row.ventasMes,
      render: (row) => (row.ventasMes > 0 ? <span className="tabular-nums">{soles(row.ventasMes)}</span> : sinDato),
    },
    {
      key: 'porCobrar',
      label: 'Por cobrar',
      align: 'right',
      filterable: false,
      value: (row) => row.porCobrar,
      render: (row) =>
        row.porCobrar > 0 ? (
          <span className="font-semibold text-amber-700 tabular-nums">{soles(row.porCobrar)}</span>
        ) : (
          sinDato
        ),
    },
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
  const ventasMes = mercados.reduce((n, m) => n + m.ventasMes, 0)
  const conVentas = mercados.filter((m) => m.ventasMes > 0).length
  const porCobrar = mercados.reduce((n, m) => n + m.porCobrar, 0)
  const conDeuda = mercados.filter((m) => m.porCobrar > 0).length

  return (
    <ListPage
      icon={<Store size={20} />}
      title="Mercados"
      description="Dónde se entrega: mercados, zonas o empresas."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />} sinPermiso={!puede('tms.mercados', 'crear')}>
          Nuevo mercado
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      filtroPedido={filtroPedido}
      stats={
        <>
          <StatCard
            label="Mercados"
            value={String(mercados.length)}
            icon={<Store size={18} />}
            progreso={mercados.length > 0 ? 1 : 0}
            accion={{ label: 'Ver todos', onClick: () => verEstado('') }}
          />
          <StatCard
            label="Activos"
            value={String(activos.length)}
            icon={<ShieldCheck size={18} />}
            tono="success"
            progreso={mercados.length > 0 ? activos.length / mercados.length : 0}
            accion={{
              label: activos.length > 0 ? `Ver los ${activos.length}` : 'Ver',
              onClick: () => verEstado('Activo'),
            }}
          />
          <StatCard
            label="Ventas del mes"
            value={soles(ventasMes)}
            hint={conVentas === 1 ? 'en 1 mercado' : `en ${conVentas} mercados`}
            icon={<TrendingUp size={18} />}
            tono="success"
          />
          <StatCard
            label="Por cobrar"
            value={soles(porCobrar)}
            hint={conDeuda === 1 ? '1 mercado con deuda' : `${conDeuda} mercados con deuda`}
            icon={<HandCoins size={18} />}
            tono={porCobrar > 0 ? 'warning' : 'neutral'}
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
          <RowAction tone="view" label={`Ver ${row.nombre}`} onClick={() => setDetalle(row)}>
            <FaEye size={15} />
          </RowAction>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)} sinPermiso={!puede('tms.mercados', 'editar')}>
            <FaPencil size={15} />
          </RowAction>
          <RowAction
            label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
            tone={row.activo ? 'warning' : 'success'}
            onClick={() => cambiarEstado(row)}
            sinPermiso={!puede('tms.mercados', 'editar')}>
            {row.activo ? <FaBan size={15} /> : <FaCircleCheck size={15} />}
          </RowAction>
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
