import { useCallback, useEffect, useState } from 'react'
import { PackageX, Pencil, Plus, ShieldCheck, ShieldOff } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Checkbox,
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
import { motivoNovedadApi } from './motivoNovedadApi'
import type { MotivoNovedadRequest, MotivoNovedadResponse } from './motivoNovedadApi'

const VACIO: MotivoNovedadRequest = { nombre: '', descripcion: '', regresaAlAlmacen: true, activo: true }

/**
 * Por qué no se entregó algo. El dueño arma su propia lista: cada negocio
 * pierde entregas por razones distintas.
 *
 * Cada motivo dice además si la mercadería vuelve: lo que el cliente rechazó
 * viaja de regreso en el camión y hay que contarlo; lo que no se cargó nunca
 * salió del almacén y no hay nada que esperar.
 */
export function MotivosNovedadPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [motivos, setMotivos] = useState<MotivoNovedadResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MotivoNovedadResponse | null>(null)
  const [form, setForm] = useState<MotivoNovedadRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setMotivos(await motivoNovedadApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los motivos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('novedades', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setAbierto(true)
  }

  const abrirEdicion = (m: MotivoNovedadResponse) => {
    setEditando(m)
    setForm({
      nombre: m.nombre,
      descripcion: m.descripcion ?? '',
      regresaAlAlmacen: m.regresaAlAlmacen,
      activo: m.activo,
    })
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ponle un nombre al motivo.')

    setGuardando(true)
    try {
      const cuerpo = { ...form, nombre: form.nombre.trim(), descripcion: form.descripcion?.trim() || null }
      if (editando) await motivoNovedadApi.update(editando.id, cuerpo)
      else await motivoNovedadApi.create(cuerpo)
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Motivo actualizado' : 'Motivo creado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el motivo.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (m: MotivoNovedadResponse) =>
    confirmar({
      titulo: `${m.activo ? 'Desactivar' : 'Activar'} ${m.nombre}`,
      mensaje: m.activo
        ? 'Deja de ofrecerse al entregar pedidos. Las novedades que ya lo usan lo conservan.'
        : 'Vuelve a estar disponible para elegirse.',
      confirmar: m.activo ? 'Desactivar' : 'Activar',
      tono: m.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await motivoNovedadApi.update(m.id, {
            nombre: m.nombre,
            descripcion: m.descripcion,
            regresaAlAlmacen: m.regresaAlAlmacen,
            activo: !m.activo,
          })
          await cargar()
          toast.exito(`${m.nombre} ${m.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<MotivoNovedadResponse>[] = [
    { key: 'nombre', label: 'Motivo', filterable: false },
    {
      key: 'descripcion',
      label: 'Descripción',
      filterable: false,
      render: (row) => row.descripcion ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'regresaAlAlmacen',
      label: 'La mercadería',
      filterType: 'select',
      filterOptions: [
        { value: 'Vuelve al almacén', label: 'Vuelve al almacén' },
        { value: 'Nunca salió', label: 'Nunca salió' },
      ],
      value: (row) => (row.regresaAlAlmacen ? 'Vuelve al almacén' : 'Nunca salió'),
      render: (row) => (
        <Badge tone={row.regresaAlAlmacen ? 'warning' : 'neutral'}>
          {row.regresaAlAlmacen ? 'Vuelve al almacén' : 'Nunca salió'}
        </Badge>
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
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<PackageX size={20} />}
      title="Motivos de novedad"
      description="Por qué no se entregó algo. Los eliges al convertir un pedido en venta cuando el cliente recibe menos de lo pedido."
      actions={
        puede('tms.motivos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo motivo
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Motivos" value={String(motivos.length)} icon={<PackageX size={18} />} />
          <StatCard
            label="Activos"
            value={String(motivos.filter((m) => m.activo).length)}
            icon={<ShieldCheck size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={motivos}
      cardIcon={PackageX}
      searchPlaceholder="Buscar motivo..."
      empty={cargando ? 'Cargando motivos...' : 'Todavía no hay motivos: crea el primero.'}
      rowActions={(row) => (
        <>
          {puede('tms.motivos', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.motivos', 'editar') && (
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
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo motivo'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear motivo'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <Input
            label="Nombre"
            placeholder="Cliente no quiso, Producto dañado, Faltó en el carro..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Descripción"
            optional
            value={form.descripcion ?? ''}
            onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
          />

          <div className="flex flex-col gap-1.5">
            <Checkbox
              label="La mercadería viaja en el camión y vuelve al almacén"
              checked={form.regresaAlAlmacen}
              onChange={(e) => setForm({ ...form, regresaAlAlmacen: e.target.checked })}
            />
            <p className="pl-7 text-xs text-ink-soft">
              Márcalo cuando el producto salió y hay que contarlo al volver (el cliente lo rechazó, llegó dañado).
              Déjalo sin marcar si nunca salió del almacén (se olvidó cargar, no alcanzó).
            </p>
          </div>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
