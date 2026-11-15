import { CircleCheck, Hourglass, Receipt, TriangleAlert } from 'lucide-react'
import { FilaStats } from './FilaStats'
import { StatCard } from './StatCard'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/**
 * Cuánto hay que pagar, cuánto ya se registró y cuánto falta, en tres tarjetas.
 *
 * Va arriba de la lista de pagos de una venta o una compra: antes era una línea "Pagado S/ X de S/ Y" al pie, que
 * había que leer y restar a mano para saber si faltaba algo. Si lo registrado pasa del total, la tercera tarjeta
 * avisa en rojo cuánto sobra.
 */
export function ResumenPagos({ total, pagado }: { total: number; pagado: number }) {
  const falta = Math.max(0, total - pagado)
  const sobra = pagado - total > 0.001 ? pagado - total : 0

  return (
    <FilaStats>
      <StatCard label="Total a pagar" value={soles(total)} icon={<Receipt size={18} />} tono="neutral" />
      <StatCard
        label="Pagado"
        value={soles(pagado)}
        icon={<CircleCheck size={18} />}
        tono="success"
        progreso={total > 0 ? pagado / total : 0}
      />
      {sobra > 0 ? (
        <StatCard
          label="Sobra"
          value={soles(sobra)}
          hint="los pagos pasan del total"
          icon={<TriangleAlert size={18} />}
          tono="danger"
        />
      ) : (
        <StatCard
          label="Falta"
          value={soles(falta)}
          hint={falta > 0.001 ? 'por registrar' : 'completo'}
          icon={<Hourglass size={18} />}
          tono={falta > 0.001 ? 'warning' : 'success'}
        />
      )}
    </FilaStats>
  )
}
