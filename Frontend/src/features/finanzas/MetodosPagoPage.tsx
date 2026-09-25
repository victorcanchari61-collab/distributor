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
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { metodoPagoApi } from './finanzasApi'
import type { MetodoPagoResponse, TipoMetodoPago } from './finanzasApi'
import { cuentaFinancieraApi } from './cuentaFinancieraApi'
import type { CuentaFinancieraResponse } from './cuentaFinancieraApi'

const TIPOS: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

const VACIO = {
  nombre: '',
  tipo: 'BILLETERA_DIGITAL' as TipoMetodoPago,
  numero: '',
  cuentaFinancieraId: 0,
}

/**
 * Métodos de pago: efectivo, billetera digital, transferencia... Catálogo
 * compartido por compras, cuentas por cobrar, cuentas por pagar, mis cobros y
 * Mi Caja — se declara una vez aquí y todos lo reusan.
 *
 * Es solo un CANAL, no una cuenta con saldo: la plata de verdad vive en la
 * Cuenta Financiera a la que apunta (ver Bancos). Efectivo es la excepción —
 * es único y fijo, no se crea otro ni se edita — porque no apunta a ninguna
 * cuenta en concreto: se resuelve según quién cobra.
 */
export function MetodosPagoPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [metodos, setMetodos] = useState<MetodoPagoResponse[]>([])
  const [cuentas, setCuentas] = useState<CuentaFinancieraResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MetodoPagoResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [m, c] = await Promise.all([metodoPagoApi.getAll(), cuentaFinancieraApi.getAll()])
      setMetodos(m)
      setCuentas(c)
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

  useRealtime(['metodospago', 'cuentasfinancieras'], cargar)

  // A qué cuenta puede apuntar un método: bancos y pasarelas, nunca la Caja
  // General (esa es Efectivo, y Efectivo no elige cuenta).
  const cuentasElegibles = cuentas.filter((c) => c.naturaleza !== 'CAJA' && c.activo)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setAbierto(true)
  }

  const abrirEdicion = (m: MetodoPagoResponse) => {
    setEditando(m)
    setForm({
      nombre: m.nombre,
      tipo: m.tipo,
      numero: m.numero ?? '',
      cuentaFinancieraId: m.cuentaFinancieraId ?? 0,
    })
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ingresa el nombre.')
    if (form.tipo === 'BILLETERA_DIGITAL' && !form.numero.trim()) {
      return toast.error('Indica el número asociado a esta billetera.')
    }
    if (form.tipo !== 'EFECTIVO' && !form.cuentaFinancieraId) {
      return toast.error('Elige a qué cuenta financiera va este método.')
    }

    setGuardando(true)
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        tipo: form.tipo,
        numero: form.tipo === 'BILLETERA_DIGITAL' ? form.numero.trim() : null,
        cuentaFinancieraId: form.tipo === 'EFECTIVO' ? null : form.cuentaFinancieraId,
      }
      if (editando) {
        await metodoPagoApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      } else {
        await metodoPagoApi.create(cuerpo)
      }
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Método actualizado' : 'Método creado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el método de pago.')
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
            numero: m.numero,
            cuentaFinancieraId: m.cuentaFinancieraId,
            activo: !m.activo,
          })
          await cargar()
          toast.exito(`${m.nombre} ${m.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<MetodoPagoResponse>[] = [
    // El nombre se busca con el buscador de arriba, no en el panel.
    { key: 'nombre', label: 'Nombre', filterable: false },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: TIPOS,
      // El filtro compara contra el valor crudo, no contra la etiqueta del Badge.
      value: (row) => row.tipo,
      render: (row) => <Badge>{TIPOS.find((t) => t.value === row.tipo)?.label ?? row.tipo}</Badge>,
    },
    {
      key: 'numero',
      label: 'Número',
      filterable: false,
      render: (row) => row.numero ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'cuentaFinanciera',
      label: 'Cuenta',
      filterType: 'select',
      filterOptions: [...new Set(metodos.map((m) => m.cuentaFinanciera).filter((v): v is string => !!v))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((v) => ({ value: v, label: v })),
      render: (row) => row.cuentaFinanciera ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      // Las opciones son las etiquetas porque `value` ya expone la fila asi.
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
      icon={<Coins size={20} />}
      title="Métodos de pago"
      description="Efectivo, billetera digital, transferencia... el mismo catálogo lo usan ventas, compras y cuentas por cobrar y por pagar."
      actions={
        puede('finanzas.metodospago', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo método
          </Button>
        ) : undefined
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
      note="Efectivo es fijo: no se crea otro, no se edita ni se desactiva — se resuelve según quién cobra, no apunta a ninguna cuenta."
      rowActions={(row) => (
        <>
          {puede('finanzas.metodospago', 'editar') && (
            <RowAction
              label={`Editar ${row.nombre}`}
              disabled={row.tipo === 'EFECTIVO'}
              disabledReason="Efectivo es fijo"
              onClick={() => abrirEdicion(row)}
            >
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('finanzas.metodospago', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              disabled={row.tipo === 'EFECTIVO'}
              disabledReason="Efectivo es fijo"
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
          <Desplegable
            label="Tipo"
            value={form.tipo}
            onChange={(v) => setForm({ ...form, tipo: v as TipoMetodoPago })}
            // Efectivo ya existe y es único: no se ofrece para crear uno nuevo.
            options={TIPOS.filter((t) => t.value !== 'EFECTIVO')}
          />

          <Input
            label="Nombre"
            placeholder="Yape, Plin, BCP Cuenta Corriente..."
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          {form.tipo === 'BILLETERA_DIGITAL' && (
            <Input
              label="Número"
              placeholder="999 999 999"
              value={form.numero}
              onChange={(e) => setForm({ ...form, numero: e.target.value })}
            />
          )}

          <Desplegable
            label="Cuenta financiera"
            value={form.cuentaFinancieraId}
            onChange={(v) => setForm({ ...form, cuentaFinancieraId: Number(v) })}
            placeholder="A qué cuenta va la plata"
            hint={
              cuentasElegibles.length === 0 ? (
                <span className="text-xs text-amber-600">Crea una cuenta en Bancos primero</span>
              ) : undefined
            }
            options={cuentasElegibles.map((c) => ({
              value: c.id,
              label: c.nombre,
              detalle: c.numeroCuenta ?? undefined,
            }))}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
