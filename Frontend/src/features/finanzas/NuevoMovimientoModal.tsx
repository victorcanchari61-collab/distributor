import { useState } from 'react'
import { Alert, Button, Desplegable, Input, Modal } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { hoyLocal } from '../../lib/fechas'
import { gastoOperativoApi, origenLabel } from './gastoOperativoApi'
import type { CategoriaOpcion, TipoMovimientoOperativo } from './gastoOperativoApi'
import type { CuentaMovimiento } from './movimientoDineroApi'

const NATURALEZA: Record<string, string> = { CAJA: 'Caja', BANCO: 'Banco', PASARELA: 'Pasarela' }

/**
 * Un ingreso o egreso registrado a mano: un aporte de capital, un gasto sin
 * plantilla. Las categorías del sistema (ventas, préstamos, planilla) no salen:
 * esas se registran solas en su módulo.
 */
export function NuevoMovimientoModal({
  cuentas,
  categorias,
  onClose,
  onGuardado,
}: {
  cuentas: CuentaMovimiento[]
  categorias: CategoriaOpcion[]
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [tipo, setTipo] = useState<TipoMovimientoOperativo>('EGRESO')
  const [cuentaFinancieraId, setCuentaFinancieraId] = useState(0)
  const [motivoGastoId, setMotivoGastoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [fecha, setFecha] = useState(hoyLocal())
  const [descripcion, setDescripcion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const numero = Number(monto.replace(',', '.'))
    if (!cuentaFinancieraId) return setError('Elige la cuenta.')
    if (!motivoGastoId) return setError('Elige la categoría.')
    if (!Number.isFinite(numero) || numero <= 0) return setError('Ingresa un monto mayor a cero.')

    setGuardando(true)
    setError('')
    try {
      await gastoOperativoApi.crear({
        cuentaFinancieraId,
        tipo,
        motivoGastoId,
        monto: Math.round(numero * 100) / 100,
        fecha,
        descripcion: descripcion.trim() || null,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el movimiento.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Nuevo movimiento"
      description="Un ingreso o egreso a mano: aporte de capital, combustible, alquiler. Ventas, compras y préstamos se registran solos en su módulo."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Desplegable
          label="Tipo"
          value={tipo}
          onChange={(v) => {
            setTipo(v as TipoMovimientoOperativo)
            setMotivoGastoId(0)
          }}
          options={[
            { value: 'INGRESO', label: 'Ingreso' },
            { value: 'EGRESO', label: 'Egreso' },
          ]}
        />
        <Desplegable
          label="Cuenta"
          value={cuentaFinancieraId}
          onChange={(v) => setCuentaFinancieraId(Number(v))}
          placeholder="De dónde sale o a dónde entra"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre, detalle: NATURALEZA[c.naturaleza] ?? c.naturaleza }))}
        />
        <Desplegable
          label="Categoría"
          value={motivoGastoId}
          onChange={(v) => setMotivoGastoId(Number(v))}
          placeholder="Elige una categoría"
          options={categorias
            .filter((c) => c.tipo === tipo)
            .map((c) => ({ value: c.id, label: c.nombre, detalle: origenLabel(c.origen) }))}
        />
        <Input label="Monto" type="number" step="0.01" placeholder="0.00" value={monto} onChange={(e) => setMonto(e.target.value)} />
        <Input label="Fecha" type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
        <Input label="Descripción" optional value={descripcion} onChange={(e) => setDescripcion(e.target.value)} />
      </div>
    </Modal>
  )
}
