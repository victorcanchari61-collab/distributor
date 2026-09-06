import { useEffect, useState } from 'react'
import { Filter, Plus, RotateCcw, X } from 'lucide-react'
import { cn } from './cn'
import { Modal } from './Modal'
import { Button } from './Button'
import { FilterField } from './FilterField'
import { OPERATORS, describeFilter } from './dataTableFilters'
import type { DataTableFilter, FilterType, OperatorId } from './dataTableFilters'
import type { DataTableColumn } from './SysDataTable'

/**
 * Boton de "Filtros" de `SysDataTable`, con sus dos flujos:
 *
 *   - escritorio: todos los filtros disponibles a la vista, uno por columna,
 *     con Restablecer/Aplicar (`PanelEscritorio`).
 *   - movil: se agregan de a uno, eligiendo columna, operador y valor
 *     (`PanelMovil`) — la pantalla no da espacio para mostrarlos todos juntos.
 *
 * Cada flujo vive en su propio componente: antes estaban mezclados en una
 * sola funcion de 300 lineas que ademas construia los `DataTableFilter[]` a
 * mano y decidia que control pintar segun `filterType` — esa ultima parte
 * ahora la resuelve `FilterField`, compartida por los dos.
 */

export function FiltersButton<T>({
  columns,
  filters,
  setFilters,
  open,
  onToggle,
  onClose,
}: {
  columns: DataTableColumn<T>[]
  filters: DataTableFilter[]
  setFilters: React.Dispatch<React.SetStateAction<DataTableFilter[]>>
  open: boolean
  onToggle: () => void
  onClose: () => void
}) {
  const filterable = columns.filter((c) => c.filterable !== false)

  return (
    <>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        aria-label="Filtros"
        title="Filtros"
        className={cn(
          'relative flex h-[38px] w-[38px] items-center justify-center rounded-lg transition-colors',
          'text-[rgb(var(--sys-ink-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.12)]',
          open && 'bg-[rgb(var(--sys-rgb)/0.12)]',
        )}
      >
        <Filter size={17} />
        {filters.length > 0 && (
          <span className="absolute -top-1 -right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] px-1 text-[10px] leading-none font-semibold text-[var(--sys-on)] ring-2 ring-white">
            {filters.length}
          </span>
        )}
      </button>

      <Modal open={open} title="Filtros" onClose={onClose} size="sm">
        {/* escritorio: todos los filtros disponibles a la vista */}
        <div className="hidden flex-col gap-4 sm:flex">
          <PanelEscritorio
            filterable={filterable}
            filters={filters}
            setFilters={setFilters}
            open={open}
            onClose={onClose}
          />
        </div>

        {/* movil: agrega los filtros de a uno */}
        <div className="flex flex-col gap-4 sm:hidden">
          <PanelMovil filterable={filterable} filters={filters} setFilters={setFilters} />
        </div>
      </Modal>
    </>
  )
}

/* ------------------------------ panel de escritorio ------------------------------ */

function PanelEscritorio<T>({
  filterable,
  filters,
  setFilters,
  open,
  onClose,
}: {
  filterable: DataTableColumn<T>[]
  filters: DataTableFilter[]
  setFilters: React.Dispatch<React.SetStateAction<DataTableFilter[]>>
  open: boolean
  onClose: () => void
}) {
  // Se arma de nuevo cada vez que se abre, a partir de lo ya aplicado.
  const [draft, setDraft] = useState<Record<string, { value: string; valueTo: string }>>({})

  useEffect(() => {
    if (!open) return
    const inicial: Record<string, { value: string; valueTo: string }> = {}
    for (const f of filters) inicial[f.column] = { value: f.value, valueTo: f.valueTo ?? '' }
    setDraft(inicial)
  }, [open, filters])

  const setValue = (key: string, campo: 'value' | 'valueTo', valor: string) =>
    setDraft((prev) => ({
      ...prev,
      [key]: { value: prev[key]?.value ?? '', valueTo: prev[key]?.valueTo ?? '', [campo]: valor },
    }))

  const aplicar = () => {
    const nuevos: DataTableFilter[] = []
    for (const col of filterable) {
      const d = draft[col.key]
      if (!d) continue
      const tipo: FilterType = col.filterType ?? 'text'
      if (tipo === 'date') {
        if (d.value || d.valueTo) {
          nuevos.push({ id: col.key, column: col.key, operator: 'between', value: d.value, valueTo: d.valueTo })
        }
      } else if (d.value?.trim()) {
        nuevos.push({
          id: col.key,
          column: col.key,
          operator: tipo === 'select' ? 'equals' : 'contains',
          value: d.value,
        })
      }
    }
    setFilters(nuevos)
    onClose()
  }

  const restablecer = () => {
    setDraft({})
    setFilters([])
  }

  return (
    <>
      <div className="flex flex-col gap-3.5">
        {filterable.map((col) => {
          const tipo: FilterType = col.filterType ?? 'text'
          const d = draft[col.key] ?? { value: '', valueTo: '' }
          return (
            <div key={col.key} className="flex flex-col gap-1">
              <p className="text-[11px] font-semibold tracking-wide text-zinc-400 uppercase">{col.label}</p>
              <FilterField
                type={tipo}
                options={col.filterOptions}
                value={d.value}
                valueTo={d.valueTo}
                onChange={(v) => setValue(col.key, 'value', v)}
                onChangeTo={(v) => setValue(col.key, 'valueTo', v)}
                onEnter={aplicar}
                textPlaceholder={`Buscar ${col.label.toLowerCase()}...`}
              />
            </div>
          )
        })}
      </div>

      <div className="flex items-center gap-2 border-t border-line pt-3">
        <Button type="button" size="sm" variant="secondary" onClick={restablecer}>
          <RotateCcw size={13} />
          Restablecer
        </Button>
        <Button type="button" size="sm" onClick={aplicar} className="flex-1">
          Aplicar filtros
        </Button>
      </div>
    </>
  )
}

