import type { RectPlano } from '../inventarioApi'
import type { FiguraPlano } from './PlanoLienzo'

/** El tipo de dato que lleva un producto arrastrado desde el panel hasta un lugar del plano. */
export const MIME_PRODUCTO = 'application/x-titanic-producto'

/** Cuántas partes extra puede tener un lugar (el servidor pone el mismo tope). */
export const MAXIMO_PARTES = 30

export const choca = (a: RectPlano, b: RectPlano) =>
  a.x < b.x + b.ancho && b.x < a.x + a.ancho && a.y < b.y + b.alto && b.y < a.y + a.alto

/** Se tocan por un lado (comparten un tramo de borde); tocarse solo por una esquina no cuenta. */
export const tocan = (a: RectPlano, b: RectPlano) =>
  ((a.x + a.ancho === b.x || b.x + b.ancho === a.x) && a.y < b.y + b.alto && b.y < a.y + a.alto) ||
  ((a.y + a.alto === b.y || b.y + b.alto === a.y) && a.x < b.x + b.ancho && b.x < a.x + a.ancho)

const rect = (r: RectPlano): RectPlano => ({ x: r.x, y: r.y, ancho: r.ancho, alto: r.alto })

/** Todos los rectángulos de una figura: el principal y sus partes extra (un lugar en forma de L). */
export const rectsDe = (f: FiguraPlano): RectPlano[] => [rect(f), ...(f.partes ?? [])]

/** Si los rectángulos de un lugar no se enciman entre sí y forman una sola figura (cada uno toca al resto). */
export function formanUnaFigura(rects: RectPlano[]): boolean {
  for (let i = 0; i < rects.length; i++) for (let j = i + 1; j < rects.length; j++) if (choca(rects[i], rects[j])) return false
  if (rects.length <= 1) return true
  const visto = new Set([0])
  const pila = [0]
  while (pila.length) {
    const i = pila.pop()!
    rects.forEach((r, j) => {
      if (!visto.has(j) && tocan(rects[i], r)) {
        visto.add(j)
        pila.push(j)
      }
    })
  }
  return visto.size === rects.length
}

/** Si esos rectángulos caben sin encimarse con nada más del plano (lo de `propia` no cuenta: es lo que se mueve). */
export const estaLibre = (figuras: FiguraPlano[], propia: string | null, rects: RectPlano | RectPlano[]) => {
  const lista = Array.isArray(rects) ? rects : [rects]
  return figuras.every((f) => f.clave === propia || rectsDe(f).every((o) => lista.every((r) => !choca(o, r))))
}

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

// ------------------------------------------------------------- Celdas: lo ocupado, lo libre, lo pegado

/** Qué celdas están ocupadas: ocupado[y][x]. */
export function mapaOcupado(figuras: FiguraPlano[], columnas: number, filas: number): boolean[][] {
  const mapa = Array.from({ length: filas }, () => Array<boolean>(columnas).fill(false))
  for (const f of figuras)
    for (const r of rectsDe(f))
      for (let y = r.y; y < r.y + r.alto && y < filas; y++) for (let x = r.x; x < r.x + r.ancho && x < columnas; x++) mapa[y][x] = true
  return mapa
}

/** El rectángulo libre de mayor área (el primero, si hay empates). Null si el plano está lleno. */
export function rectanguloLibreMasGrande(figuras: FiguraPlano[], columnas: number, filas: number): RectPlano | null {
  const ocupado = mapaOcupado(figuras, columnas, filas)
  // Sumas acumuladas: cuántas celdas ocupadas hay en cualquier rectángulo, de una vez.
  const suma = Array.from({ length: filas + 1 }, () => Array<number>(columnas + 1).fill(0))
  for (let y = 0; y < filas; y++)
    for (let x = 0; x < columnas; x++) suma[y + 1][x + 1] = (ocupado[y][x] ? 1 : 0) + suma[y][x + 1] + suma[y + 1][x] - suma[y][x]
  const ocupadas = (x: number, y: number, a: number, h: number) => suma[y + h][x + a] - suma[y][x + a] - suma[y + h][x] + suma[y][x]

  let mejor: RectPlano | null = null
  for (let y = 0; y < filas; y++)
    for (let x = 0; x < columnas; x++) {
      if (ocupado[y][x]) continue
      for (let h = 1; y + h <= filas; h++) {
        let a = 1
        while (x + a <= columnas && ocupadas(x, y, a, h) === 0) a++
        a--
        if (a === 0) break
        if (!mejor || a * h > mejor.ancho * mejor.alto) mejor = { x, y, ancho: a, alto: h }
      }
    }
  return mejor
}

