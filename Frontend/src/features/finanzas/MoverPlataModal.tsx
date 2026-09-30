import { useState } from 'react'
import { Alert, Button, Desplegable, Input, Modal } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { cuentaFinancieraApi } from './cuentaFinancieraApi'
import { tipoDeCuenta } from './cuentaFinancieraApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`


/** Una cuenta que se puede elegir; el saldo solo si quien abre el modal lo conoce. */
export interface CuentaParaMover {
  id: number
  nombre: string
  naturaleza: string
  /** La Bóveda: no es una caja. */
  esBoveda?: boolean
  saldoActual?: number
}

/**
 * Mover plata de una cuenta propia a otra: depositar lo de la Bóveda en el
 * banco, darle sencillo a un repartidor, retirar del banco. No es ingreso ni
 * gasto: en el estado de resultados no suma nada.
 */
export function MoverPlataModal({
  cuentas,
  origenInicial,
  onClose,
  onHecho,
}: {
  cuentas: CuentaParaMover[]
  origenInicial?: number
  onClose: () => void
  onHecho: () => void | Promise<void>
}) {
  const [origenId, setOrigenId] = useState(origenInicial ?? 0)
  const [destinoId, setDestinoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const origen = cuentas.find((c) => c.id === origenId)
  const opciones = (excluir: number) =>
    cuentas
      .filter((c) => c.id !== excluir)
      .map((c) => ({
        value: c.id,
        label: c.nombre,
        detalle: [tipoDeCuenta(c), c.saldoActual !== undefined ? soles(c.saldoActual) : null]
          .filter(Boolean)
          .join(' · '),
      }))

  const mover = async () => {
    const numero = Number(monto.replace(',', '.'))
    if (!origenId) return setError('Elige de dónde sale la plata.')
    if (!destinoId) return setError('Elige a dónde va la plata.')
    if (!Number.isFinite(numero) || numero <= 0) return setError('Ingresa un monto mayor a cero.')

    setGuardando(true)
    setError('')
    try {
      await cuentaFinancieraApi.transferir({
        cuentaOrigenId: origenId,
        cuentaDestinoId: destinoId,
        monto: Math.round(numero * 100) / 100,
        observacion: observacion.trim() || null,
      })
      await onHecho()
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos mover la plata.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Mover plata"
      description="De una cuenta propia a otra: un depósito, el sencillo de un repartidor, un retiro del banco. No es ingreso ni gasto."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void mover()}>
            Mover
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Desplegable
          label="Sale de"
          value={origenId}
          onChange={(v) => {
            setOrigenId(Number(v))
            if (Number(v) === destinoId) setDestinoId(0)
          }}
          placeholder="Elige la cuenta"
          options={opciones(0)}
        />
        <Desplegable
          label="Va a"
          value={destinoId}
          onChange={(v) => setDestinoId(Number(v))}
          placeholder="Elige la cuenta"
          options={opciones(origenId)}
        />
        <Input
          label="Monto"
          type="number"
          step="0.01"
          placeholder="0.00"
          hint={origen?.saldoActual !== undefined ? `Disponible ${soles(origen.saldoActual)}` : undefined}
          value={monto}
          onChange={(e) => setMonto(e.target.value)}
        />
        <Input
          label="Detalle"
          optional
          placeholder="Depósito del día, sencillo para la ruta..."
          value={observacion}
          onChange={(e) => setObservacion(e.target.value)}
        />
      </div>
    </Modal>
  )
}
