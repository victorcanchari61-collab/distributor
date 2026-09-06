import { useState } from 'react'
import type { ReactNode } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'

/** Lo minimo que tiene una fila de catalogo simple. */
export interface FilaCatalogo {
  id: number
  nombre: string
  descripcion?: string | null
  activo: boolean
  productos: number
}

export interface CatalogoSimpleProps {
  titulo: string
  descripcion: string
  icono: ReactNode
  filas: FilaCatalogo[]
  /** Muestra y edita el campo descripcion. Marcas no lo tienen. */
  conDescripcion?: boolean
  /** Encabezado de la columna de uso. Por defecto "Productos". */
  usosEtiqueta?: string
  /** Palabra en singular para el mensaje de "no se puede eliminar". Por defecto "producto". */
  usosSingular?: string
  onCrear: (datos: { nombre: string; descripcion?: string | null }) => Promise<unknown>
  onActualizar: (
    id: number,
    datos: { nombre: string; descripcion?: string | null; activo: boolean },
  ) => Promise<unknown>
  onEliminar: (id: number) => Promise<unknown>
  onRecargar: () => Promise<void>
}

/**
 * Tabla de un catalogo de nombre y poco mas: categorias y marcas.
 *
 * Las dos son la misma pantalla con distinto titulo, asi que viven en un solo
 * componente. Si mañana el diseño de estas tablas cambia, se cambia aqui.
 */
export function CatalogoSimple({
  titulo,
  descripcion,
  icono,
  filas,
  conDescripcion,
  usosEtiqueta = 'Productos',
  usosSingular = 'producto',
  onCrear,
  onActualizar,
  onEliminar,
  onRecargar,
}: CatalogoSimpleProps) {
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<FilaCatalogo | null>(null)
  const [form, setForm] = useState({ nombre: '', descripcion: '' })
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ nombre: '', descripcion: '' })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (fila: FilaCatalogo) => {
    setEditando(fila)
    setForm({ nombre: fila.nombre, descripcion: fila.descripcion ?? '' })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    try {
      const datos = {
        nombre: form.nombre.trim(),
        descripcion: conDescripcion ? form.descripcion.trim() || null : undefined,
      }

      if (editando) {
        await onActualizar(editando.id, { ...datos, activo: editando.activo })
      } else {
        await onCrear(datos)
      }

      setAbierto(false)
      await onRecargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (fila: FilaCatalogo) =>
    confirmar({
      titulo: `${fila.activo ? 'Desactivar' : 'Activar'} ${fila.nombre}`,
      mensaje: fila.activo
        ? 'Deja de ofrecerse al dar de alta productos. Los que ya la usan la conservan.'
        : 'Vuelve a estar disponible.',
      confirmar: fila.activo ? 'Desactivar' : 'Activar',
      tono: fila.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await onActualizar(fila.id, {
            nombre: fila.nombre,
            descripcion: fila.descripcion,
            activo: !fila.activo,
          })
          await onRecargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const eliminar = (fila: FilaCatalogo) =>
    confirmar({
      titulo: `Eliminar ${fila.nombre}`,
      mensaje:
        fila.productos > 0
          ? `La usan ${fila.productos} ${usosSingular}(s), así que no se podrá eliminar. Desactívala en su lugar.`
          : 'Se borra definitivamente.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await onEliminar(fila.id)
          await onRecargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar.')
        }
      },
    })

  const columns: DataTableColumn<FilaCatalogo>[] = [
    { key: 'nombre', label: 'Nombre' },
    ...(conDescripcion
      ? [
          {
            key: 'descripcion',
            label: 'Descripción',
            render: (row: FilaCatalogo) =>
              row.descripcion ?? <span className="text-ink-soft">—</span>,
          },
        ]
      : []),
    { key: 'productos', label: usosEtiqueta, align: 'right' as const },
    {
      key: 'activo',
      label: 'Estado',
      value: (row: FilaCatalogo) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row: FilaCatalogo) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>
          {row.activo ? 'Activo' : 'Inactivo'}
        </Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={icono}
      title={titulo}
      description={descripcion}
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      columns={columns}
      rows={filas}
      searchPlaceholder="Buscar..."
      empty="Todavía no hay registros."
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
        title={editando ? `Editar ${editando.nombre}` : `Nuevo en ${titulo.toLowerCase()}`}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          {conDescripcion && (
            <Input
              label="Descripción"
              optional
              value={form.descripcion}
              onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
            />
          )}
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