/**
 * Las celdas libres pegadas a una figura: todo el espacio vacío que se alcanza desde sus bordes sin cruzar nada
 * dibujado. Es lo que "Rellenar espacio" le suma al lugar.
 */
export function celdasLibresPegadas(figuras: FiguraPlano[], figura: FiguraPlano, columnas: number, filas: number): boolean[][] {
  const ocupado = mapaOcupado(figuras, columnas, filas)
  const tomada = Array.from({ length: filas }, () => Array<boolean>(columnas).fill(false))
  const pila: [number, number][] = []
  const empujar = (x: number, y: number) => {
    if (x < 0 || y < 0 || x >= columnas || y >= filas || ocupado[y][x] || tomada[y][x]) return
    tomada[y][x] = true
    pila.push([x, y])
  }
  // Las semillas: las celdas libres de alrededor de cada rectángulo de la figura.
  for (const r of rectsDe(figura)) {
    for (let x = r.x; x < r.x + r.ancho; x++) {
      empujar(x, r.y - 1)
      empujar(x, r.y + r.alto)
    }
    for (let y = r.y; y < r.y + r.alto; y++) {
      empujar(r.x - 1, y)
      empujar(r.x + r.ancho, y)
    }
  }
  while (pila.length) {
    const [x, y] = pila.pop()!
    empujar(x + 1, y)
    empujar(x - 1, y)
    empujar(x, y + 1)
    empujar(x, y - 1)
  }
  return tomada
}

/**
 * Parte un conjunto de celdas en pocos rectángulos: toma la primera celda (de arriba abajo, de izquierda a derecha),
 * la estira a la derecha todo lo que puede y después hacia abajo mientras la fila entera siga en el conjunto.
 */
export function enRectangulos(celdas: boolean[][]): RectPlano[] {
  const resta = celdas.map((fila) => [...fila])
  const filas = resta.length
  const columnas = filas ? resta[0].length : 0
  const rects: RectPlano[] = []
  for (let y = 0; y < filas; y++)
    for (let x = 0; x < columnas; x++) {
      if (!resta[y][x]) continue
      let ancho = 0
      while (x + ancho < columnas && resta[y][x + ancho]) ancho++
      let alto = 1
      while (y + alto < filas && Array.from({ length: ancho }, (_, i) => resta[y + alto][x + i]).every(Boolean)) alto++
      for (let yy = y; yy < y + alto; yy++) for (let xx = x; xx < x + ancho; xx++) resta[yy][xx] = false
      rects.push({ x, y, ancho, alto })
    }
  return rects
}

/**
 * Los tramos del borde de afuera de una figura hecha de varios rectángulos, en celdas: por cada celda, los lados que no
 * dan a otra celda de la misma figura. Así se dibuja una L como una sola figura, sin línea en medio.
 */
export function bordeExterior(rects: RectPlano[]): { x1: number; y1: number; x2: number; y2: number }[] {
  const dentro = new Set<string>()
  for (const r of rects) for (let y = r.y; y < r.y + r.alto; y++) for (let x = r.x; x < r.x + r.ancho; x++) dentro.add(`${x},${y}`)
  const tramos: { x1: number; y1: number; x2: number; y2: number }[] = []
  for (const clave of dentro) {
    const [x, y] = clave.split(',').map(Number)
    if (!dentro.has(`${x},${y - 1}`)) tramos.push({ x1: x, y1: y, x2: x + 1, y2: y })
    if (!dentro.has(`${x},${y + 1}`)) tramos.push({ x1: x, y1: y + 1, x2: x + 1, y2: y + 1 })
    if (!dentro.has(`${x - 1},${y}`)) tramos.push({ x1: x, y1: y, x2: x, y2: y + 1 })
    if (!dentro.has(`${x + 1},${y}`)) tramos.push({ x1: x + 1, y1: y, x2: x + 1, y2: y + 1 })
  }
  return tramos
}
