import { useCallback, useEffect, useRef, useState } from 'react'
import { ApiError } from '../../../lib/apiClient'
import { useRealtime } from '../../../lib/realtime'
import { planoApi, ubicacionApi } from '../inventarioApi'
import type { PlanoResponse, UbicacionResponse } from '../inventarioApi'
import type { FiguraPlano } from './PlanoLienzo'

const numeroDePiso = (codigo: string) => {
  const m = /^P(\d+)$/i.exec(codigo)
  return m ? Number(m[1]) : Number.MAX_SAFE_INTEGER
}

/**
 * Los pisos del almacén, cada uno es un plano, de abajo hacia arriba: por el número de su código (P2 antes que P10),
 * el mismo orden que usa el servidor para saber qué pisos cruza una escalera.
 */
export const pisosDe = (lugares: UbicacionResponse[]) =>
  lugares
    .filter((l) => l.tipo === 'PISO' && l.padreId === null)
    .sort((a, b) => numeroDePiso(a.codigo) - numeroDePiso(b.codigo) || a.id - b.id)

/**
 * Hacia dónde lleva una escalera vista desde un piso: "Sube a P2 · P3", "Baja a P1", o las dos cosas en un piso del
 * medio. Vacío si la escalera no cruza a otro piso.
 */
export function rumboEscalera(pisos: number[], desde: number | null, lugares: UbicacionResponse[], corto = false): string {
  const i = desde === null ? -1 : pisos.indexOf(desde)
  if (i < 0 || pisos.length < 2) return ''
  const codigo = (id: number) => lugares.find((l) => l.id === id)?.codigo ?? '?'
  const arriba = pisos.slice(i + 1).map(codigo)
  const abajo = pisos.slice(0, i).reverse().map(codigo)
  // Corto, para la etiqueta sobre la escalera (que suele ser angosta): "↑ P3 ↓ P1".
  if (corto)
    return [arriba.length ? `↑ ${arriba.join(' · ')}` : '', abajo.length ? `↓ ${abajo.join(' · ')}` : ''].filter(Boolean).join(' ')
  return [arriba.length ? `Sube a ${arriba.join(' · ')}` : '', abajo.length ? `Baja a ${abajo.join(' · ')}` : '']
    .filter(Boolean)
    .join(' — ')
}

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
      partes: l.planoPartes ?? [],
      color: l.id,
    }))
  // Lo de este piso y las escaleras que lo cruzan, aunque se hayan puesto desde otro piso.
  const elementos = plano?.elementos ?? []
  const deElementos: FiguraPlano[] = elementos
    .filter((e) => e.pisoId === pisoId || (pisoId !== null && e.tipo === 'ESCALERA' && e.pisos.includes(pisoId)))
    .map((e) => ({
      clave: `E${e.id}`,
      tipo: e.tipo,
      nombre: e.nombre,
      detalle: e.tipo === 'ESCALERA' ? rumboEscalera(e.pisos, pisoId, lugares, true) || undefined : undefined,
      detalleCompleto: e.tipo === 'ESCALERA' ? rumboEscalera(e.pisos, pisoId, lugares) || undefined : undefined,
      x: e.x,
      y: e.y,
      ancho: e.ancho,
      alto: e.alto,
    }))

  /*
   * Doble altura: lo que en un piso de abajo está abierto hasta este (un pasillo, un depósito alto) aquí es un vacío,
   * sin suelo. Se dibuja con su misma forma para que no se ponga nada encima; tocarlo lleva a lo de abajo.
   */
  const codigoDe = (id: number | null) => lugares.find((l) => l.id === id)?.codigo ?? ''
  const vacios: FiguraPlano[] =
    pisoId === null
      ? []
      : [
          ...elementos
            .filter((e) => e.tipo === 'PASILLO' && e.pisoId !== pisoId && e.pisos.includes(pisoId))
            .map(
              (e): FiguraPlano => ({
                clave: `VE${e.id}`,
                tipo: 'VACIO',
                nombre: 'Vacío',
                detalle: `doble altura de ${codigoDe(e.pisoId)}`,
                x: e.x,
                y: e.y,
                ancho: e.ancho,
                alto: e.alto,
              }),
            ),
          ...lugares
            .filter((l) => l.tipo === 'CUARTO' && l.planoX !== null && l.padreId !== pisoId && (l.planoPisos ?? []).includes(pisoId))
            .map(
              (l): FiguraPlano => ({
                clave: `VL${l.id}`,
                tipo: 'VACIO',
                nombre: 'Vacío',
                detalle: `doble altura de ${l.ruta}${l.nombre ? ` · ${l.nombre}` : ''}`,
                x: l.planoX ?? 0,
                y: l.planoY ?? 0,
                ancho: l.planoAncho ?? 2,
                alto: l.planoAlto ?? 2,
                partes: l.planoPartes ?? [],
              }),
            ),
        ]
  // Los pasillos van debajo: un lugar elegido no queda tapado por el pasillo de al lado.
  return [...deElementos, ...vacios, ...deLugares]
}

/**
 * De dónde viene un vacío: "VL12" es la doble altura del lugar 12; "VE5", la del pasillo 5. Null si la clave no es de
 * un vacío.
 */
export const origenDeVacio = (clave: string): { clave: string; id: number; esLugar: boolean } | null => {
  const m = /^V([LE])(\d+)$/.exec(clave)
  return m ? { clave: `${m[1]}${m[2]}`, id: Number(m[2]), esLugar: m[1] === 'L' } : null
}

/** Si el almacén tiene algo dibujado en el plano: sin eso no tiene sentido ofrecer elegir en él. */
export const tienePlano = (lugares: UbicacionResponse[]) => lugares.some((l) => l.tipo === 'CUARTO' && l.planoX !== null)

/** "L12" → 12. Las claves de pasillos y escaleras empiezan con E (las de los vacíos, con V: ver origenDeVacio). */
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
