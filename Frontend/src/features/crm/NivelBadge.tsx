import { Badge } from '../../components/ui'
import type { NivelCliente } from './crmApi'
import { NIVELES } from './formato'

export function NivelBadge({ nivel }: { nivel: NivelCliente }) {
  const { label, tone } = NIVELES[nivel]
  return <Badge tone={tone}>{label}</Badge>
}
