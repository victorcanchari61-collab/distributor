import { useEffect, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { ComponentType, ReactNode } from 'react'
import {
  ArrowDown,
  ArrowUp,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  ChevronsUpDown,
  Eye,
  GripVertical,
  Search,
  X,
} from 'lucide-react'
import { cn } from './cn'
import { useDismiss } from './useDismiss'
import { FiltersButton } from './FiltersButton'
import { describeFilter } from './dataTableFilters'
import type { DataTableFilter, FilterType } from './dataTableFilters'

/**
 * Tabla de listado con columnas movibles y ocultables, orden y busqueda por
 * columna, buscador general y filtros acumulables.
 *
 * Se pinta con el color de sistema activo (--sys-rgb y compañía, definidos en
 * styles/systems.css). Envuelve la tabla en un `data-sys="tms"` y cambia
 * entera de color; sin envolver hereda el azul del boton de login.
 *
 * Por defecto todo el trabajo (filtrar, ordenar, paginar) se hace en cliente
 * sobre `rows`, que es lo que sirve para un listado chico. Un listado grande
 * pasa `servidor`: ahí la tabla deja de recortar nada y solo avisa qué está
 * pidiendo, para que la vista traiga esa página del backend.
 */

/** Ancho fijo de la columna de acciones: no se redimensiona ni se reparte. */
const ACTIONS_WIDTH = 140

/**
 * Filas por pagina en TODO el sistema. Es una regla, no un default suelto:
 * los listados se ven iguales en todas las pantallas. Una vista solo deberia
 * pasar `pageSize` si tiene una razon de verdad para salirse de la regla.
 */
const PAGE_SIZE = 20

/** Las otras opciones del selector de "por pagina". */
const PAGE_SIZES = [PAGE_SIZE, 50, 100, 200]

export interface DataTableColumn<T> {
  key: string
  label: string
  align?: 'left' | 'right'
  sortable?: boolean
  searchable?: boolean
  filterable?: boolean
  /** Tipo de control que arma el panel de filtros para esta columna. */
  filterType?: FilterType
  /** Opciones del `<select>` cuando `filterType: 'select'`. */
  filterOptions?: { value: string; label: string }[]
  /** Escape hatch: valor a usar para buscar, ordenar y filtrar. */
  value?: (row: T) => string | number
  render?: (row: T) => ReactNode
}

/** Lo que la tabla está pidiendo: el espejo de su estado, para mandarlo al backend. */
export interface ConsultaTabla {
  pagina: number
  porPagina: number
  buscar: string
  /** Columna por la que ordena, o null si no hay orden elegido. */
  orden: string | null
  sentido: 'asc' | 'desc' | null
  filtros: { columna: string; operador: string; valor: string; valorHasta?: string }[]
}

/**
 * Modo servidor: la tabla no filtra ni pagina en memoria, solo avisa qué
 * necesita. Se usa cuando el listado es grande y traerlo entero no tiene
 * sentido.
 */
export interface SysDataTableServidor {
  /** Cuántas filas hay en todo el listado ya filtrado, no en esta página. */
  total: number
  /** Se llama cada vez que cambia la búsqueda, un filtro, el orden o la página. */
  onConsulta: (consulta: ConsultaTabla) => void
  cargando?: boolean
}

export interface SysDataTableProps<T> {
  columns: DataTableColumn<T>[]
  rows: T[]
  /** Si se pasa, la tabla trabaja contra el backend en vez de en memoria. */
  servidor?: SysDataTableServidor
  /** Propiedad que identifica cada fila. */
  rowKey?: keyof T & string
  searchPlaceholder?: string
  empty?: string
  pageSize?: number
  /** Icono de la tarjeta en la vista movil. */
  cardIcon?: ComponentType<{ size?: number; className?: string; 'aria-hidden'?: boolean }>
  /** Columna de acciones en la tabla y botones de cada tarjeta en movil. */
  actions?: (row: T) => ReactNode
  /**
   * Ancho de la columna de Acciones, en px. El valor por defecto (140) alcanza
   * para 3-4 íconos; una vista con más botones por fila (ej. Ver, Historial,
   * Editar, Confirmar, Anular) necesita declarar uno mayor, o esos íconos
   * fuerzan un scroll horizontal aunque el resto de columnas sean pocas.
   */
  actionsWidth?: number
  /** Si se pasa, toda la fila (y la tarjeta en movil) queda clickeable. */
  onRowClick?: (row: T) => void
  /** Oculta el buscador general y los botones de filtros/columnas — para tablas chicas (ej. líneas de un documento) donde solo estorban. */
  toolbar?: boolean
  className?: string
}

type Row = Record<string, unknown>

/**
 * Texto comparable de un valor: sin acentos y en minusculas, para que buscar
 * "razon" encuentre "Razón" y las mayusculas den igual.
 */
const asText = (value: unknown) =>
  (value == null ? '' : String(value))
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()

/**
 * Texto plano de lo que una columna pinta. Recorre elementos de React para
 * sacar su contenido legible, de modo que una celda con `render` siga siendo
 * buscable sin que la tabla que la usa tenga que declarar nada.
 */
function plainText(node: unknown, depth = 0): string {
  if (node == null || typeof node === 'boolean' || depth > 6) return ''
  if (typeof node === 'string' || typeof node === 'number') return String(node)
  if (Array.isArray(node)) return node.map((n) => plainText(n, depth + 1)).join(' ')

  const props = (node as { props?: Record<string, unknown> }).props
  if (!props) return ''

  // Los componentes propios suelen recibir su texto en `children`, `value` o
  // `label` (badges, tags de estado y similares).
  return [props.children, props.value, props.label]
    .map((p) => plainText(p, depth + 1))
    .filter(Boolean)
    .join(' ')
}

/** Propiedades habituales cuando una celda apunta a un objeto relacionado. */
const TEXT_KEYS = ['name', 'nombre', 'label', 'razon_social', 'descripcion', 'title', 'codigo']

/**
 * Valor de una celda para buscar, ordenar y filtrar. Se deduce sola:
 *
 *   1. `col.value(row)` si la columna lo declara (escape hatch opcional).
 *   2. el campo `row[col.key]`, si es un valor simple.
 *   3. la propiedad textual del objeto, si el campo es una relacion.
 *   4. lo que devuelva `render`, incluso si es JSX.
 *
 * Asi una columna calculada funciona sin configuracion extra.
 */
function cellValue<T>(col: DataTableColumn<T> | undefined, row: T): string | number {
  if (!col || !row) return ''
  if (col.value) return col.value(row)

  const raw = (row as Row)[col.key]

  if (raw !== null && raw !== undefined && typeof raw !== 'object') {
    return raw as string | number
  }

  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    const source = raw as Row
    const key = TEXT_KEYS.find((k) => typeof source[k] === 'string')
    if (key) return source[key] as string
  }

  // Ultimo recurso: lo que se ve en pantalla.
  if (col.render) {
    const painted = col.render(row)
    if (typeof painted === 'string' || typeof painted === 'number') return painted
    return plainText(painted)
  }

  return (raw as unknown as string | number) ?? ''
}

