import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import { api } from './apiClient'
import { getToken } from './authStorage'

/** Una acción sobre un submódulo, tal como la nombra el backend. */
export const ACCION = {
  ver: 'ver',
  crear: 'crear',
  editar: 'editar',
  anular: 'anular',
  eliminar: 'eliminar',
  exportar: 'exportar',
  importar: 'importar',
  confirmar: 'confirmar',
  cobrar: 'cobrar',
} as const

export type Accion = (typeof ACCION)[keyof typeof ACCION]

export interface SubmoduloCatalogo {
  submodulo: string
  modulo: string
  acciones: Accion[]
}

interface Contexto {
  /** Claves "submodulo:accion". */
  permisos: Set<string>
  cargando: boolean
  /** Se vuelve a preguntar al backend: tras aprobarle un permiso a alguien. */
  refrescar: () => Promise<void>
}

const PermisosContext = createContext<Contexto>({
  permisos: new Set(),
  cargando: true,
  refrescar: async () => {},
})

/**
 * Trae del backend lo que este usuario puede hacer.
 *
 * No sale del token a propósito: si viviera ahí, conceder un permiso obligaría
 * a la persona a volver a entrar — justo lo contrario de lo que hace falta
 * cuando un admin lo aprueba en el momento.
 */
export function PermisosProvider({ children }: { children: React.ReactNode }) {
  const [permisos, setPermisos] = useState<Set<string>>(new Set())
  const [cargando, setCargando] = useState(true)

  const refrescar = useMemo(
    () => async () => {
      if (!getToken()) {
        setPermisos(new Set())
        setCargando(false)
        return
      }
      try {
        const claves = await api.get<string[]>('/permiso/mios')
        setPermisos(new Set(claves))
      } catch {
        // Sin respuesta se queda sin permisos: es preferible una pantalla vacía
        // a mostrar botones que el servidor va a rechazar igual.
        setPermisos(new Set())
      } finally {
        setCargando(false)
      }
    },
    [],
  )

  useEffect(() => {
    void refrescar()
  }, [refrescar])

  const valor = useMemo(() => ({ permisos, cargando, refrescar }), [permisos, cargando, refrescar])

  return <PermisosContext.Provider value={valor}>{children}</PermisosContext.Provider>
}

/**
 * <c>puede('fact.notaventa', 'anular')</c> para esconder lo que no se permite.
 *
 * Esconder es comodidad, no seguridad: el filtro del backend rechaza igual a
 * quien llame al endpoint directo. Aquí solo evitamos ofrecer un botón que
 * terminaría en un 403.
 */
export function usePermisos() {
  const { permisos, cargando, refrescar } = useContext(PermisosContext)

  return useMemo(
    () => ({
      cargando,
      refrescar,
      puede: (submodulo: string, accion: Accion) => permisos.has(`${submodulo}:${accion}`),
      /** Si la pantalla se puede abrir siquiera. */
      puedeVer: (submodulo: string) => permisos.has(`${submodulo}:${ACCION.ver}`),
    }),
    [permisos, cargando, refrescar],
  )
}

/** El catálogo completo, para dibujar la matriz de Accesos. */
export function catalogoPermisos() {
  return api.get<SubmoduloCatalogo[]>('/permiso/catalogo')
}
