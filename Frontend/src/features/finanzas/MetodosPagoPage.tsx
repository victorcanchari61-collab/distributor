import { useCallback, useEffect, useState } from 'react'
import { Coins, Pencil, Plus, ShieldCheck, ShieldOff } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
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
import type { MetodoPagoResponse, TipoMetodoPago } from './finanzasApi'

const TIPOS: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

const VACIO = {
  nombre: '',
  tipo: 'EFECTIVO' as TipoMetodoPago,
  banco: '',
  numeroCuenta: '',
  cci: '',
  titular: '',
}

/** "BCP · 191-123456789", o solo el número si no tiene banco (billetera). */
function textoCuenta(m: MetodoPagoResponse) {
  if (m.tipo === 'EFECTIVO') return null
  if (!m.numeroCuenta) return null
  return m.banco ? `${m.banco} · ${m.numeroCuenta}` : m.numeroCuenta
}

/**
 * Métodos de pago: efectivo, billetera digital, transferencia... Catálogo
 * compartido por compras, cuentas por cobrar, cuentas por pagar, mis cobros y
 * el arqueo diario — se declara una vez aquí y todos lo reusan.
 *
 * El efectivo no identifica nada más; billetera digital y transferencia sí
 * apuntan a una cuenta concreta (banco, número, titular) — "Transferencia" a
 * secas no dice a qué cuenta va la plata.
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
    setForm({
      nombre: m.nombre,
      tipo: m.tipo,
      banco: m.banco ?? '',
      numeroCuenta: m.numeroCuenta ?? '',
      cci: m.cci ?? '',
      titular: m.titular ?? '',
    })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')
    if (form.tipo === 'TRANSFERENCIA' && !form.banco.trim()) return setErrorForm('Indica el banco.')
    if (form.tipo !== 'EFECTIVO' && !form.numeroCuenta.trim()) {
      return setErrorForm(
        form.tipo === 'TRANSFERENCIA' ? 'Indica el número de cuenta.' : 'Indica el número de celular.',
      )
    }

    setGuardando(true)
    try {
      const conCuenta = form.tipo !== 'EFECTIVO'
      const cuerpo = {
        nombre: form.nombre.trim(),
        tipo: form.tipo,
        banco: form.tipo === 'TRANSFERENCIA' ? form.banco.trim() || null : null,
        numeroCuenta: conCuenta ? form.numeroCuenta.trim() || null : null,
        cci: form.tipo === 'TRANSFERENCIA' ? form.cci.trim() || null : null,
        titular: conCuenta ? form.titular.trim() || null : null,
      }
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
          await metodoPagoApi.update(m.id, {
            nombre: m.nombre,
            tipo: m.tipo,
            banco: m.banco,
            numeroCuenta: m.numeroCuenta,
            cci: m.cci,
            titular: m.titular,
            activo: !m.activo,
          })
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<MetodoPagoResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    {
      key: 'tipo',
      label: 'Tipo',
      render: (row) => <Badge>{TIPOS.find((t) => t.value === row.tipo)?.label ?? row.tipo}</Badge>,
    },
    {
      key: 'numeroCuenta',
      label: 'Cuenta',
      render: (row) => textoCuenta(row) ?? <span className="text-ink-soft">—</span>,
    },
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
      description="Efectivo, billetera digital, transferencia... el mismo catálogo lo usan compras, cuentas por cobrar y por pagar, mis cobros y el arqueo diario."
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

          <Desplegable
            label="Tipo"
            value={form.tipo}
            onChange={(v) => setForm({ ...form, tipo: v as TipoMetodoPago })}
            options={TIPOS}
          />

          <Input
            label="Nombre"
            placeholder="Yape, Plin, BCP Cuenta Corriente..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          {form.tipo === 'TRANSFERENCIA' && (
            <Input
              label="Banco"
              placeholder="BCP, Interbank, BBVA..."
              value={form.banco}
              onChange={(e) => setForm({ ...form, banco: e.target.value })}
            />
          )}

          {form.tipo !== 'EFECTIVO' && (
            <Input
              label={form.tipo === 'TRANSFERENCIA' ? 'Número de cuenta' : 'Número de celular'}
              value={form.numeroCuenta}
              onChange={(e) => setForm({ ...form, numeroCuenta: e.target.value })}
            />
          )}

          {form.tipo === 'TRANSFERENCIA' && (
            <Input
              label="CCI"
              optional
              placeholder="Código de cuenta interbancario"
              value={form.cci}
              onChange={(e) => setForm({ ...form, cci: e.target.value })}
            />
          )}

          {form.tipo !== 'EFECTIVO' && (
            <Input
              label="Titular"
              optional
              placeholder="A nombre de quién está"
              value={form.titular}
              onChange={(e) => setForm({ ...form, titular: e.target.value })}
            />
          )}
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
