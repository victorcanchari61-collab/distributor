import { useEffect, useState } from 'react'
import { ApiError } from '../../lib/apiClient'
import { catalogoApi } from './catalogoApi'
import type { CatalogoResponse } from './catalogoApi'

/** Carga el catálogo público. Sin sesión ni tiempo real: lo mismo que ve cualquiera con el enlace. */
export function useCatalogo() {
  const [datos, setDatos] = useState<CatalogoResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let vigente = true
    catalogoApi
      .obtener()
      .then((r) => vigente && setDatos(r))
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No se pudo cargar el catálogo'))
      .finally(() => vigente && setCargando(false))
    return () => {
      vigente = false
    }
  }, [])

  return { datos, cargando, error }
}