function matchesFilter<T>(row: T, filter: DataTableFilter, col?: DataTableColumn<T>) {
  const raw = cellValue(col ?? ({ key: filter.column, label: '' } as DataTableColumn<T>), row)
  const value = asText(raw)
  const term = asText(filter.value)

  switch (filter.operator) {
    case 'equals':
      return value === term
    case 'between': {
      // Fecha, guardada como epoch por column.value(): el filtro llega como
      // fecha (yyyy-mm-dd) de un <input type="date">, así que "hasta" se
      // extiende al final de ese día para que incluya todo lo del dia elegido.
      const num = Number(raw)
      const desde = filter.value ? new Date(filter.value).getTime() : -Infinity
      const hasta = filter.valueTo ? new Date(filter.valueTo).getTime() + 86_400_000 - 1 : Infinity
      return num >= desde && num <= hasta
    }
    default:
      return value.includes(term)
  }
}

export function SysDataTable<T>({
  columns = [],
  rows = [],
  rowKey = 'id' as keyof T & string,
  searchPlaceholder = 'Buscar...',
  empty = 'No hay registros para mostrar.',
  pageSize = PAGE_SIZE,
  cardIcon: CardIcon,
  actions,
  actionsWidth = ACTIONS_WIDTH,
  servidor,
  onRowClick,
  className,
  toolbar = true,
}: SysDataTableProps<T>) {
  const [order, setOrder] = useState<string[]>(() => columns.map((c) => c.key))
  const [hidden, setHidden] = useState<string[]>([])
  const [sort, setSort] = useState<{ key: string | null; dir: 'asc' | 'desc' | null }>({
    key: null,
    dir: null,
  })
  const [search, setSearch] = useState('')
  const [columnSearch, setColumnSearch] = useState<Record<string, string>>({})
  const [openSearch, setOpenSearch] = useState<string | null>(null)
  // Celda desde la que se abrio el buscador de columna: el popover se pinta en
  // un portal anclado a ella, porque la cabecera lleva overflow-hidden y ahi
  // dentro quedaria recortado.
  const [anchorSearch, setAnchorSearch] = useState<HTMLElement | null>(null)
  const [filters, setFilters] = useState<DataTableFilter[]>([])
  const [panel, setPanel] = useState<'columns' | 'filters' | null>(null)
  const [dragging, setDragging] = useState<string | null>(null)
  const [dragOver, setDragOver] = useState<string | null>(null)
  // anchos fijados por el usuario al arrastrar el borde de una cabecera
  const [widths, setWidths] = useState<Record<string, number>>({})
  const [resizingKey, setResizingKey] = useState<string | null>(null)
  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(pageSize)

  const byKey = useMemo(
    () => Object.fromEntries(columns.map((c) => [c.key, c])) as Record<string, DataTableColumn<T>>,
    [columns],
  )

  // El orden se guarda en estado para poder arrastrar las cabeceras, pero
  // entonces hay que sincronizarlo cuando la vista agrega o quita columnas:
  // sin esto, una columna nueva nunca llegaria a pintarse.
  useEffect(() => {
    setOrder((prev) => {
      const vigentes = prev.filter((k) => k in byKey)
      const nuevas = columns.map((c) => c.key).filter((k) => !vigentes.includes(k))
      if (nuevas.length === 0 && vigentes.length === prev.length) return prev
      return [...vigentes, ...nuevas]
    })
  }, [columns, byKey])

  // Columnas en el orden elegido y sin las ocultas.
  const visible = useMemo(
    () => order.map((k) => byKey[k]).filter((c) => c && !hidden.includes(c.key)),
    [order, byKey, hidden],
  )

  const toggleSort = (key: string) =>
    setSort((prev) =>
      prev.key !== key
        ? { key, dir: 'asc' }
        : prev.dir === 'asc'
          ? { key, dir: 'desc' }
          : { key: null, dir: null },
    )

  const toggleColumn = (key: string) =>
    setHidden((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]))

  const handleDrop = (targetKey: string) => {
    if (!dragging || dragging === targetKey) return
    setOrder((prev) => {
      const next = prev.filter((k) => k !== dragging)
      next.splice(next.indexOf(targetKey), 0, dragging)
      return next
    })
    setDragging(null)
    setDragOver(null)
  }

  const startResize = (e: React.MouseEvent<HTMLSpanElement>, key: string) => {
    e.preventDefault()
    e.stopPropagation()
    const th = e.currentTarget.closest('th')
    if (!th) return
    const startX = e.clientX
    const startWidth = th.getBoundingClientRect().width
    setResizingKey(key)
    document.body.style.userSelect = 'none'
    document.body.style.cursor = 'col-resize'

    const onMove = (ev: MouseEvent) =>
      setWidths((prev) => ({ ...prev, [key]: Math.max(90, startWidth + ev.clientX - startX) }))

    const onUp = () => {
      setResizingKey(null)
      document.body.style.userSelect = ''
      document.body.style.cursor = ''
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
    }

    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }

  /** Doble clic en el borde: la columna vuelve a su ancho automatico. */
  const resetWidth = (key: string) =>
    setWidths((prev) => {
      const next = { ...prev }
      delete next[key]
      return next
    })

  const data = useMemo(() => {
    // En modo servidor las filas ya vienen buscadas, filtradas, ordenadas y
    // recortadas por el backend: volver a tocarlas acá filtraría la página
    // contra sí misma y escondería resultados que sí existen.
    if (servidor) return rows

    let result = rows

    // buscador general
    if (search.trim()) {
      const term = asText(search)
      result = result.filter((row) =>
        visible.some((col) => asText(cellValue(col, row)).includes(term)),
      )
    }

    // busqueda por columna
    for (const [key, term] of Object.entries(columnSearch)) {
      if (!term?.trim()) continue
      const col = byKey[key]
      result = result.filter((row) => asText(cellValue(col, row)).includes(asText(term)))
    }

    // filtros acumulados
    for (const filter of filters) {
      result = result.filter((row) => matchesFilter(row, filter, byKey[filter.column]))
    }

    // orden
    if (sort.key) {
      const factor = sort.dir === 'desc' ? -1 : 1
      const col = byKey[sort.key]
      result = [...result].sort((a, b) => {
        const x = cellValue(col, a)
        const y = cellValue(col, b)
        if (typeof x === 'number' && typeof y === 'number') return (x - y) * factor
        return String(x ?? '').localeCompare(String(y ?? ''), 'es', { numeric: true }) * factor
      })
    }

    return result
  }, [rows, search, columnSearch, filters, sort, visible, byKey, servidor])

  const enServidor = servidor !== undefined

  // Cualquier cambio en el filtrado devuelve el listado a la primera pagina.
  //
  // `rows` entra en la lista solo en modo cliente: contra el servidor las
  // filas cambian justamente PORQUE se pidio otra pagina, asi que volver a la
  // primera dispararia otra peticion y se quedaria dando vueltas.
  useEffect(() => {
    setPage(1)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [perPage, search, columnSearch, filters, sort, ...(enServidor ? [] : [rows])])

  /*
   * Lo que la tabla necesita del backend. Se manda con un respiro de 300ms
   * para que escribir en el buscador no dispare una peticion por tecla.
   *
   * `onConsulta` se guarda en una ref y NO entra en las dependencias: la vista
   * normalmente la pasa como funcion inline, que cambia en cada render — si
   * estuviera en la lista, el efecto se repetiria sin parar.
   */
  const onConsultaRef = useRef(servidor?.onConsulta)
  onConsultaRef.current = servidor?.onConsulta

  useEffect(() => {
    if (!enServidor) return

    const pedir = () =>
      onConsultaRef.current?.({
        pagina: page,
        porPagina: perPage,
        buscar: search.trim(),
        orden: sort.key,
        sentido: sort.dir,
        filtros: [
          ...filters.map((f) => ({
            columna: f.column,
            operador: f.operator,
            valor: f.value ?? '',
            valorHasta: f.valueTo,
          })),
          // La busqueda por columna es un filtro mas, solo que escrito desde
          // la cabecera en vez del panel de filtros.
          ...Object.entries(columnSearch)
            .filter(([, texto]) => texto?.trim())
            .map(([columna, texto]) => ({
              columna,
              operador: 'contains',
              valor: texto.trim(),
            })),
        ],
      })

    const id = setTimeout(pedir, 300)
    return () => clearTimeout(id)
  }, [enServidor, page, perPage, search, columnSearch, filters, sort])

  // Contra el servidor el total lo dice el backend, y las filas que llegaron
  // YA son la pagina: recortarlas otra vez dejaria la tabla vacia.
  const total = enServidor ? servidor.total : data.length
  const pageCount = Math.max(1, Math.ceil(total / perPage))
  const from = (page - 1) * perPage
  const pageRows = useMemo(
    () => (enServidor ? data : data.slice(from, from + perPage)),
    [enServidor, data, from, perPage],
  )

  const headRef = useRef<HTMLDivElement>(null)
  const bodyRef = useRef<HTMLDivElement>(null)

  /*
   * La cabecera va fuera del area con scroll, para que la barra aparezca solo
   * junto a las filas. Ambas tablas usan `table-layout: fixed` con los mismos
   * anchos declarados, asi que quedan alineadas sin medir nada del DOM.
   *
   * El ancho de la barra se descuenta a la tabla de la cabecera; ese hueco lo
   * cubre el fondo de su contenedor, que lleva el mismo degradado, de modo que
   * la franja de color llega hasta el borde sin dejar blanco.
   */
  const [scrollbar, setScrollbar] = useState(0)

  useEffect(() => {
    const el = bodyRef.current
    if (!el) return

    const medir = () => setScrollbar(el.offsetWidth - el.clientWidth)
    medir()

    const ro = new ResizeObserver(medir)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  // Anchos de columna: los arrastrados mandan; el resto se reparte por igual.
  const colTemplate = useMemo(() => {
    const auto = `${100 / Math.max(1, visible.length)}%`
    const cols: (string | number)[] = visible.map((col) => widths[col.key] ?? auto)
    if (actions) cols.push(actionsWidth)
    return cols
  }, [visible, widths, actions, actionsWidth])

  const onBodyScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const el = e.currentTarget
    if (headRef.current) headRef.current.scrollLeft = el.scrollLeft

    // Sin desbordamiento vertical no se pagina: tope y fondo coincidirian.
    if (el.scrollHeight <= el.clientHeight + 4) return

    const alFondo = el.scrollTop + el.clientHeight >= el.scrollHeight - 4
    if (alFondo && page < pageCount) setPage((p) => Math.min(p + 1, pageCount))
  }

  // Cada cambio de pagina empieza por la primera fila.
  useEffect(() => {
    if (bodyRef.current) bodyRef.current.scrollTop = 0
  }, [page])

  const activeColumnSearches = Object.values(columnSearch).filter((v) => v?.trim()).length

  return (
    <div className={className}>
      {toolbar && (
        <>
          {/* barra de herramientas: suelta, sin tarjeta que la envuelva */}
          <div className="mb-2 flex items-center justify-end gap-2">
            <div className="relative min-w-0 flex-1 sm:max-w-xs sm:flex-none sm:basis-80">
              <Search
                size={15}
                className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-zinc-400"
              />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={searchPlaceholder}
                className="w-full rounded-lg border border-zinc-200 bg-white py-2 pr-8 pl-9 text-sm text-zinc-900 transition outline-none placeholder:text-zinc-400 focus:border-zinc-400"
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  aria-label="Limpiar busqueda"
                  className="absolute top-1/2 right-2.5 -translate-y-1/2 text-zinc-400 transition-colors hover:text-zinc-700"
                >
                  <X size={14} />
                </button>
              )}
            </div>

            {/* iconos junto al buscador, en el extremo derecho */}
            <div className="flex items-center gap-1">
              <FiltersButton
                columns={columns}
                filters={filters}
                setFilters={setFilters}
                open={panel === 'filters'}
                onToggle={() => setPanel((p) => (p === 'filters' ? null : 'filters'))}
                onClose={() => setPanel(null)}
              />

              <ColumnsButton
                order={order}
                byKey={byKey}
                hidden={hidden}
                onToggle={toggleColumn}
                onShowAll={() => setHidden([])}
                open={panel === 'columns'}
                onOpen={() => setPanel((p) => (p === 'columns' ? null : 'columns'))}
                onClose={() => setPanel(null)}
              />
            </div>
          </div>

          {/* chips de filtros activos */}
          {(filters.length > 0 || activeColumnSearches > 0) && (
            <div className="mb-2 flex flex-wrap items-center gap-1.5">
          {filters.map((f) => (
            <span
              key={f.id}
              className="inline-flex animate-[fadeIn_150ms_ease-out] items-center gap-1.5 rounded-full border border-[rgb(var(--sys-rgb)/0.3)] bg-[rgb(var(--sys-rgb)/0.1)] py-1 pr-1.5 pl-2.5 text-[11px] text-[rgb(var(--sys-ink-rgb))]"
            >
              <span className="font-medium">{byKey[f.column]?.label}</span>
              <span>{describeFilter(f)}</span>
              <button
                type="button"
                onClick={() => setFilters((prev) => prev.filter((x) => x.id !== f.id))}
                aria-label="Quitar filtro"
                className="rounded-full p-0.5 transition-colors hover:bg-[rgb(var(--sys-rgb)/0.2)]"
              >
                <X size={11} />
              </button>
            </span>
          ))}

          {Object.entries(columnSearch)
            .filter(([, v]) => v?.trim())
            .map(([key, value]) => (
              <span
                key={key}
                className="inline-flex items-center gap-1.5 rounded-full border border-zinc-200 bg-white py-1 pr-1.5 pl-2.5 text-[11px] text-zinc-600"
              >
                <Search size={10} />
                <span className="font-medium">{byKey[key]?.label}</span>
                <span>{value}</span>
                <button
                  type="button"
                  onClick={() => setColumnSearch((prev) => ({ ...prev, [key]: '' }))}
                  aria-label="Quitar busqueda de columna"
                  className="rounded-full p-0.5 transition-colors hover:bg-zinc-100"
                >
                  <X size={11} />
                </button>
              </span>
            ))}

          <button
            type="button"
            onClick={() => {
              setFilters([])
              setColumnSearch({})
            }}
            className="ml-auto text-[11px] font-medium text-zinc-500 transition-colors hover:text-zinc-800"
          >
            Limpiar todo
          </button>
        </div>
          )}
        </>
      )}

      {/* tabla */}
      <div className="hidden overflow-hidden rounded-lg shadow-sm ring-1 ring-zinc-200 sm:block">
        {/* el degradado va en el contenedor: cubre tambien el hueco que deja
            la barra de scroll, asi la franja llega hasta el borde */}
        <div
          ref={headRef}
          className="overflow-hidden bg-linear-to-br from-[rgb(var(--sys-rgb))] to-[rgb(var(--sys-dark-rgb))]"
        >
          <table
            className="border-collapse text-sm"
            style={{ tableLayout: 'fixed', width: `calc(100% - ${scrollbar}px)` }}
          >
            <colgroup>
              {colTemplate.map((w, i) => (
                <col key={i} style={{ width: w }} />
              ))}
            </colgroup>

            <thead>
              <tr className="text-[var(--sys-on)]">
                {visible.map((col) => {
                  const isSorted = sort.key === col.key
                  const isDragged = dragging === col.key
                  const isTarget = dragOver === col.key && dragging !== col.key

                  return (
                    <th
                      key={col.key}
                      scope="col"
                      draggable={resizingKey === null}
                      onDragStart={() => setDragging(col.key)}
                      onDragEnd={() => {
                        setDragging(null)
                        setDragOver(null)
                      }}
                      onDragOver={(e) => {
                        e.preventDefault()
                        setDragOver(col.key)
                      }}
                      onDrop={() => handleDrop(col.key)}
                      className={cn(
                        'group relative overflow-hidden px-3 py-1.5',
                        // sin transicion mientras se arrastra el borde: debe seguir al cursor
                        resizingKey === col.key
                          ? 'select-none'
                          : 'transition-[width,background-color,opacity] duration-200',
                        isDragged && 'opacity-40',
                        isTarget && 'bg-[rgb(var(--sys-on-rgb)/0.15)]',
                      )}
                    >
                      {isTarget && (
                        <span className="absolute inset-y-0 left-0 w-0.5 bg-[var(--sys-on)]" />
                      )}

                      <div
                        className={cn(
                          'flex min-w-0 items-center gap-1',
                          col.align === 'right' && 'justify-end',
                        )}
                      >
                        {/*
                          Los controles se esconden cuando la columna es angosta
                          y vuelven al pasar el mouse: antes se desbordaban sobre
                          la columna vecina. Los que estan en uso (orden activo o
                          busqueda escrita) se quedan siempre visibles.
                        */}
                        <GripVertical
                          size={13}
                          className="hidden shrink-0 cursor-grab text-[var(--sys-on)] opacity-40 transition-opacity group-hover:inline-block hover:opacity-100 active:cursor-grabbing"
                          aria-hidden="true"
                        />

                        <span className="min-w-0 truncate text-[11px] font-semibold tracking-wider uppercase">
                          {col.label}
                        </span>

                        {col.sortable !== false && (
                          <button
                            type="button"
                            onClick={() => toggleSort(col.key)}
                            aria-label={`Ordenar por ${col.label}`}
                            className={cn(
                              'shrink-0 rounded p-0.5 text-[var(--sys-on)] transition-opacity hover:opacity-100',
                              isSorted ? 'opacity-100' : 'hidden opacity-50 group-hover:block',
                            )}
                          >
                            {isSorted && sort.dir === 'asc' ? (
                              <ArrowUp size={13} />
                            ) : isSorted ? (
                              <ArrowDown size={13} />
                            ) : (
                              <ChevronsUpDown size={13} />
                            )}
                          </button>
                        )}

                        {col.searchable !== false && (
                          <button
                            type="button"
                            onClick={(e) => {
                              const th = e.currentTarget.closest('th') as HTMLElement | null
                              setAnchorSearch(th)
                              setOpenSearch((k) => (k === col.key ? null : col.key))
                            }}
                            aria-label={`Buscar en ${col.label}`}
                            className={cn(
                              'shrink-0 rounded p-0.5 text-[var(--sys-on)] transition-opacity hover:opacity-100',
                              columnSearch[col.key]?.trim()
                                ? 'opacity-100'
                                : 'hidden opacity-50 group-hover:block',
                            )}
                          >
                            <Search size={13} />
                          </button>
                        )}
                      </div>

                      {/* tirador para agrandar o reducir la columna */}
                      <span
                        role="separator"
                        aria-orientation="vertical"
                        aria-label={`Redimensionar ${col.label}`}
                        onMouseDown={(e) => startResize(e, col.key)}
                        onDoubleClick={() => resetWidth(col.key)}
                        onDragStart={(e) => e.preventDefault()}
                        className={cn(
                          'absolute top-0 right-0 z-10 flex h-full w-2 cursor-col-resize items-center justify-center',
                          'after:h-1/2 after:w-0.5 after:rounded-full after:bg-[var(--sys-on)] after:transition-opacity',
                          resizingKey === col.key
                            ? 'after:opacity-100'
                            : 'after:opacity-40 hover:after:opacity-100',
                        )}
                      />

                    </th>
                  )
                })}

                {/* columna fija: no se mueve, no se oculta ni se ordena */}
                {actions && (
                  <th
                    scope="col"
                    className="px-3 py-1.5 text-center text-[11px] font-semibold tracking-wider whitespace-nowrap uppercase"
                  >
                    Acciones
                  </th>
                )}
              </tr>
            </thead>
          </table>
        </div>

        {/* solo las filas se desplazan: la barra queda por debajo de la cabecera */}
        <div ref={bodyRef} onScroll={onBodyScroll} className="max-h-[55vh] overflow-auto">
          <table
            className="w-full border-collapse bg-white text-sm"
            style={{ tableLayout: 'fixed' }}
          >
            <colgroup>
              {colTemplate.map((w, i) => (
                <col key={i} style={{ width: w }} />
              ))}
            </colgroup>

            <tbody>
              {pageRows.length === 0 ? (
                <tr>
                  <td
                    colSpan={(visible.length || 1) + (actions ? 1 : 0)}
                    className="px-4 py-12 text-center text-sm text-zinc-500"
                  >
                    {empty}
                  </td>
                </tr>
              ) : (
                pageRows.map((row) => (
                  <tr
                    key={String((row as Row)[rowKey])}
                    onClick={onRowClick ? () => onRowClick(row) : undefined}
                    className={cn(
                      'border-b border-zinc-100 transition-colors last:border-b-0 hover:bg-[rgb(var(--sys-rgb)/0.05)]',
                      onRowClick && 'cursor-pointer',
                    )}
                  >
                    {visible.map((col) => (
                      <td
                        key={col.key}
                        className={cn(
                          // con `table-fixed` el contenido no puede ensanchar la
                          // columna: lo que no cabe se recorta
                          'truncate px-3 py-1.5 text-zinc-700',
                          col.align === 'right' && 'text-right tabular-nums',
                        )}
                      >
                        {col.render ? col.render(row) : (((row as Row)[col.key] as ReactNode) ?? null)}
                      </td>
                    ))}

                    {actions && (
                      <td className="px-3 py-1.5 whitespace-nowrap">
                        <div className="flex items-center justify-center gap-1">{actions(row)}</div>
                      </td>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* movil: cada fila se convierte en una tarjeta */}
      <div className="space-y-2 sm:hidden">
        {pageRows.length === 0 ? (
          <p className="rounded-xl bg-white px-4 py-10 text-center text-sm text-zinc-500 ring-1 ring-zinc-200">
            {empty}
          </p>
        ) : (
          pageRows.map((row) => {
            const [head, ...rest] = visible
            return (
              <div
                key={String((row as Row)[rowKey])}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={cn(
                  'rounded-xl bg-white p-3 shadow-sm ring-1 ring-zinc-200 transition-colors',
                  onRowClick && 'cursor-pointer active:bg-[rgb(var(--sys-rgb)/0.05)]',
                )}
              >
                {head && (
                  <div className="mb-2.5 flex items-start justify-between gap-2">
                    <div className="flex min-w-0 items-center gap-2">
                      {CardIcon && (
                        <CardIcon
                          size={16}
                          className="shrink-0 text-[rgb(var(--sys-rgb))]"
                          aria-hidden={true}
                        />
                      )}
                      <p className="truncate text-sm font-semibold text-zinc-900">
                        {head.render
                          ? head.render(row)
                          : (((row as Row)[head.key] as ReactNode) ?? null)}
                      </p>
                    </div>
                    {actions && (
                      <div className="flex shrink-0 items-center gap-1">{actions(row)}</div>
                    )}
                  </div>
                )}

                <dl className="space-y-1.5">
                  {rest.map((col) => {
                    const value = col.render
                      ? col.render(row)
                      : (((row as Row)[col.key] as ReactNode) ?? null)
                    const isEmpty = value === null || value === undefined || value === ''
                    return (
                      <div key={col.key} className="flex items-center justify-between gap-3">
                        <dt className="shrink-0 text-[12px] text-zinc-500">{col.label}</dt>
                        <dd className="min-w-0 truncate text-right text-[12px] text-zinc-800">
                          {isEmpty ? <span className="text-zinc-300">—</span> : value}
                        </dd>
                      </div>
                    )
                  })}
                </dl>
              </div>
            )
          })
        )}
      </div>

      {/* buscador de columna: fuera del arbol de la tabla para que nada lo recorte */}
      {openSearch && byKey[openSearch] && (
        <ColumnSearchPopover
          column={byKey[openSearch]}
          anchor={anchorSearch}
          value={columnSearch[openSearch] ?? ''}
          onChange={(v) => setColumnSearch((prev) => ({ ...prev, [openSearch]: v }))}
          onClose={() => setOpenSearch(null)}
        />
      )}

      <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-[12px] text-zinc-500">
        <div className="flex items-center gap-3">
          <span>
            {total === 0
              ? 'Sin registros'
              : `${from + 1}–${Math.min(from + perPage, total)} de ${total}`}
            {/* En modo cliente se aclara sobre cuantas filas se filtro; contra
                el servidor no aplica: `rows` es solo la pagina que llego. */}
            {!enServidor && data.length !== rows.length && ` (${rows.length} en total)`}
          </span>

          <label className="flex items-center gap-1.5">
            <span className="hidden sm:inline">Por pagina</span>
            <select
              value={perPage}
              onChange={(e) => setPerPage(Number(e.target.value))}
              className="rounded-md border border-zinc-200 bg-white py-1 pr-6 pl-2 text-[12px] text-zinc-700 outline-none focus:border-[rgb(var(--sys-rgb)/0.6)]"
            >
              {/* El tamaño que declara la vista entra en la lista: si no, el
                  select mostraria un valor que no es ninguna de sus opciones. */}
              {[...new Set([pageSize, ...PAGE_SIZES])]
                .sort((a, b) => a - b)
                .map((n) => (
                  <option key={n} value={n}>
                    {n}
                  </option>
                ))}
            </select>
          </label>
        </div>

        {pageCount > 1 && (
          <div className="flex items-center gap-1">
            <PageButton onClick={() => setPage(1)} disabled={page === 1} label="Primera">
              <ChevronsLeft size={15} />
            </PageButton>
            <PageButton
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              label="Anterior"
            >
              <ChevronLeft size={15} />
            </PageButton>

            {pageNumbers(page, pageCount).map((n, i) =>
              n === '...' ? (
                <span key={`gap${i}`} className="px-1 text-zinc-400">
                  ...
                </span>
              ) : (
                <button
                  key={n}
                  type="button"
                  onClick={() => setPage(n as number)}
                  aria-current={n === page ? 'page' : undefined}
                  className={cn(
                    'min-w-[28px] rounded-md px-2 py-1 font-medium transition-colors',
                    n === page
                      ? 'bg-[rgb(var(--sys-rgb))] text-[var(--sys-on)]'
                      : 'text-zinc-600 hover:bg-[rgb(var(--sys-rgb)/0.12)]',
                  )}
                >
                  {n}
                </button>
              ),
            )}

            <PageButton
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
              disabled={page === pageCount}
              label="Siguiente"
            >
              <ChevronRight size={15} />
            </PageButton>
            <PageButton
              onClick={() => setPage(pageCount)}
              disabled={page === pageCount}
              label="Ultima"
            >
              <ChevronsRight size={15} />
            </PageButton>
          </div>
        )}
      </div>
    </div>
  )
}

/* ------------------------------- paginacion ------------------------------- */

/** Numeros de pagina a mostrar, con elipsis cuando hay muchas. */
function pageNumbers(current: number, total: number): (number | string)[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)

  const pages: (number | string)[] = [1]
  const start = Math.max(2, current - 1)
  const end = Math.min(total - 1, current + 1)

  if (start > 2) pages.push('...')
  for (let i = start; i <= end; i++) pages.push(i)
  if (end < total - 1) pages.push('...')
  pages.push(total)

  return pages
}

function PageButton({
  onClick,
  disabled,
  label,
  children,
}: {
  onClick: () => void
  disabled?: boolean
  label: string
  children: ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      title={label}
      className="rounded-md p-1 text-zinc-500 transition-colors hover:bg-zinc-100 hover:text-zinc-800 disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent"
    >
      {children}
    </button>
  )
}

/* ------------------------ buscador flotante de columna --------------------- */

function ColumnSearchPopover<T>({
  column,
  anchor,
  value,
  onChange,
  onClose,
}: {
  column: DataTableColumn<T>
  /** Celda de cabecera bajo la que se coloca la ventana. */
  anchor: HTMLElement | null
  value: string
  onChange: (value: string) => void
  onClose: () => void
}) {
  const ref = useDismiss(onClose)
  const inputRef = useRef<HTMLInputElement>(null)
  const [shown, setShown] = useState(false)
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null)

  // Se pinta con position:fixed en coordenadas de pantalla, calculadas desde la
  // celda. Asi flota sobre la tabla en vez de quedar recortado por la cabecera,
  // que necesita overflow-hidden para sincronizar su scroll con las filas.
  useEffect(() => {
    if (!anchor) return

    const colocar = () => {
      const r = anchor.getBoundingClientRect()
      const ancho = Math.min(224, window.innerWidth - 32)
      setPos({
        top: r.bottom + 4,
        // Si la columna esta pegada al borde derecho, se alinea hacia dentro.
        left: Math.min(Math.max(8, r.left), window.innerWidth - ancho - 8),
      })
    }

    colocar()
    inputRef.current?.focus()
    const id = requestAnimationFrame(() => setShown(true))

    window.addEventListener('resize', colocar)
    window.addEventListener('scroll', colocar, true)
    return () => {
      cancelAnimationFrame(id)
      window.removeEventListener('resize', colocar)
      window.removeEventListener('scroll', colocar, true)
    }
  }, [anchor])

  if (!pos) return null

  return createPortal(
    <div
      ref={ref}
      style={{ top: pos.top, left: pos.left }}
      className={cn(
        'fixed z-50 w-[min(14rem,calc(100vw-2rem))] origin-top rounded-lg bg-white p-2 shadow-xl shadow-zinc-900/20 ring-1 ring-zinc-200 transition-all duration-150',
        shown ? 'translate-y-0 scale-100 opacity-100' : '-translate-y-1 scale-95 opacity-0',
      )}
    >
      <div className="relative">
        <Search
          size={13}
          className="pointer-events-none absolute top-1/2 left-2 -translate-y-1/2 text-zinc-400"
        />
        <input
          ref={inputRef}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && onClose()}
          placeholder={`Buscar ${column.label.toLowerCase()}`}
          className="w-full rounded-md border border-zinc-200 py-1.5 pr-6 pl-7 text-[12px] font-normal tracking-normal normal-case text-zinc-900 outline-none focus:border-zinc-400"
        />
        {value && (
          <button
            type="button"
            onClick={() => onChange('')}
            aria-label="Limpiar"
            className="absolute top-1/2 right-1.5 -translate-y-1/2 rounded p-0.5 text-zinc-400 transition-colors hover:text-zinc-700"
          >
            <X size={12} />
          </button>
        )}
      </div>
    </div>,
    document.body,
  )
}

/* ---------------------------- menu de columnas ---------------------------- */

function ColumnsButton<T>({
  order,
  byKey,
  hidden,
  onToggle,
  onShowAll,
  open,
  onOpen,
  onClose,
}: {
  order: string[]
  byKey: Record<string, DataTableColumn<T>>
  hidden: string[]
  onToggle: (key: string) => void
  onShowAll: () => void
  open: boolean
  onOpen: () => void
  onClose: () => void
}) {
  const ref = useDismiss(() => open && onClose())

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={onOpen}
        aria-expanded={open}
        aria-label="Mostrar u ocultar columnas"
        title="Columnas"
        className={cn(
          'relative flex h-[38px] w-[38px] items-center justify-center rounded-lg transition-colors',
          'text-[rgb(var(--sys-ink-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.12)]',
          open && 'bg-[rgb(var(--sys-rgb)/0.12)]',
        )}
      >
        <Eye size={17} />
        {hidden.length > 0 && (
          <span className="absolute -top-1 -right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] px-1 text-[10px] leading-none font-semibold text-[var(--sys-on)] ring-2 ring-white">
            {hidden.length}
          </span>
        )}
      </button>

      <div
        className={cn(
          'absolute right-0 z-30 mt-2 w-[min(15rem,calc(100vw-2rem))] origin-top-right rounded-xl bg-white shadow-xl shadow-zinc-900/10 ring-1 ring-zinc-200 transition-all duration-150',
          open ? 'scale-100 opacity-100' : 'pointer-events-none scale-95 opacity-0',
        )}
      >
        <div className="flex items-center justify-between border-b border-zinc-100 px-3 py-2">
          <p className="text-[12px] font-semibold text-zinc-900">Mostrar columnas</p>
          <button
            type="button"
            onClick={onShowAll}
            className="text-[11px] font-medium text-[rgb(var(--sys-ink-rgb))] hover:underline"
          >
            Todas
          </button>
        </div>
        <div className="max-h-72 overflow-y-auto p-1">
          {order.map((key) => {
            const col = byKey[key]
            if (!col) return null
            const isVisible = !hidden.includes(key)
            return (
              <label
                key={key}
                className="flex cursor-pointer items-center gap-2.5 rounded-lg px-2 py-1.5 text-[13px] text-zinc-700 transition-colors hover:bg-zinc-50"
              >
                <input
                  type="checkbox"
                  checked={isVisible}
                  onChange={() => onToggle(key)}
                  className="h-3.5 w-3.5 rounded border-zinc-300 text-[rgb(var(--sys-rgb))] focus:ring-[rgb(var(--sys-rgb)/0.3)]"
                />
                <span className="truncate">{col.label}</span>
              </label>
            )
          })}
        </div>
        <p className="border-t border-zinc-100 px-3 py-2 text-[10px] leading-relaxed text-zinc-400">
          Arrastra las cabeceras de la tabla para cambiar su orden.
        </p>
      </div>
    </div>
  )
}
