import { CircleAlert, CircleCheck, CircleHelp, Eye, TriangleAlert } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import type { EstadoClave } from './crmApi'

/** El icono de cada estado en las tarjetas de los reportes. */
export const ICONO_ESTADO: Record<EstadoClave, LucideIcon> = {
  CRITICO: CircleAlert,
  RIESGO: TriangleAlert,
  SEGUIMIENTO: Eye,
  NORMAL: CircleCheck,
  SIN_BASE: CircleHelp,
}
