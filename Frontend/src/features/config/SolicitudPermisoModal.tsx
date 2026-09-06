import { useEffect, useState } from 'react'
import { Check, ShieldAlert } from 'lucide-react'
import { Alert, Button, Modal } from '../../components/ui'
import { resolveNav } from '../../components/layout'
import { ApiError, alNegarPermiso } from '../../lib/apiClient'
import type { PermisoNegado } from '../../lib/apiClient'
import { solicitudApi } from './solicitudApi'

const ACCION_LABEL: Record<string, string> = {
  ver: 'entrar a',
  crear: 'crear en',
  editar: 'editar en',
  anular: 'anular en',
  eliminar: 'eliminar en',
  exportar: 'exportar de',
  importar: 'importar en',
  confirmar: 'confirmar en',
  cobrar: 'registrar cobros en',
}

/**
 * Lo que ve alguien cuando el servidor le niega una acción.
 *
 * Un "no autorizado" a secas deja a la persona sin salida: sabe que no puede y
 * nada mas. Aqui la negativa es el punto donde se pide el permiso, que es
 * justo cuando se sabe para que hace falta — el motivo lo escribe quien lo
 * necesita, no quien lo aprueba.
 *
 * Se monta una sola vez en la app y se engancha al cliente HTTP: cualquier 403
 * del filtro de permisos lo abre, venga de la pantalla que venga. Pedirle a
 * cada vista que se acuerde de hacerlo garantizaria que la mitad no lo haga.
 */
export function SolicitudPermisoModal() {
  const [negado, setNegado] = useState<PermisoNegado | null>(null)
  const [motivo, setMotivo] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [enviado, setEnviado] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    alNegarPermiso((permiso) => {
      setNegado(permiso)
      setMotivo('')
      setEnviado(false)
      setError('')
    })
    return () => alNegarPermiso(null)
  }, [])

  if (!negado) return null

  const pantalla = resolveNav(negado.submodulo).item?.label ?? negado.submodulo
  const accion = ACCION_LABEL[negado.accion] ?? negado.accion

  const cerrar = () => setNegado(null)

  const enviar = async () => {
    setEnviando(true)
    setError('')
    try {
      await solicitudApi.solicitar({
        submodulo: negado.submodulo,
        accion: negado.accion,
        motivo: motivo.trim() || null,
      })
      setEnviado(true)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos enviar la solicitud.')
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Modal
      open
      onClose={cerrar}
      title={enviado ? 'Solicitud enviada' : 'No tienes permiso para esto'}
      size="sm"
      footer={
        enviado ? (
          <Button onClick={cerrar}>Entendido</Button>
        ) : (
          <>
            <Button variant="secondary" onClick={cerrar}>
              Cerrar
            </Button>
            <Button loading={enviando} onClick={() => void enviar()}>
              Solicitar permiso
            </Button>
          </>
        )
      }
    >
      {enviado ? (
        <div className="flex flex-col items-center gap-2 py-4 text-center">
          <Check size={28} className="text-emerald-600" />
          <p className="text-sm text-ink">
            Un administrador la verá en su bandeja. Cuando te lo conceda podrás hacerlo sin volver
            a entrar.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {error && <Alert>{error}</Alert>}

          <div className="flex gap-3">
            <ShieldAlert size={20} className="mt-0.5 shrink-0 text-amber-500" />
            <p className="text-sm text-ink">
              Tu rol no te deja <b>{accion}</b> <b>{pantalla}</b>. Puedes pedírselo a un
              administrador.
            </p>
          </div>

          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-ink">
              ¿Para qué lo necesitas? <span className="font-normal text-ink-soft">(opcional)</span>
            </span>
            <textarea
              value={motivo}
              onChange={(e) => setMotivo(e.target.value)}
              maxLength={300}
              rows={3}
              placeholder="Anular la NV-0042: la emití con el cliente equivocado"
              className="w-full rounded-field border border-line px-3 py-2 text-sm"
            />
            <span className="mt-1 block text-xs text-ink-soft">
              Escribirlo ayuda: quien aprueba decide si te lo da por una vez o para siempre.
            </span>
          </label>
        </div>
      )}
    </Modal>
  )
}
