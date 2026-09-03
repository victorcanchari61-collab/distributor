import { useCallback, useEffect, useState } from 'react'
import { Coins, Pencil, Plus, ShieldCheck, ShieldOff } from 'lucide-react'
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
import { useRealtime } from '../../lib/realtime'
import { metodoPagoApi } from './finanzasApi'
import type { MetodoPagoResponse } from './finanzasApi'

const VACIO = { nombre: '' }

/**
 * Métodos de pago: efectivo, transferencia, tarjeta... Catálogo compartido
 * por compras, cuentas por cobrar, cuentas por pagar, mis cobros y el arqueo
 * diario — se declara una vez aquí y todos lo reusan.
 */
export function MetodosPagoPage() {
  const [metodos, setMetodos] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MetodoPagoResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setMetodos(await metodoPagoApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los métodos de pago.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('metodospago', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (m: MetodoPagoResponse) => {
    setEditando(m)
    setForm({ nombre: m.nombre })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    try {
      const cuerpo = { nombre: form.nombre.trim() }
      if (editando) {
        await metodoPagoApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      } else {
        await metodoPagoApi.create(cuerpo)
      }
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el método de pago.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (m: MetodoPagoResponse) =>
    confirmar({
      titulo: `${m.activo ? 'Desactivar' : 'Activar'} ${m.nombre}`,
      mensaje: m.activo
        ? 'Deja de ofrecerse en compras, cobros y pagos nuevos. Lo ya registrado se conserva.'
        : 'Vuelve a estar disponible para elegirse.',
      confirmar: m.activo ? 'Desactivar' : 'Activar',
      tono: m.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await metodoPagoApi.update(m.id, { nombre: m.nombre, activo: !m.activo })
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<MetodoPagoResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'usos', label: 'En uso', align: 'right', render: (row) => `${row.usos}` },
    {
      key: 'activo',
      label: 'Estado',
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Coins size={20} />}
      title="Métodos de pago"
      description="Efectivo, transferencia, tarjeta... el mismo catálogo lo usan compras, cuentas por cobrar y por pagar, mis cobros y el arqueo diario."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo método
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <StatCard label="Métodos de pago" value={String(metodos.length)} icon={<Coins size={18} />} />
      }
      columns={columns}
      rows={metodos}
      cardIcon={Coins}
      searchPlaceholder="Buscar método de pago..."
      empty={cargando ? 'Cargando métodos de pago...' : 'Todavía no hay métodos de pago.'}
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
            {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
          </RowAction>
        </>
      )}
    >
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo método de pago'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear método'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}
          <Input
            label="Nombre"
            placeholder="Yape, Plin, Transferencia BCP..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
