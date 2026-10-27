import { useCallback, useEffect, useMemo, useState } from 'react'
import { ArrowDown, ArrowUp, Award, Calculator, CalendarDays, Minus, Save } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  PageHeader,
  Select,
  SysDataTable,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaHora } from '../../lib/fechas'
import { ACCION, usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { CategoriaBadge } from './CategoriaBadge'
import { categorizacionApi } from './categorizacionApi'
import type {
  Categorizacion,
  CicloCategorizacion,
  ClienteCategorizado,
  ColorCategoria,
} from './categorizacionApi'
import { CICLOS, COLORES_CATEGORIA, diaSiguiente, soles, ventanaDelCiclo } from './formato'

const SUBMODULO = 'crm.categorizacion'

/** Una categoría mientras se edita: el monto es texto para poder escribirlo sin que se reformatee. */
interface FilaEditable {
  codigo: string
  nombre: string
  color: ColorCategoria
  desde: string
}

interface Formulario {
  ciclo: CicloCategorizacion
  categorias: FilaEditable[]
}

const aFormulario = (c: Categorizacion): Formulario => ({
  ciclo: c.ciclo,
  categorias: c.categorias.map((x) => ({
    codigo: x.codigo,
    nombre: x.nombre,
    color: x.color,
    desde: String(x.desde),
  })),
})

const MOVIMIENTOS = {
  SUBE: { icono: <ArrowUp size={13} />, label: 'Sube', tono: 'success' as const },
  BAJA: { icono: <ArrowDown size={13} />, label: 'Baja', tono: 'danger' as const },
  IGUAL: { icono: <Minus size={13} />, label: 'Igual', tono: 'neutral' as const },
  NUEVO: { icono: null, label: 'Nuevo', tono: 'sys' as const },
}

/**
 * Categorización de clientes: Socio, Distribuidor, Mayorista... según lo que compraron en el ciclo
 * anterior.
 *
 * Guardar solo cambia la configuración; las categorías de los clientes se recalculan con "Calcular
 * ahora" o solas cuando empieza el ciclo siguiente. Del "hasta" no se escribe nada: es lo que falta
 * para llegar a la categoría de arriba, así los tramos nunca dejan huecos ni se pisan.
 */
export function CategorizacionPage() {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const { puede } = usePermisos()
  const puedeEditar = puede(SUBMODULO, ACCION.editar)

  const [datos, setDatos] = useState<Categorizacion | null>(null)
  const [form, setForm] = useState<Formulario | null>(null)
  const [clientes, setClientes] = useState<ClienteCategorizado[]>([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [calculando, setCalculando] = useState(false)

  const cargar = useCallback(async () => {
    try {
      const [config, lista] = await Promise.all([categorizacionApi.obtener(), categorizacionApi.clientes()])
      setDatos(config)
      setClientes(lista)
      // Lo que se está escribiendo no se pisa cuando otra PC avisa de un cambio: solo se carga la
      // primera vez y después de guardar.
      setForm((actual) => actual ?? aFormulario(config))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la categorización.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['categorizacion', 'clientes'], cargar)

  const sucio = useMemo(
    () => !!datos && !!form && JSON.stringify(aFormulario(datos)) !== JSON.stringify(form),
    [datos, form],
  )

  // El efecto de cambiar el ciclo se ve antes de guardar: se calcula en pantalla con la misma cuenta.
  const ventana = useMemo(() => (form ? ventanaDelCiclo(form.ciclo, new Date()) : null), [form])

  const cambiar = (indice: number, cambios: Partial<FilaEditable>) =>
    setForm((f) =>
      f ? { ...f, categorias: f.categorias.map((c, i) => (i === indice ? { ...c, ...cambios } : c)) } : f,
    )

  const guardar = async () => {
    if (!form) return

    const montos = form.categorias.map((c) => Number(c.desde))
    if (montos.some((m) => !Number.isFinite(m) || m < 0)) return toast.error('Los montos tienen que ser números desde 0.')
    if (form.categorias.some((c) => !c.nombre.trim())) return toast.error('Toda categoría necesita un nombre.')

    setGuardando(true)
    try {
      const guardado = await categorizacionApi.guardar({
        ciclo: form.ciclo,
        categorias: form.categorias.map((c, i) => ({
          codigo: c.codigo,
          nombre: c.nombre.trim(),
          color: c.color,
          desde: montos[i],
        })),
      })
      setDatos(guardado)
      setForm(aFormulario(guardado))
      toast.exito('Configuración guardada. Las categorías de los clientes cambian al calcular.')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar la configuración.')
    } finally {
      setGuardando(false)
    }
  }

  const calcular = () => {
    if (sucio) return toast.error('Guarda la configuración antes de calcular.')

    confirmar({
      titulo: 'Calcular categorías',
      mensaje: datos?.vigente
        ? 'Se vuelve a calcular la categoría de todos los clientes activos con lo guardado, y reemplaza al cálculo de este ciclo.'
        : 'Se calcula por primera vez la categoría de todos los clientes activos con lo guardado. Desde ahí, se actualiza sola cada vez que empieza un ciclo nuevo.',
      confirmar: 'Calcular ahora',
      tono: 'pregunta',
      accion: async () => {
        setCalculando(true)
        try {
          const nuevo = await categorizacionApi.calcular()
          setDatos(nuevo)
          setClientes(await categorizacionApi.clientes())
          toast.exito('Categorías calculadas.')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos calcular las categorías.')
        } finally {
          setCalculando(false)
        }
      },
    })
  }

  const colorDe = useCallback(
    (codigo: string) => datos?.categorias.find((c) => c.codigo === codigo),
    [datos],
  )

  const columnas: DataTableColumn<ClienteCategorizado>[] = useMemo(
    () => [
      {
        key: 'cliente',
        label: 'Cliente',
        filterable: false,
        render: (r) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{r.nombre}</span>
            <span className="text-xs text-ink-soft">
              {r.codigo} · {r.documento}
            </span>
          </span>
        ),
      },
      { key: 'mercado', label: 'Mercado', filterType: 'select', filterOptions: opciones(clientes.map((c) => c.mercado)), value: (r) => r.mercado ?? '', render: (r) => r.mercado ?? '—' },
      { key: 'ruta', label: 'Ruta', filterType: 'select', filterOptions: opciones(clientes.map((c) => c.ruta)), value: (r) => r.ruta ?? '', render: (r) => r.ruta ?? '—' },
      {
        key: 'monto',
        label: 'Compró en el ciclo',
        align: 'right',
        filterable: false,
        value: (r) => r.monto,
        render: (r) => soles(r.monto),
      },
      {
        key: 'categoria',
        label: 'Categoría',
        filterType: 'select',
        filterOptions: (datos?.categorias ?? []).map((c) => ({ value: c.codigo, label: `${c.codigo} · ${c.nombre}` })),
        value: (r) => r.categoria,
        render: (r) => {
          const c = colorDe(r.categoria)
          return <CategoriaBadge codigo={r.categoria} nombre={c?.nombre} color={c?.color} />
        },
      },
      {
        key: 'movimiento',
        label: 'Frente al ciclo anterior',
        filterType: 'select',
        filterOptions: Object.entries(MOVIMIENTOS).map(([value, { label }]) => ({ value, label })),
        value: (r) => r.movimiento,
        render: (r) => {
          if (!r.movimiento) return <span className="text-ink-soft">—</span>
          const m = MOVIMIENTOS[r.movimiento]
          return (
            <span className="flex items-center gap-2">
              <Badge tone={m.tono}>
                <span className="mr-1 inline-flex">{m.icono}</span>
                {m.label}
              </Badge>
              {r.categoriaAnterior && r.movimiento !== 'IGUAL' && (
                <span className="text-xs text-ink-soft">antes {r.categoriaAnterior}</span>
              )}
            </span>
          )
        },
      },
    ],
    [clientes, datos, colorDe],
  )

  const vigente = datos?.vigente

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<Award size={20} />}
        title="Categorización de clientes"
        description="Cada cliente tiene la categoría que le toca por lo que compró en el ciclo anterior."
      />

      {error && <Alert>{error}</Alert>}

      {datos && !vigente && (
        <Alert tone="warning">
          Todavía no se calculó ninguna categoría. Revisa los montos, guarda y pulsa «Calcular ahora»: desde ahí se
          actualizan solas cuando empieza un ciclo nuevo.
        </Alert>
      )}
      {vigente?.vencido && (
        <Alert tone="warning">
          El último cálculo rigió hasta el {fechaCorta(vigente.ventana.vigenteHasta)} y todavía no se actualizó.
          Pulsa «Calcular ahora» si no se hizo solo.
        </Alert>
      )}
      {datos?.cicloDistinto && (
        <Alert tone="info">
          El ciclo guardado es distinto al del último cálculo: las categorías actuales siguen siendo las de ese
          cálculo hasta que pulses «Calcular ahora».
        </Alert>
      )}

      {form && ventana && (
        <section className="space-y-4 rounded-panel border border-line bg-white p-4 sm:p-5">
          <div>
            <p className="mb-1.5 text-xs font-semibold tracking-wide text-ink-soft uppercase">Ciclo de actualización</p>
            <Tabs
              items={CICLOS.map((c) => ({ id: c.id, label: c.label }))}
              active={form.ciclo}
              onChange={(id) => puedeEditar && setForm({ ...form, ciclo: id as CicloCategorizacion })}
            />
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-field border border-line px-3 py-2.5">
              <p className="text-xs font-semibold tracking-wide text-ink-soft uppercase">
                Compras evaluadas ({CICLOS.find((c) => c.id === form.ciclo)?.label.toLowerCase()})
              </p>
              <p className="mt-0.5 font-semibold text-[rgb(var(--sys-ink-rgb))]">
                {fechaCorta(ventana.evaluadoDesde)} – {fechaCorta(ventana.evaluadoHasta)}
              </p>
            </div>
            <div className="rounded-field border border-line px-3 py-2.5">
              <p className="text-xs font-semibold tracking-wide text-ink-soft uppercase">
                Fecha en que cambiará el resultado
              </p>
              <p className="mt-0.5 flex flex-wrap items-baseline gap-2 font-semibold text-[rgb(var(--sys-ink-rgb))]">
                <CalendarDays size={15} className="self-center" />
                {fechaCorta(diaSiguiente(ventana.vigenteHasta))}
                <span className="text-xs font-normal text-ink-soft">
                  El actual rige desde el {fechaCorta(ventana.vigenteDesde)}
                </span>
              </p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full min-w-[40rem] text-sm">
              <thead>
                <tr className="border-b border-line text-left text-xs font-semibold tracking-wide text-ink-soft uppercase">
                  <th className="py-2 pr-3">Categoría</th>
                  <th className="px-3 py-2 text-center">Código</th>
                  <th className="px-3 py-2">Desde (S/)</th>
                  <th className="px-3 py-2">Hasta (S/)</th>
                  <th className="py-2 pl-3 text-right">Clientes</th>
                </tr>
              </thead>
              <tbody>
                {form.categorias.map((c, i) => {
                  const arriba = i === 0 ? null : Number(form.categorias[i - 1].desde)
                  const hasta = arriba !== null && Number.isFinite(arriba) ? arriba - 1 : null
                  const clientesDe = datos?.categorias.find((x) => x.codigo === c.codigo)?.clientes ?? 0

                  return (
                    <tr key={c.codigo} className="border-b border-line last:border-0">
                      <td className="py-2 pr-3">
                        <div className="flex items-center gap-2">
                          <CategoriaBadge codigo={c.codigo} nombre={c.nombre || '—'} color={c.color} className="min-w-28" />
                          {puedeEditar && (
                            <>
                              <Input
                                aria-label={`Nombre de la categoría ${c.codigo}`}
                                size="sm"
                                value={c.nombre}
                                maxLength={30}
                                onChange={(e) => cambiar(i, { nombre: e.target.value })}
                                className="max-w-40"
                              />
                              <Select
                                aria-label={`Color de la categoría ${c.codigo}`}
                                size="sm"
                                value={c.color}
                                onChange={(e) => cambiar(i, { color: e.target.value as ColorCategoria })}
                                className="max-w-28"
                              >
                                {COLORES_CATEGORIA.map((o) => (
                                  <option key={o.id} value={o.id}>
                                    {o.label}
                                  </option>
                                ))}
                              </Select>
                            </>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-2 text-center font-bold text-ink-muted">{c.codigo}</td>
                      <td className="px-3 py-2">
                        <Input
                          aria-label={`Monto desde de la categoría ${c.codigo}`}
                          size="sm"
                          inputMode="numeric"
                          value={c.desde}
                          // La última arranca en cero: así nadie queda sin categoría.
                          disabled={!puedeEditar || i === form.categorias.length - 1}
                          onChange={(e) => cambiar(i, { desde: e.target.value.replace(/[^\d.]/g, '') })}
                        />
                      </td>
                      <td className="px-3 py-2 text-ink-muted">
                        {hasta === null ? <span className="text-ink-soft">A MÁS</span> : hasta.toLocaleString('es-PE')}
                      </td>
                      <td className="py-2 pl-3 text-right font-medium">{clientesDe}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="text-xs text-ink-soft">
              Los montos son soles con IGV, sin ventas anuladas y menos los recojos. El «hasta» es lo que falta para
              llegar a la categoría de arriba.
              {vigente && (
                <>
                  {' '}
                  Último cálculo: {fechaHora(vigente.calculadoEn)}
                  {vigente.automatico ? ' (automático)' : vigente.usuario ? ` por ${vigente.usuario}` : ''}.
                </>
              )}
            </p>

            {puedeEditar && (
              <div className="flex flex-wrap gap-2">
                <Button variant="secondary" loading={calculando} onClick={calcular}>
                  <Calculator size={16} /> Calcular ahora
                </Button>
                <Button loading={guardando} disabled={!sucio} onClick={guardar}>
                  <Save size={16} /> Guardar configuración
                </Button>
              </div>
            )}
          </div>
        </section>
      )}

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-ink">
          Clientes por categoría
          {vigente && (
            <span className="ml-2 font-normal text-ink-soft">
              compras del {fechaCorta(vigente.ventana.evaluadoDesde)} al {fechaCorta(vigente.ventana.evaluadoHasta)} ·
              rige hasta el {fechaCorta(vigente.ventana.vigenteHasta)}
            </span>
          )}
        </h2>
        <SysDataTable
          columns={columnas}
          rows={clientes}
          rowKey="clienteId"
          searchPlaceholder="Buscar cliente, documento..."
          cardIcon={Award}
          empty={
            cargando ? 'Cargando clientes...' : vigente ? 'No hay clientes en este cálculo.' : 'Calcula las categorías para ver los clientes.'
          }
        />
      </section>

      {dialogo}
    </div>
  )
}

/** Las opciones distintas de una lista de textos, sin vacíos y en orden alfabético. */
function opciones(valores: (string | null)[]) {
  return [...new Set(valores.filter((v): v is string => !!v))]
    .sort((a, b) => a.localeCompare(b, 'es'))
    .map((v) => ({ value: v, label: v }))
}
