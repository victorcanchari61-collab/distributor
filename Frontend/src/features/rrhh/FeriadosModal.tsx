import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import {
  Button,
  Input,
  Modal,
  RowAction,
  SysDataTable,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { feriadoApi } from './feriadoApi'
import type { FeriadoResponse } from './feriadoApi'

interface Props {
  open: boolean
  onClose: () => void
}

/**
 * Días no laborables. Quien trabaja uno cobra ese día doble en la planilla.
 * Se administra desde el mismo lugar
 * donde se usa —el calendario de Asistencia— y no tiene entrada propia en el
 * menú: es una lista corta que se toca un par de veces al año.
 */
export function FeriadosModal({ open, onClose }: Props) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [feriados, setFeriados] = useState<FeriadoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [editando, setEditando] = useState<FeriadoResponse | null>(null)
  const [agregando, setAgregando] = useState(false)
  const [form, setForm] = useState({ fecha: hoyLocal(), nombre: '' })
  const [guardando, setGuardando] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setFeriados(await feriadoApi.getAll())
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los feriados.')
    } finally {
      setCargando(false)
    }
  }, [toast])

  useEffect(() => {
    if (open) void cargar()
  }, [open, cargar])

  useRealtime('feriados', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ fecha: hoyLocal(), nombre: '' })
    setAgregando(true)
  }

  const abrirEdicion = (feriado: FeriadoResponse) => {
    setEditando(feriado)
    setForm({ fecha: feriado.fecha.slice(0, 10), nombre: feriado.nombre })
    setAgregando(true)
  }

  const guardar = async () => {
    if (!form.fecha) return toast.error('Elige la fecha.')
    if (!form.nombre.trim()) return toast.error('Ingresa el nombre del feriado.')

    setGuardando(true)
    try {
      const cuerpo = { fecha: form.fecha, nombre: form.nombre.trim() }
      if (editando) await feriadoApi.update(editando.id, cuerpo)
      else await feriadoApi.create(cuerpo)
      setAgregando(false)
      await cargar()
      toast.exito(editando ? 'Feriado actualizado' : 'Feriado registrado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el feriado.')
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (feriado: FeriadoResponse) =>
    confirmar({
      titulo: `Eliminar ${feriado.nombre}`,
      mensaje: `Deja de marcarse en el calendario. No afecta las asistencias ya registradas ese día.`,
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        try {
          await feriadoApi.remove(feriado.id)
          await cargar()
          toast.exito('Feriado eliminado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos eliminar el feriado.')
        }
      },
    })

  const columns: DataTableColumn<FeriadoResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterable: false, render: (row) => fechaCorta(row.fecha) },
    { key: 'nombre', label: 'Nombre', filterable: false },
  ]

  return (
    <Modal open={open} title="Feriados" description="Días no laborables. Si alguien trabaja un feriado, en la planilla se le paga ese día doble." onClose={onClose} size="lg">
      <div className="space-y-4">
        {agregando ? (
          <div className="space-y-3 rounded-field border border-line bg-surface-alt p-3">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <Input
                label="Fecha"
                type="date"
                value={form.fecha}
                onChange={(e) => setForm({ ...form, fecha: e.target.value })}
              />
              <Input
                label="Nombre"
                className="sm:col-span-2"
                placeholder="Ej. Día del Trabajo"
                value={form.nombre}
                onChange={(e) => setForm({ ...form, nombre: e.target.value })}
              />
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="secondary" size="sm" onClick={() => setAgregando(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardar()}>
                {editando ? 'Guardar cambios' : 'Agregar'}
              </Button>
            </div>
          </div>
        ) : (
          puede('rrhh.asistencia', 'crear') && (
            <Button size="sm" variant="secondary" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
              Nuevo feriado
            </Button>
          )
        )}

        <SysDataTable
          columns={columns}
          rows={feriados}
          toolbar={false}
          paginacion={false}
          empty={cargando ? 'Cargando feriados...' : 'Todavía no hay feriados registrados.'}
          actions={(row) => (
            <>
              {puede('rrhh.asistencia', 'editar') && (
                <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
                  <Pencil size={15} />
                </RowAction>
              )}
              {puede('rrhh.asistencia', 'eliminar') && (
                <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
                  <Trash2 size={15} />
                </RowAction>
              )}
            </>
          )}
        />
      </div>

      {dialogo}
    </Modal>
  )
}
