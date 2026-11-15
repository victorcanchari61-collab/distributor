import { useCallback, useEffect, useRef, useState } from 'react'
import { ApiError } from '../../../lib/apiClient'
import { useRealtime } from '../../../lib/realtime'
import { planoApi, ubicacionApi } from '../inventarioApi'
import type { PlanoResponse, UbicacionResponse } from '../inventarioApi'
import type { FiguraPlano } from './PlanoLienzo'

/** Los pisos del almacén: cada uno es un plano. */
export const pisosDe = (lugares: UbicacionResponse[]) => lugares.filter((l) => l.tipo === 'PISO' && l.padreId === null)

/**
 * Lo que va dibujado en el plano de un piso (o en el único plano, si el almacén no usa pisos y `pisoId` es null):
 * sus lugares ya dibujados y sus pasillos y escaleras.
 */
export function figurasDe(lugares: UbicacionResponse[], plano: PlanoResponse | null, pisoId: number | null): FiguraPlano[] {
  const deLugares: FiguraPlano[] = lugares
    .filter((l) => l.tipo === 'CUARTO' && l.padreId === pisoId && l.planoX !== null)
    .map((l) => ({
      clave: `L${l.id}`,
      tipo: 'LUGAR',
      codigo: l.ruta,
      nombre: l.nombre ?? 'Lugar',
      productos: l.productos,
      inactivo: !l.activo,
      x: l.planoX ?? 0,
      y: l.planoY ?? 0,
      ancho: l.planoAncho ?? 2,
      alto: l.planoAlto ?? 2,
    }))
  const deElementos: FiguraPlano[] = (plano?.elementos ?? [])
    .filter((e) => e.pisoId === pisoId)
    .map((e) => ({ clave: `E${e.id}`, tipo: e.tipo, nombre: e.nombre, x: e.x, y: e.y, ancho: e.ancho, alto: e.alto }))
  // Los pasillos van debajo: un lugar elegido no queda tapado por el pasillo de al lado.
  return [...deElementos, ...deLugares]
}

/** Si el almacén tiene algo dibujado en el plano: sin eso no tiene sentido ofrecer elegir en él. */
export const tienePlano = (lugares: UbicacionResponse[]) => lugares.some((l) => l.tipo === 'CUARTO' && l.planoX !== null)

/** "L12" → 12. Las claves de pasillos y escaleras empiezan con E. */
export const idDeClave = (clave: string) => Number(clave.slice(1))

/** Para buscar sin que importen mayúsculas ni tildes: "Leche Glória" encuentra "leche gloria". */
export const normalizar = (texto: string) =>
  texto
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .trim()

/** Los lugares y los planos de un almacén, al día con lo que cambie en otra PC. */
export function usePlanoAlmacen(almacenId: number) {
  const [lugares, setLugares] = useState<UbicacionResponse[]>([])
  const [plano, setPlano] = useState<PlanoResponse | null>(null)
  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState('')
  // Una respuesta que llega tarde, de un almacén que ya no se mira, se descarta.
  const vigente = useRef(almacenId)
  vigente.current = almacenId

  const recargar = useCallback(async () => {
    if (!almacenId) return
    setCargando(true)
    try {
      const [l, p] = await Promise.all([ubicacionApi.listar(almacenId), planoApi.obtener(almacenId)])
      if (vigente.current !== almacenId) return
      setLugares(l)
      setPlano(p)
      setError('')
    } catch (e) {
      if (vigente.current === almacenId) setError(e instanceof ApiError ? e.message : 'No pudimos cargar el plano.')
    } finally {
      if (vigente.current === almacenId) setCargando(false)
    }
  }, [almacenId])

  useEffect(() => {
    setLugares([])
    setPlano(null)
    void recargar()
  }, [recargar])

  useRealtime('ubicaciones', recargar)

  return { lugares, setLugares, plano, setPlano, cargando, error, recargar }
}
