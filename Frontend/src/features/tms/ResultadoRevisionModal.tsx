import { useEffect, useState } from 'react'
import { Button, Checkbox, Input, Modal, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { resultadoRevisionApi } from './motivoNovedadApi'
import type { ResultadoRevisionRequest, ResultadoRevisionResponse } from './motivoNovedadApi'

const VACIO: ResultadoRevisionRequest = { nombre: '', descripcion: '', volvioTodo: false, activo: true }

/**
 * Crear o editar un resultado de la revisión. Lo usan el catálogo (Motivos de
 * novedad → Resultados) y el "+" de la ventana Revisar, para crearlo sin salir.
 */
export function ResultadoRevisionModal({
  abierto,
  editando,
  onClose,
  onGuardado,
}: {
  abierto: boolean
  /** Null para uno nuevo. */
  editando: ResultadoRevisionResponse | null
  onClose: () => void
  onGuardado: (resultado: ResultadoRevisionResponse) => void | Promise<void>
}) {
  const toast = useToast()
  const [form, setForm] = useState<ResultadoRevisionRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)

  useEffect(() => {
    if (!abierto) return
    setForm(
      editando
        ? {
            nombre: editando.nombre,
            descripcion: editando.descripcion ?? '',
            volvioTodo: editando.volvioTodo,
            activo: editando.activo,
          }
        : VACIO,
    )
  }, [abierto, editando])

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ponle un nombre al resultado.')

    setGuardando(true)
    try {
      const cuerpo = { ...form, nombre: form.nombre.trim(), descripcion: form.descripcion?.trim() || null }
      const guardado = editando
        ? await resultadoRevisionApi.update(editando.id, cuerpo)
        : await resultadoRevisionApi.create(cuerpo)
      toast.exito(editando ? 'Resultado actualizado' : 'Resultado creado')
      await onGuardado(guardado)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el resultado.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open={abierto}
      size="sm"
      title={editando ? `Editar ${editando.nombre}` : 'Nuevo resultado'}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            {editando ? 'Guardar' : 'Crear'}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Input
          label="Nombre"
          maxLength={60}
          placeholder="Pesaron mal el producto"
          value={form.nombre}
          onChange={(e) => setForm({ ...form, nombre: e.target.value })}
        />
        <Input
          label="Descripción"
          optional
          maxLength={250}
          value={form.descripcion ?? ''}
          onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
        />
        <Checkbox
          label="Volvió todo lo que no se entregó"
          checked={form.volvioTodo}
          disabled={!!editando && editando.usos > 0}
          onChange={(e) => setForm({ ...form, volvioTodo: e.target.checked })}
        />
      </div>
    </Modal>
  )
}
