import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { FileText, ShoppingCart, UserSearch, UserRound, ClipboardList } from 'lucide-react'
import { Alert, PageHeader, Tabs } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { ACCION, usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { crmApi } from './crmApi'
import type { CatalogoSeguimiento, FichaCliente } from './crmApi'
import { BuscadorCliente } from './seguimiento/BuscadorCliente'
import { FichaCabecera } from './seguimiento/FichaCabecera'
import { TabCompras } from './seguimiento/TabCompras'
import { TabDocumentos } from './seguimiento/TabDocumentos'
import { TabResumen } from './seguimiento/TabResumen'
import { TabSeguimiento } from './seguimiento/TabSeguimiento'

const PESTANAS = ['resumen', 'seguimiento', 'compras', 'documentos'] as const
type Pestana = (typeof PESTANAS)[number]

const SUBMODULO = 'crm.seguimiento'

/**
 * Gestión y seguimiento de clientes: se busca un cliente y aparece su ficha (resumen, seguimiento, compras y documentos).
 * Los reportes de Clientes con caída e inactivos la abren ya con el cliente elegido: `?cliente=17&pestana=seguimiento`.
 */
export function SeguimientoPage() {
  const { puede } = usePermisos()
  const [parametros, setParametros] = useSearchParams()

  const idTexto = parametros.get('cliente')
  const id = idTexto && /^\d+$/.test(idTexto) ? Number(idTexto) : null
  const pestana: Pestana = PESTANAS.includes(parametros.get('pestana') as Pestana) ? (parametros.get('pestana') as Pestana) : 'resumen'

  const [ficha, setFicha] = useState<FichaCliente | null>(null)
  const [catalogo, setCatalogo] = useState<CatalogoSeguimiento | null>(null)
  // El que se acaba de elegir, para mostrar su nombre en el buscador mientras carga su ficha.
  const [elegido, setElegido] = useState<{ id: number; nombre: string } | null>(null)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    if (id === null) return
    try {
      setFicha(await crmApi.ficha(id))
      setError('')
    } catch (e) {
      setFicha(null)
      setError(e instanceof ApiError ? e.message : 'No se pudo cargar la ficha del cliente')
    }
  }, [id])

  useEffect(() => {
    if (id === null) {
      setFicha(null)
      setError('')
      return
    }
    setError('')
    void cargar()
  }, [id, cargar])

  useEffect(() => {
    crmApi
      .catalogo()
      .then(setCatalogo)
      .catch(() => setCatalogo(null))
  }, [])

  // Un cambio de otra PC (una gestión, una venta) se ve sin recargar.
  useRealtime(['seguimientos', 'notasventa', 'clientes'], cargar)

  const cambiarPestana = (clave: string) => setParametros({ cliente: String(id), pestana: clave }, { replace: true })

  /** Al elegir otro cliente se queda en la misma pestaña: útil para atender varios seguimientos seguidos. */
  const elegirCliente = (c: { id: number; nombre: string } | null) => {
    setElegido(c)
    setParametros(c ? { cliente: String(c.id), pestana } : {}, { replace: false })
  }

  const fichaVigente = ficha && ficha.cliente.id === id ? ficha : null
  const actual = fichaVigente
    ? { id: fichaVigente.cliente.id, nombre: fichaVigente.cliente.nombre }
    : elegido && elegido.id === id
      ? elegido
      : null

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<UserSearch size={20} />}
        title="Gestión y seguimiento"
        description="Elige un cliente para ver su ficha, registrar una gestión y dejar programado el siguiente contacto."
        actions={<BuscadorCliente actual={actual} alElegir={elegirCliente} />}
      />

      {id === null ? (
        <div className="flex flex-col items-center justify-center rounded-panel border border-line bg-white py-20 text-center">
          <span className="mb-4 flex size-16 items-center justify-center rounded-2xl bg-violet-100 text-violet-500">
            <UserSearch size={30} />
          </span>
          <h2 className="text-lg font-semibold text-ink">Elige un cliente para empezar</h2>
          <p className="mt-1 max-w-md text-sm text-ink-soft">
            Búscalo por nombre, documento o código para ver su ficha, registrar una gestión y dejar programado el siguiente contacto.
          </p>
        </div>
      ) : error && !fichaVigente ? (
        <Alert tone="warning">{error}</Alert>
      ) : !fichaVigente ? (
        <div className="space-y-4" aria-busy="true">
          <div className="h-40 animate-pulse rounded-panel bg-surface-alt" />
          <div className="h-10 w-2/3 animate-pulse rounded-field bg-surface-alt" />
          <div className="h-72 animate-pulse rounded-panel bg-surface-alt" />
        </div>
      ) : (
        <div className="space-y-4">
          <FichaCabecera ficha={fichaVigente} />

          <Tabs
            items={[
              { id: 'resumen', label: 'Resumen', icon: <UserRound size={15} /> },
              { id: 'seguimiento', label: 'Seguimiento', icon: <ClipboardList size={15} /> },
              { id: 'compras', label: 'Compras', icon: <ShoppingCart size={15} /> },
              { id: 'documentos', label: 'Documentos', icon: <FileText size={15} /> },
            ]}
            active={pestana}
            onChange={cambiarPestana}
          />

          {/* Al cambiar de cliente cada pestaña vuelve a pedir sus datos. */}
          {pestana === 'resumen' && (
            <TabResumen
              key={fichaVigente.cliente.id}
              ficha={fichaVigente}
              puedeRegistrar={puede(SUBMODULO, ACCION.crear)}
              irASeguimiento={() => cambiarPestana('seguimiento')}
            />
          )}
          {pestana === 'seguimiento' && (
            <TabSeguimiento
              key={fichaVigente.cliente.id}
              clienteId={fichaVigente.cliente.id}
              catalogo={catalogo}
              puedeRegistrar={puede(SUBMODULO, ACCION.crear)}
              puedeEditar={puede(SUBMODULO, ACCION.editar)}
              alCambiar={() => void cargar()}
            />
          )}
          {pestana === 'compras' && <TabCompras key={fichaVigente.cliente.id} clienteId={fichaVigente.cliente.id} />}
          {pestana === 'documentos' && <TabDocumentos key={fichaVigente.cliente.id} clienteId={fichaVigente.cliente.id} />}
        </div>
      )}
    </div>
  )
}
