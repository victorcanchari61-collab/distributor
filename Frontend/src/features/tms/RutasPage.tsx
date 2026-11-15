import { useCallback, useEffect, useState } from 'react'
import { HandCoins, Plus, Route, ShieldCheck, TrendingUp, UserX } from 'lucide-react'
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
import { rutaApi } from './rutaApi'
import type { RutaRequest, RutaResponse } from './rutaApi'

const DIAS = ['LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO']
const DIA_CORTO: Record<string, string> = {
  LUNES: 'Lun',
  MARTES: 'Mar',
  MIERCOLES: 'Mié',
  JUEVES: 'Jue',
  VIERNES: 'Vie',
  SABADO: 'Sáb',
  DOMINGO: 'Dom',
}
const DIA_LARGO: Record<string, string> = {
  LUNES: 'Lunes',
  MARTES: 'Martes',
  MIERCOLES: 'Miércoles',
  JUEVES: 'Jueves',
  VIERNES: 'Viernes',
  SABADO: 'Sábado',
  DOMINGO: 'Domingo',
}

const soles = (n: number) => `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
const sinDato = <span className="text-ink-soft">—</span>

/** Los días en que sale, sin repetir: dos camiones el mismo lunes siguen siendo un lunes. */
const diasDe = (r: RutaResponse) => DIAS.filter((d) => r.salidas.some((x) => x.dia === d))
const placasDe = (r: RutaResponse) => [...new Set(r.salidas.map((x) => x.placa))]

/** Cuántos mercados se ven en la celda antes del "+N". */
const MERCADOS_A_LA_VISTA = 4
/** Por número cuando lo son ("2" antes que "10"), y por nombre si no. */
const ordenarMercados = (mercados: string[]) =>
  [...mercados].sort((a, b) => a.localeCompare(b, 'es', { numeric: true }))

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

  // Las tarjetas llevan a lo que cuentan: "Ver las 8" pone ese filtro en "Estado".
  const [filtroPedido, setFiltroPedido] = useState<{ column: string; value: string; vez: number }>()
  const verPor = (column: string, value: string) =>
    setFiltroPedido((f) => ({ column, value, vez: (f?.vez ?? 0) + 1 }))
  const verEstado = (value: string) => verPor('activo', value)

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
    setAbierto(true)
  }

  const abrirEdicion = (r: RutaResponse) => {
    setEditando(r)
    setForm({ nombre: r.nombre })
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ingresa el nombre.')

    setGuardando(true)
    try {
      const cuerpo = { nombre: form.nombre.trim() }
      if (editando) await rutaApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      else await rutaApi.create(cuerpo)
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Ruta actualizada' : 'Ruta creada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar la ruta.')
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
      // Quién la tiene a cargo: se asigna en Usuarios, no aquí.
      key: 'vendedores',
      label: 'A cargo de',
      filterType: 'select',
      filterOptions: [
        { value: 'Con vendedor', label: 'Con vendedor' },
        { value: 'Sin vendedor', label: 'Sin vendedor' },
      ],
      value: (row) => (row.vendedores.length ? 'Con vendedor' : 'Sin vendedor'),
      render: (row) =>
        row.vendedores.length ? row.vendedores.join(', ') : <span className="text-ink-soft">Sin vendedor</span>,
    },
    {
      // Dónde están sus clientes: se deduce de los mercados de los clientes activos de la ruta.
      key: 'mercados',
      label: 'Mercados',
      filterType: 'select',
      filterOptions: ordenarMercados([...new Set(rutas.flatMap((r) => r.mercados))]).map((m) => ({
        value: m,
        label: m,
      })),
      valores: (row) => row.mercados,
      value: (row) => row.mercados.join(', '),
      width: 240,
      // Una ruta puede tener veinte mercados: se ven los primeros y un "+N" con la lista entera al pasar el mouse,
      // para que la fila no se haga altísima.
      render: (row) => {
        if (!row.mercados.length) return sinDato
        const todos = ordenarMercados(row.mercados)
        const vistos = todos.slice(0, MERCADOS_A_LA_VISTA)
        const resto = todos.length - vistos.length
        return (
          <span className="flex flex-wrap gap-1" title={todos.join(', ')}>
            {vistos.map((m) => (
              <span key={m} className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-ink">
                {m}
              </span>
            ))}
            {resto > 0 && (
              <span className="rounded-full bg-[rgb(var(--sys-rgb)/0.12)] px-2 py-0.5 text-xs font-semibold text-[rgb(var(--sys-ink-rgb))]">
                +{resto}
              </span>
            )}
          </span>
        )
      },
    },
    {
      // Qué días sale, según los recorridos de Flota (se editan allá).
      key: 'dias',
      label: 'Días',
      filterType: 'select',
      width: 190,
      filterOptions: DIAS.map((d) => ({ value: d, label: DIA_LARGO[d] })),
      valores: (row) => diasDe(row),
      value: (row) => diasDe(row).map((d) => DIA_CORTO[d]).join(', '),
      render: (row) => (diasDe(row).length ? diasDe(row).map((d) => DIA_CORTO[d]).join(', ') : sinDato),
    },
    {
      key: 'vehiculo',
      label: 'Camión',
      filterType: 'select',
      filterOptions: [...new Set(rutas.flatMap((r) => placasDe(r)))]
        .sort()
        .map((p) => ({ value: p, label: p })),
      valores: (row) => placasDe(row),
      value: (row) => placasDe(row).join(', '),
      render: (row) => (placasDe(row).length ? placasDe(row).join(', ') : sinDato),
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
      key: 'clientesConCompraMes',
      label: 'Compraron',
      align: 'right',
      filterable: false,
      render: (row) => (row.clientesConCompraMes > 0 ? row.clientesConCompraMes : sinDato),
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
      key: 'clientesConDeuda',
      label: 'Deben',
      align: 'right',
      filterable: false,
      render: (row) => (row.clientesConDeuda > 0 ? row.clientesConDeuda : sinDato),
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

  const activas = rutas.filter((r) => r.activo)
  const sinVendedor = activas.filter((r) => r.vendedores.length === 0).length
  const ventasMes = rutas.reduce((n, r) => n + r.ventasMes, 0)
  const compraron = rutas.reduce((n, r) => n + r.clientesConCompraMes, 0)
  const porCobrar = rutas.reduce((n, r) => n + r.porCobrar, 0)
  const deben = rutas.reduce((n, r) => n + r.clientesConDeuda, 0)

  return (
    <ListPage
      icon={<Route size={20} />}
      title="Rutas"
      description="Rutas de reparto a las que pertenece cada cliente."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />} sinPermiso={!puede('tms.rutas', 'crear')}>
          Nueva ruta
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      filtroPedido={filtroPedido}
      stats={
        <>
          <StatCard
            label="Rutas"
            value={String(rutas.length)}
            icon={<Route size={18} />}
            progreso={rutas.length > 0 ? 1 : 0}
            accion={{ label: 'Ver todas', onClick: () => verEstado('') }}
          />
          <StatCard
            label="Activas"
            value={String(activas.length)}
            icon={<ShieldCheck size={18} />}
            tono="success"
            progreso={rutas.length > 0 ? activas.length / rutas.length : 0}
            accion={{
              label: activas.length > 0 ? `Ver las ${activas.length}` : 'Ver',
              onClick: () => verEstado('Activo'),
            }}
          />
          <StatCard
            label="Sin vendedor"
            value={String(sinVendedor)}
            hint="activas sin nadie a cargo"
            icon={<UserX size={18} />}
            tono={sinVendedor > 0 ? 'warning' : 'success'}
            progreso={activas.length > 0 ? sinVendedor / activas.length : 0}
            accion={{
              label: sinVendedor > 0 ? `Ver las ${sinVendedor}` : 'Ver',
              onClick: () => verPor('vendedores', 'Sin vendedor'),
            }}
          />
          <StatCard
            label="Ventas del mes"
            value={soles(ventasMes)}
            hint={compraron === 1 ? '1 cliente compró' : `${compraron} clientes compraron`}
            icon={<TrendingUp size={18} />}
            tono="success"
          />
          <StatCard
            label="Por cobrar"
            value={soles(porCobrar)}
            hint={deben === 1 ? '1 cliente debe' : `${deben} clientes deben`}
            icon={<HandCoins size={18} />}
            tono={porCobrar > 0 ? 'warning' : 'neutral'}
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
            <FaEye size={15} />
          </RowAction>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)} sinPermiso={!puede('tms.rutas', 'editar')}>
            <FaPencil size={15} />
          </RowAction>
          <RowAction
            label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
            tone={row.activo ? 'warning' : 'success'}
            onClick={() => cambiarEstado(row)}
            sinPermiso={!puede('tms.rutas', 'editar')}>
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
            <Dato etiqueta="A cargo de" valor={detalle.vendedores.length ? detalle.vendedores.join(', ') : 'Sin vendedor'} />
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
