import { useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { motivoApi } from './inventarioApi'
import type { MotivoResponse, TipoMovimiento } from './inventarioApi'

const VACIO = { codigo: '', nombre: '', tipo: 'ENTRADA' as TipoMovimiento }

/**
 * Motivos de un ajuste: carga inicial, merma, sobrante...
 *
 * Los motivos DEL SISTEMA (venta, compra, sus anulaciones) no aparecen para
 * editar ni eliminar: los usa cada documento que ya existe en el historial, y
 * cambiarles el signo o el código descuadraría todo lo que mueven. Solo se
 * gestionan aquí los manuales, que es lo único que un ajuste puede usar.
 */
export function MotivosTabla({
  motivos,
  onRecargar,
}: {
  motivos: MotivoResponse[]
  onRecargar: () => Promise<void>
}) {
  // Solo manuales: los del sistema (venta, compra, sus anulaciones) no se
  // listan aqui en absoluto, ni en la tabla ni en el pie.
  const manuales = motivos.filter((m) => !m.delSistema)

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MotivoResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (m: MotivoResponse) => {
    setEditando(m)
    setForm({ codigo: m.codigo, nombre: m.nombre, tipo: m.tipo })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.codigo.trim()) return setErrorForm('Ingresa el código.')
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    try {
      const cuerpo = { codigo: form.codigo.trim(), nombre: form.nombre.trim(), tipo: form.tipo }
      if (editando) {
        await motivoApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      } else {
        await motivoApi.create(cuerpo)
      }
      setAbierto(false)
      await onRecargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el motivo.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (m: MotivoResponse) =>
    confirmar({
      titulo: `${m.activo ? 'Desactivar' : 'Activar'} ${m.nombre}`,
      mensaje: m.activo
        ? 'Deja de ofrecerse al registrar un ajuste nuevo. Los documentos que ya lo usan lo conservan.'
        : 'Vuelve a estar disponible para ajustes nuevos.',
      confirmar: m.activo ? 'Desactivar' : 'Activar',
      tono: m.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await motivoApi.update(m.id, {
            codigo: m.codigo,
            nombre: m.nombre,
            tipo: m.tipo,
            activo: !m.activo,
          })
          await onRecargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const eliminar = (m: MotivoResponse) =>
    confirmar({
      titulo: `Eliminar ${m.nombre}`,
      mensaje:
        m.movimientos > 0
          ? `Lo usan ${m.movimientos} movimiento(s), así que no se podrá eliminar. Desactívalo en su lugar.`
          : 'Se borra definitivamente.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await motivoApi.remove(m.id)
          await onRecargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el motivo.')
        }
      },
    })

  const columnaTipo = (row: MotivoResponse) => (
    <Badge tone={row.tipo === 'ENTRADA' ? 'success' : 'warning'}>
      {row.tipo === 'ENTRADA' ? 'Ingreso' : 'Salida'}
    </Badge>
  )

  const columns: DataTableColumn<MotivoResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'codigo', label: 'Código', render: (row) => <Badge>{row.codigo}</Badge> },
    { key: 'tipo', label: 'Tipo', render: columnaTipo },
    {
      key: 'pideCosto',
      label: 'Pide costo',
      value: (row) => (row.pideCosto ? 'Sí' : 'No'),
      render: (row) => (row.pideCosto ? 'Sí' : <span className="text-ink-soft">No</span>),
    },
    { key: 'movimientos', label: 'Movimientos', align: 'right' },
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
      icon={<Plus size={20} />}
      title="Motivos"
      description="Los que puedes elegir al registrar un ajuste. Venta, compra y sus anulaciones los crea su propio documento: no se listan aquí."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo motivo
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      columns={columns}
      rows={manuales}
      searchPlaceholder="Buscar motivo..."
      empty="Todavía no hay motivos manuales."
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
            <Badge tone={row.activo ? 'warning' : 'success'}>{row.activo ? 'Off' : 'On'}</Badge>
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
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo motivo'}
        description="Suma o resta stock según el tipo. Las entradas piden costo; las salidas lo heredan del stock que sale."
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
          {errorForm && <Alert>{errorForm}</Alert>}

          <div className="grid gap-4 sm:grid-cols-[8rem_1fr]">
            <Input
              label="Código"
              placeholder="PRESTAMO"
              value={form.codigo}
              onChange={(e) => setForm({ ...form, codigo: e.target.value.toUpperCase() })}
            />
            <Input
              label="Nombre"
              placeholder="Préstamo a otra bodega"
              value={form.nombre}
              onChange={(e) => setForm({ ...form, nombre: e.target.value })}
            />
          </div>

          <Desplegable
            label="Tipo"
            value={form.tipo}
            onChange={(v) => setForm({ ...form, tipo: v as TipoMovimiento })}
            options={[
              { value: 'ENTRADA', label: 'Ingreso', nota: 'suma stock, pide costo' },
              { value: 'SALIDA', label: 'Salida', nota: 'resta stock, hereda el costo' },
            ]}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