/* -------------------------------- panel de movil ---------------------------------- */

function PanelMovil<T>({
  filterable,
  filters,
  setFilters,
}: {
  filterable: DataTableColumn<T>[]
  filters: DataTableFilter[]
  setFilters: React.Dispatch<React.SetStateAction<DataTableFilter[]>>
}) {
  const [draft, setDraft] = useState<{ column: string; operator: OperatorId; value: string; valueTo: string }>({
    column: filterable[0]?.key ?? '',
    operator: 'contains',
    value: '',
    valueTo: '',
  })

  const draftCol = filterable.find((c) => c.key === draft.column)
  const draftType: FilterType = draftCol?.filterType ?? 'text'

  // Cambiar de columna cambia de tipo de filtro: el operador tiene que
  // encajar con el nuevo control (una lista de estado siempre entiende "es
  // igual a", un rango de fechas no tiene operador — siempre es "entre").
  const elegirColumna = (key: string) => {
    const col = filterable.find((c) => c.key === key)
    const tipo: FilterType = col?.filterType ?? 'text'
    setDraft({
      column: key,
      operator: tipo === 'select' ? 'equals' : tipo === 'date' ? 'between' : 'contains',
      value: '',
      valueTo: '',
    })
  }

  const add = () => {
    if (!draft.column) return
    if (draftType === 'date' ? !draft.value && !draft.valueTo : !draft.value.trim()) return
    setFilters((prev) => [
      ...prev,
      { ...draft, id: `${draft.column}-${prev.length}-${draft.value}-${draft.valueTo}` },
    ])
    setDraft((d) => ({ ...d, value: '', valueTo: '' }))
  }

  return (
    <>
      <div className="flex flex-col gap-2">
        <p className="text-[11px] font-semibold tracking-wide text-zinc-400 uppercase">Agregar filtro</p>

        <select
          value={draft.column}
          onChange={(e) => elegirColumna(e.target.value)}
          className="w-full rounded-lg border border-zinc-200 px-2 py-1.5 text-[13px] outline-none focus:border-zinc-400"
        >
          {filterable.map((c) => (
            <option key={c.key} value={c.key}>
              {c.label}
            </option>
          ))}
        </select>

        {/* El operador solo se elige en filtros de texto libre: una lista de
            estado siempre es "es igual a", y una fecha siempre es un rango —
            mostrar el operador ahí solo confundiría. */}
        {draftType === 'text' && (
          <select
            value={draft.operator}
            onChange={(e) => setDraft((d) => ({ ...d, operator: e.target.value as OperatorId }))}
            className="w-full rounded-lg border border-zinc-200 px-2 py-1.5 text-[13px] outline-none focus:border-zinc-400"
          >
            {OPERATORS.filter((o) => o.id !== 'between').map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </select>
        )}

        <FilterField
          type={draftType}
          options={draftCol?.filterOptions}
          value={draft.value}
          valueTo={draft.valueTo}
          onChange={(v) => setDraft((d) => ({ ...d, value: v }))}
          onChangeTo={(v) => setDraft((d) => ({ ...d, valueTo: v }))}
          onEnter={add}
        />

        <Button type="button" size="sm" onClick={add}>
          <Plus size={14} />
          Agregar filtro
        </Button>
      </div>

      {filters.length > 0 && (
        <div className="flex flex-col gap-1.5 border-t border-line pt-3">
          <p className="text-[11px] font-semibold tracking-wide text-zinc-400 uppercase">Filtros aplicados</p>
          <ul className="flex flex-col gap-1.5">
            {filters.map((f) => (
              <li
                key={f.id}
                className="flex items-center justify-between gap-2 rounded-lg bg-zinc-50 px-2.5 py-2 text-[12px] text-zinc-700"
              >
                <span className="truncate">
                  <b className="font-medium">{filterable.find((c) => c.key === f.column)?.label}</b>{' '}
                  {describeFilter(f)}
                </span>
                <button
                  type="button"
                  onClick={() => setFilters((prev) => prev.filter((x) => x.id !== f.id))}
                  aria-label="Quitar filtro"
                  className="shrink-0 rounded p-1 text-zinc-400 transition-colors hover:bg-zinc-200 hover:text-zinc-700"
                >
                  <X size={13} />
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </>
  )
}
