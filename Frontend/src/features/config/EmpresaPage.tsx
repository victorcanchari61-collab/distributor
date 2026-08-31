import { useCallback, useEffect, useState } from 'react'
import { Building2, CheckCircle2, Circle, Pencil, Plus, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { empresaApi } from './empresaApi'
import type { EmpresaRequest, EmpresaResponse } from './empresaApi'

const VACIA: EmpresaRequest = {
  razonSocial: '',
  nombreComercial: '',
  ruc: '',
  direccion: '',
  telefono: '',
  email: '',
  activa: false,
}

export function EmpresaPage() {
  const [empresas, setEmpresas] = useState<EmpresaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<EmpresaResponse | null>(null)
  const [abierto, setAbierto] = useState(false)
  const [form, setForm] = useState<EmpresaRequest>(VACIA)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setEmpresas(await empresaApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las empresas.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const abrirNueva = () => {
    setEditando(null)
    setForm({ ...VACIA, activa: empresas.length === 0 })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (empresa: EmpresaResponse) => {
    setEditando(empresa)
    setForm({
      razonSocial: empresa.razonSocial,
      nombreComercial: empresa.nombreComercial,
      ruc: empresa.ruc,
      direccion: empresa.direccion ?? '',
      telefono: empresa.telefono ?? '',
      email: empresa.email ?? '',
      activa: empresa.activa,
    })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    setGuardando(true)
    setErrorForm('')
    try {
      if (editando) await empresaApi.update(editando.id, form)
      else await empresaApi.create(form)
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la empresa.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const activar = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await empresaApi.activar(empresa.id)
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos activar la empresa.')
    }
  }

  const eliminar = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await empresaApi.remove(empresa.id)
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos eliminar la empresa.')
    }
  }

  const activa = empresas.find((e) => e.activa)

  const columns: DataTableColumn<EmpresaResponse>[] = [
    { key: 'razonSocial', label: 'Razón social' },
    { key: 'nombreComercial', label: 'Nombre comercial' },
    { key: 'ruc', label: 'RUC' },
    { key: 'telefono', label: 'Teléfono' },
    {
      key: 'activa',
      label: 'Estado',
      value: (row) => (row.activa ? 'Activa' : 'Inactiva'),
      render: (row) =>
        row.activa ? <Badge tone="success">Activa</Badge> : <Badge>Inactiva</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<Building2 size={20} />}
      title="Empresas"
      description="Puedes registrar varias, pero solo una opera el sistema a la vez."
      actions={
        <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
          Nueva empresa
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        activa ? (
          <div className="flex flex-wrap items-center gap-3 rounded-panel border border-[rgb(var(--sys-rgb)/0.3)] bg-[rgb(var(--sys-rgb)/0.06)] p-4">
            <CheckCircle2 size={20} className="shrink-0 text-[rgb(var(--sys-ink-rgb))]" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink">Operando como {activa.nombreComercial}</p>
              <p className="truncate text-xs text-ink-muted">
                {activa.razonSocial} · RUC {activa.ruc}
              </p>
            </div>
          </div>
        ) : undefined
      }
      columns={columns}
      rows={empresas}
      cardIcon={Building2}
      searchPlaceholder="Buscar por razón social o RUC..."
      empty={cargando ? 'Cargando empresas...' : 'Todavía no hay empresas registradas.'}
      rowActions={(row) => (
        <>
          {!row.activa && (
            <RowAction label={`Activar ${row.nombreComercial}`} onClick={() => void activar(row)}>
              <Circle size={15} />
            </RowAction>
          )}
          <RowAction label={`Editar ${row.nombreComercial}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          {!row.activa && (
            <RowAction
              label={`Eliminar ${row.nombreComercial}`}
              tone="danger"
              onClick={() => void eliminar(row)}
            >
              <Trash2 size={15} />
            </RowAction>
          )}
        </>
      )}
      note="La empresa activa no se puede eliminar ni desactivar: para cambiarla, activa otra."
    >
      <Modal
        open={abierto}
        title={editando ? 'Editar empresa' : 'Nueva empresa'}
        description="Estos datos aparecen en documentos y reportes."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear empresa'}
            </Button>
          </>
        }
      >
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {errorForm && (
            <div className="sm:col-span-2">
              <Alert>{errorForm}</Alert>
            </div>
          )}

          <Input
            label="Razón social"
            className="sm:col-span-2"
            value={form.razonSocial}
            onChange={(e) => setForm({ ...form, razonSocial: e.target.value })}
          />
          <Input
            label="Nombre comercial"
            value={form.nombreComercial}
            onChange={(e) => setForm({ ...form, nombreComercial: e.target.value })}
          />
          <Input
            label="RUC"
            inputMode="numeric"
            maxLength={11}
            value={form.ruc}
            onChange={(e) => setForm({ ...form, ruc: e.target.value.replace(/\D/g, '') })}
          />
          <Input
            label="Dirección fiscal"
            className="sm:col-span-2"
            value={form.direccion ?? ''}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />
          <Input
            label="Teléfono"
            value={form.telefono ?? ''}
            onChange={(e) => setForm({ ...form, telefono: e.target.value })}
          />
          <Input
            label="Correo"
            type="email"
            value={form.email ?? ''}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />

          {/* Desactivar desde aqui no se permite: el backend obliga a activar otra. */}
          {!form.activa && (
            <label className="flex cursor-pointer items-center gap-2 text-sm text-ink-muted sm:col-span-2">
              <input
                type="checkbox"
                checked={form.activa}
                onChange={(e) => setForm({ ...form, activa: e.target.checked })}
                className="size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
              />
              Dejar esta empresa como la activa del sistema
            </label>
          )}
        </div>
      </Modal>
    </ListPage>
  )
}

