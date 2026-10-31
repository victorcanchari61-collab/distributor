import { useEffect, useMemo, useState } from 'react'
import { Plus, Trash2 } from 'lucide-react'
import { Alert, Button, Checkbox, Input, Modal, Select, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { MOTIVOS_NOTA, comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse, LineaComprobante } from './comprobanteApi'
import { monto } from './PanelComprobante'

interface LineaEditable {
  clave: number
  descripcion: string
  cantidad: string
  precio: string
  afectoIgv: boolean
}

let secuencia = 0
const lineaVacia = (): LineaEditable => ({ clave: ++secuencia, descripcion: '', cantidad: '1', precio: '', afectoIgv: true })
const desdeComprobante = (l: LineaComprobante): LineaEditable => ({
  clave: ++secuencia,
  descripcion: l.descripcion,
  cantidad: String(l.cantidad),
  precio: String(l.precio),
  afectoIgv: l.afectoIgv,
})

/**
 * Nota de crédito o débito sobre un comprobante aceptado. La de crédito arranca con las líneas del comprobante
 * (anulación o devolución total) y se puede editar para corregir solo una parte; la de débito pide el cargo.
 */
export function EmitirNotaModal({
  comprobante,
  tiposPermitidos,
  onClose,
  onEmitida,
}: {
  /** El comprobante a corregir; nulo con el modal cerrado. */
  comprobante: ComprobanteResponse | null
  /** Las notas que el usuario puede emitir (tiene permiso de crear en su submódulo). */
  tiposPermitidos: readonly ('07' | '08')[]
  onClose: () => void
  onEmitida: (nota: ComprobanteResponse) => void
}) {
  const toast = useToast()
  const [tipo, setTipo] = useState<'07' | '08'>('07')
  const [codMotivo, setCodMotivo] = useState('01')
  const [desMotivo, setDesMotivo] = useState('')
  const [lineas, setLineas] = useState<LineaEditable[]>([])
  const [emitiendo, setEmitiendo] = useState(false)
  const [error, setError] = useState('')

  // Al abrir, vuelve a empezar: crédito, anulación y las líneas del comprobante.
  useEffect(() => {
    if (!comprobante) return
    const inicial = tiposPermitidos[0] ?? '07'
    setTipo(inicial)
    setCodMotivo(MOTIVOS_NOTA[inicial][0].codigo)
    setDesMotivo('')
    setLineas(inicial === '07' ? comprobante.lineas.map(desdeComprobante) : [lineaVacia()])
    setError('')
    // eslint-disable-next-line react-hooks/exhaustive-deps -- solo al abrir con otro comprobante
  }, [comprobante])

  const cambiarTipo = (nuevo: '07' | '08') => {
    setTipo(nuevo)
    setCodMotivo(MOTIVOS_NOTA[nuevo][0].codigo)
    // La de crédito parte de las líneas del comprobante; la de débito, de una línea vacía para el cargo.
    setLineas(nuevo === '07' && comprobante ? comprobante.lineas.map(desdeComprobante) : [lineaVacia()])
  }

  const total = useMemo(
    () => lineas.reduce((s, l) => s + (Number(l.cantidad) || 0) * (Number(l.precio) || 0), 0),
    [lineas],
  )

  const cambiarLinea = (clave: number, cambios: Partial<LineaEditable>) =>
    setLineas((ls) => ls.map((l) => (l.clave === clave ? { ...l, ...cambios } : l)))

  const emitir = async () => {
    if (!comprobante) return
    if (!desMotivo.trim()) {
      setError('Escribe el motivo de la nota.')
      return
    }
    const validas = lineas.filter((l) => l.descripcion.trim() || Number(l.precio) > 0)
    if (validas.length === 0 || validas.some((l) => !l.descripcion.trim() || !(Number(l.cantidad) > 0) || !(Number(l.precio) > 0))) {
      setError('Cada línea necesita descripción, cantidad y precio mayores que cero.')
      return
    }

    setEmitiendo(true)
    setError('')
    try {
      const nota = await comprobanteApi.emitirNota(comprobante.id, {
        tipo,
        codMotivo,
        desMotivo: desMotivo.trim(),
        lineas: validas.map((l) => ({
          descripcion: l.descripcion.trim(),
          cantidad: Number(l.cantidad),
          precio: Number(l.precio),
          afectoIgv: l.afectoIgv,
        })),
      })
      if (nota.estado === 'ACEPTADO') toast.exito(`${nota.numeroCompleto} aceptada por SUNAT`)
      else toast.error(nota.mensajeSunat ?? `${nota.numeroCompleto}: no se pudo confirmar con SUNAT`)
      onEmitida(nota)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos emitir la nota')
    } finally {
      setEmitiendo(false)
    }
  }

  return (
    <Modal
      open={comprobante !== null}
      title={`Nota sobre ${comprobante?.numeroCompleto ?? ''}`}
      description={comprobante ? `${comprobante.clienteNombre} · facturado ${monto(comprobante.total)}` : undefined}
      size="xl"
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={emitiendo} onClick={() => void emitir()}>
            Emitir nota {tipo === '07' ? 'de crédito' : 'de débito'} · {monto(total)}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        <div className="grid gap-3 sm:grid-cols-2">
          <Select label="Tipo de nota" value={tipo} onChange={(e) => cambiarTipo(e.target.value as '07' | '08')}>
            {tiposPermitidos.includes('07') && <option value="07">Nota de crédito (devuelve o descuenta)</option>}
            {tiposPermitidos.includes('08') && <option value="08">Nota de débito (cobra de más)</option>}
          </Select>
          <Select label="Motivo (SUNAT)" value={codMotivo} onChange={(e) => setCodMotivo(e.target.value)}>
            {MOTIVOS_NOTA[tipo].map((m) => (
              <option key={m.codigo} value={m.codigo}>
                {m.codigo} · {m.label}
              </option>
            ))}
          </Select>
        </div>

        <Input
          label="Descripción del motivo"
          placeholder="Ej.: El cliente devolvió la mercadería"
          maxLength={250}
          value={desMotivo}
          onChange={(e) => setDesMotivo(e.target.value)}
        />

        <div className="flex flex-col gap-2">
          <p className="text-sm font-semibold text-ink">{tipo === '07' ? 'Lo que se corrige' : 'El cargo'}</p>
          {lineas.map((l) => (
            <div key={l.clave} className="grid items-end gap-2 sm:grid-cols-[minmax(0,1fr)_6rem_7rem_auto_auto]">
              <Input label="Descripción" value={l.descripcion} onChange={(e) => cambiarLinea(l.clave, { descripcion: e.target.value })} />
              <Input label="Cantidad" inputMode="decimal" value={l.cantidad} onChange={(e) => cambiarLinea(l.clave, { cantidad: e.target.value })} />
              <Input label="Precio" inputMode="decimal" value={l.precio} onChange={(e) => cambiarLinea(l.clave, { precio: e.target.value })} />
              <Checkbox
                label="IGV"
                checked={l.afectoIgv}
                onChange={(e) => cambiarLinea(l.clave, { afectoIgv: e.target.checked })}
              />
              <button
                type="button"
                aria-label="Quitar línea"
                className="mb-2 rounded-md p-1.5 text-ink-soft hover:bg-red-50 hover:text-red-600"
                onClick={() => setLineas((ls) => ls.filter((x) => x.clave !== l.clave))}
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))}
          <div>
            <Button variant="secondary" size="sm" onClick={() => setLineas((ls) => [...ls, lineaVacia()])}>
              <Plus size={15} /> Agregar línea
            </Button>
          </div>
          <p className="text-xs text-ink-soft">
            Los precios llevan el IGV incluido en las líneas con IGV, igual que en la venta. Las notas de crédito no pueden pasar de lo
            facturado.
          </p>
        </div>
      </div>
    </Modal>
  )
}
