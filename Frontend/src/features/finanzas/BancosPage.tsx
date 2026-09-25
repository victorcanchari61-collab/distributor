import { useCallback, useEffect, useState } from 'react'
import { Landmark, Pencil, Plus, ShieldCheck, ShieldOff } from 'lucide-react'
import { Alert, Badge, Button, Input, ListPage, Modal, RowAction, StatCard, useConfirmacion, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { bancoApi } from './bancoApi'
import type { BancoResponse } from './bancoApi'

const VACIO = { nombre: '', activo: true }

/**
 * El catálogo de bancos (BBVA, BCP, Interbank...): entidades propias, sin
 * saldo. Cada una puede tener varias cuentas bancarias — esas sí tienen
 * saldo, y viven en la pestaña "Cuentas Bancarias".
 */
export function BancosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [bancos, setBancos] = useState<BancoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<BancoResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setBancos(await bancoApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los bancos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('bancos', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setAbierto(true)
  }

  const abrirEdicion = (b: BancoResponse) => {
    setEditando(b)
    setForm({ nombre: b.nombre, activo: b.activo })
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ponle un nombre al banco.')

    setGuardando(true)
    try {
      const cuerpo = { nombre: form.nombre.trim(), activo: form.activo }
      if (editando) await bancoApi.update(editando.id, cuerpo)
      else await bancoApi.create(cuerpo)

      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Banco actualizado' : 'Banco creado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el banco.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (b: BancoResponse) =>
    confirmar({
      titulo: `${b.activo ? 'Desactivar' : 'Activar'} ${b.nombre}`,
      mensaje: b.activo
        ? 'Deja de ofrecerse para crear cuentas bancarias nuevas. Las cuentas ya creadas se conservan.'
        : 'Vuelve a estar disponible para crear cuentas bancarias.',
      confirmar: b.activo ? 'Desactivar' : 'Activar',
      tono: b.activo ? 'warning' : 'pregunta',
      accion: async () => {
        try {
          await bancoApi.update(b.id, { nombre: b.nombre, activo: !b.activo })
          await cargar()
          toast.exito(`${b.nombre} ${b.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<BancoResponse>[] = [
    { key: 'nombre', label: 'Nombre', filterable: false },
    { key: 'cantidadCuentas', label: 'Cuentas', align: 'right', filterable: false },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<Landmark size={20} />}
      title="Bancos"
      description="El catálogo de bancos: BBVA, BCP, Interbank... De cada uno cuelgan sus cuentas bancarias."
      actions={
        puede('finanzas.bancos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo banco
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <StatCard label="Bancos activos" value={String(bancos.filter((b) => b.activo).length)} icon={<Landmark size={18} />} tono="sys" />
      }
      columns={columns}
      rows={bancos}
      cardIcon={Landmark}
      searchPlaceholder="Buscar banco..."
      empty={cargando ? 'Cargando bancos...' : 'Todavía no hay bancos registrados.'}
      rowActions={(row) => (
        <>
          {puede('finanzas.bancos', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('finanzas.bancos', 'editar') && (
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
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo banco'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear banco'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <Input
            label="Nombre"
            placeholder="BCP, Interbank, BBVA..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
