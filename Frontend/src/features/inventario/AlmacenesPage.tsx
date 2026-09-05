import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, ShieldCheck, ShieldOff, Star, Warehouse } from 'lucide-react'
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
import { almacenApi } from './inventarioApi'
import type { AlmacenResponse } from './inventarioApi'
import { useRealtime } from '../../lib/realtime'
import { Checkbox } from '../../components/ui'

const VACIO = { codigo: '', nombre: '', direccion: '', esPrincipal: false }

export function AlmacenesPage() {
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<AlmacenResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setAlmacenes(await almacenApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los almacenes.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('almacenes', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (a: AlmacenResponse) => {
    setEditando(a)
    setForm({ codigo: a.codigo, nombre: a.nombre, direccion: a.direccion ?? '', esPrincipal: a.esPrincipal })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.codigo.trim()) return setErrorForm('Ingresa el código.')
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    try {
      const cuerpo = {
        codigo: form.codigo.trim(),
        nombre: form.nombre.trim(),
        direccion: form.direccion.trim() || null,
        esPrincipal: form.esPrincipal,
      }
      if (editando) {
        await almacenApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      } else {
        await almacenApi.create(cuerpo)
      }
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el almacén.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (a: AlmacenResponse) =>
    confirmar({
      titulo: `${a.activo ? 'Desactivar' : 'Activar'} ${a.nombre}`,
      mensaje: a.activo
        ? 'Deja de recibir movimientos nuevos. Su historial se conserva.'
        : 'Vuelve a estar disponible para movimientos.',
      confirmar: a.activo ? 'Desactivar' : 'Activar',
      tono: a.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await almacenApi.update(a.id, {
            codigo: a.codigo,
            nombre: a.nombre,
            direccion: a.direccion,
            esPrincipal: a.esPrincipal,
            activo: !a.activo,
          })
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<AlmacenResponse>[] = [
    {
      key: 'nombre',
      label: 'Nombre',
      render: (row) => (
        <span className="flex items-center gap-2">
          {row.nombre}
          {row.esPrincipal && <Badge tone="sys">Principal</Badge>}
        </span>
      ),
    },
    { key: 'codigo', label: 'Código', render: (row) => <Badge>{row.codigo}</Badge> },
    {
      key: 'direccion',
      label: 'Dirección',
      render: (row) => row.direccion ?? <span className="text-ink-soft">—</span>,
    },
    { key: 'productos', label: 'Productos', align: 'right' },
    {
      key: 'valorizado',
      label: 'Valorizado',
      align: 'right',
      render: (row) => `S/ ${row.valorizado.toFixed(2)}`,
    },
    {
      key: 'activo',
      label: 'Estado',
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>
          {row.activo ? 'Activo' : 'Inactivo'}
        </Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Warehouse size={20} />}
      title="Almacenes"
      description="Dónde se guarda la mercadería. El principal es donde va todo movimiento sin indicar otro."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo almacén
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Almacenes"
            value={String(almacenes.length)}
            icon={<Warehouse size={18} />}
          />
          <StatCard
            label="Valor total"
            value={`S/ ${almacenes.reduce((n, a) => n + a.valorizado, 0).toFixed(2)}`}
            icon={<Star size={18} />}
            tono="success"
            hint="al costo de compra"
          />
        </>
      }
      columns={columns}
      rows={almacenes}
      cardIcon={Warehouse}
      searchPlaceholder="Buscar almacén..."
      empty={cargando ? 'Cargando almacenes...' : 'Todavía no hay almacenes.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          {!row.esPrincipal && (
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
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo almacén'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear almacén'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}
          <Input
            label="Código"
            placeholder="ALM-02"
            value={form.codigo}
            onChange={(e) => setForm({ ...form, codigo: e.target.value.toUpperCase() })}
          />
          <Input
            label="Nombre"
            placeholder="Depósito norte"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />
          <Input
            label="Dirección"
            optional
            value={form.direccion}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />
          <div>
            <Checkbox
              label="Almacén principal"
              checked={form.esPrincipal}
              onChange={(e) => setForm({ ...form, esPrincipal: e.target.checked })}
            />
            <p className="mt-1 text-xs text-ink-soft">
              Solo uno puede serlo: es el que sale por defecto en pedidos y ventas, y del que se muestra
              el stock al buscar productos. Marcarlo aquí desmarca al anterior.
            </p>
          </div>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
