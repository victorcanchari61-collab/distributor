import type { RectPlano } from '../inventarioApi'
import type { FiguraPlano } from './PlanoLienzo'

/** El tipo de dato que lleva un producto arrastrado desde el panel hasta un lugar del plano. */
export const MIME_PRODUCTO = 'application/x-titanic-producto'

export const choca = (a: RectPlano, b: RectPlano) =>
  a.x < b.x + b.ancho && b.x < a.x + a.ancho && a.y < b.y + b.alto && b.y < a.y + a.alto

/** Si el rectángulo cabe sin encimarse con nada más del plano. */
export const estaLibre = (figuras: FiguraPlano[], propia: string | null, r: RectPlano) =>
  figuras.every((f) => f.clave === propia || !choca(f, r))

/** El primer hueco libre de ese tamaño, de arriba abajo y de izquierda a derecha; null si no cabe. */
export function huecoLibre(figuras: FiguraPlano[], columnas: number, filas: number, ancho: number, alto: number): RectPlano | null {
  for (let y = 0; y <= filas - alto; y++)
    for (let x = 0; x <= columnas - ancho; x++) {
      const r = { x, y, ancho, alto }
      if (estaLibre(figuras, null, r)) return r
    }
  return null
}


/**
 * El mismo rectángulo girado: el ancho pasa a ser el alto. Gira sobre su esquina de arriba a la izquierda y, si así
 * se sale de la cuadrícula, se corre lo justo para que entre. Null si ni corriéndolo cabe (más alto que el plano).
 */
export function girado(r: RectPlano, columnas: number, filas: number): RectPlano | null {
  const ancho = r.alto
  const alto = r.ancho
  if (ancho > columnas || alto > filas) return null
  return { x: Math.min(r.x, columnas - ancho), y: Math.min(r.y, filas - alto), ancho, alto }
}
