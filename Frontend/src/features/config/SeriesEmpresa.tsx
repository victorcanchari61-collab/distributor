import { useCallback, useEffect, useState } from 'react'
import { Plus, Save, Sparkles, Trash2 } from 'lucide-react'
import { Alert, Badge, Button, Input, RowAction, Select, useConfirmacion, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { empresaApi } from './empresaApi'
import type { SerieCpe, SerieCpeRequest, TipoCpe } from './empresaApi'

const TIPOS: { valor: TipoCpe; etiqueta: string }[] = [
  { valor: '01', etiqueta: 'Factura' },
  { valor: '03', etiqueta: 'Boleta' },
  { valor: '07', etiqueta: 'Nota de crédito' },
  { valor: '08', etiqueta: 'Nota de débito' },
]

const nombreTipo = (tipo: TipoCpe) => TIPOS.find((t) => t.valor === tipo)?.etiqueta ?? tipo

const esNota = (tipo: TipoCpe) => tipo === '07' || tipo === '08'

/** La letra con la que SUNAT exige que empiece la serie. */
const letraDe = (tipo: TipoCpe, aplicaA: TipoCpe | null) => {
  if (esNota(tipo)) return aplicaA === '03' ? 'B' : 'F'
  return tipo === '03' ? 'B' : 'F'
}

const NUEVA: SerieCpeRequest = { tipo: '01', serie: '', aplicaA: null, ultimoNumero: 0, activa: true }

interface Props {
  empresaId: number
  /** Quien solo mira no cambia series. */
  puedeEditar: boolean
}

/**
 * Las series de comprobantes de una empresa y hasta qué número llegó cada una.
 *
 * El último número se escribe a mano porque quien ya venía facturando (con otro sistema o con la plataforma de
 * SUNAT) tiene que continuar desde donde iba: el próximo comprobante sale con ese número más uno.
 */
export function SeriesEmpresa({ empresaId, puedeEditar }: Props) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [series, setSeries] = useState<SerieCpe[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  /** Lo escrito en cada fila sin guardar, por id. */
  const [cambios, setCambios] = useState<Record<number, Partial<SerieCpeRequest>>>({})
  const [guardandoId, setGuardandoId] = useState<number | null>(null)
  const [nueva, setNueva] = useState<SerieCpeRequest>(NUEVA)
  const [agregando, setAgregando] = useState(false)

  const cargar = useCallback(async () => {
    setError('')
    try {
      setSeries(await empresaApi.series(empresaId))
      setCambios({})
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las series.')
    } finally {
      setCargando(false)
    }
  }, [empresaId])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const mensaje = (e: unknown, defecto: string) =>
    e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : defecto

  const valor = <K extends keyof SerieCpeRequest>(s: SerieCpe, campo: K) =>
    (cambios[s.id]?.[campo] ?? s[campo]) as SerieCpeRequest[K]

  const editar = (id: number, parcial: Partial<SerieCpeRequest>) =>
    setCambios((prev) => ({ ...prev, [id]: { ...prev[id], ...parcial } }))

  const guardarFila = async (s: SerieCpe) => {
    setGuardandoId(s.id)
    try {
      const guardada = await empresaApi.actualizarSerie(empresaId, s.id, {
        tipo: s.tipo,
        serie: valor(s, 'serie'),
        aplicaA: s.aplicaA,
        ultimoNumero: Number(valor(s, 'ultimoNumero')) || 0,
        activa: valor(s, 'activa'),
      })
      setSeries((lista) => lista.map((x) => (x.id === s.id ? guardada : x)))
      setCambios(({ [s.id]: _quitada, ...resto }) => resto)
      toast.exito(`Serie ${guardada.serie} guardada`)
    } catch (e) {
      toast.error(mensaje(e, 'No pudimos guardar la serie.'))
    } finally {
      setGuardandoId(null)
    }
  }

  const agregar = async () => {
    setAgregando(true)
    try {
      const creada = await empresaApi.crearSerie(empresaId, nueva)
      setSeries((lista) => [...lista, creada])
      setNueva({ ...NUEVA, tipo: nueva.tipo, aplicaA: nueva.aplicaA })
      toast.exito(`Serie ${creada.serie} creada`)
      await cargar()
    } catch (e) {
      toast.error(mensaje(e, 'No pudimos crear la serie.'))
    } finally {
      setAgregando(false)
    }
  }

  const crearEstandar = async () => {
    try {
      setSeries(await empresaApi.crearSeriesEstandar(empresaId))
      toast.exito('Series estándar creadas')
    } catch (e) {
      toast.error(mensaje(e, 'No pudimos crear las series.'))
    }
  }

  const eliminar = (s: SerieCpe) =>
    confirmar({
      titulo: `Eliminar la serie ${s.serie}`,
      mensaje: 'Se quita la serie. Solo se puede si todavía no emitió ningún comprobante.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        try {
          await empresaApi.eliminarSerie(empresaId, s.id)
          setSeries((lista) => lista.filter((x) => x.id !== s.id))
          toast.exito(`Serie ${s.serie} eliminada`)
        } catch (e) {
          toast.error(mensaje(e, 'No pudimos eliminar la serie.'))
        }
      },
    })

  const letraNueva = letraDe(nueva.tipo, nueva.aplicaA ?? null)

  return (
    <div className="space-y-4">
      <p className="text-xs text-ink-soft">
        Cada serie lleva su propia numeración. Si la empresa ya emitía comprobantes, escribe en «Último número» el último
        que usó: el siguiente saldrá con ese número más uno. Si hay varias series activas del mismo documento, se usa la
        primera.
      </p>

      {error && <Alert>{error}</Alert>}

      <div className="overflow-x-auto rounded-field border border-line">
        <table className="w-full min-w-[34rem] text-sm">
          <thead className="bg-surface-muted text-left text-xs text-ink-soft">
            <tr>
              <th className="px-3 py-2 font-medium">Documento</th>
              <th className="px-3 py-2 font-medium">Serie</th>
              <th className="px-3 py-2 font-medium">Último número</th>
              <th className="px-3 py-2 font-medium">Emitidos</th>
              <th className="px-3 py-2 font-medium">Estado</th>
              {puedeEditar && <th className="px-3 py-2" />}
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {series.length === 0 && (
              <tr>
                <td colSpan={6} className="px-3 py-6 text-center text-xs text-ink-soft">
                  {cargando ? 'Cargando series...' : 'Esta empresa todavía no tiene series: agrégalas abajo o crea las estándar.'}
                </td>
              </tr>
            )}
            {series.map((s) => {
              const sucia = cambios[s.id] !== undefined
              return (
                <tr key={s.id}>
                  <td className="px-3 py-2">
                    {nombreTipo(s.tipo)}
                    {s.aplicaA && <span className="text-xs text-ink-soft"> · de {s.aplicaA === '01' ? 'facturas' : 'boletas'}</span>}
                  </td>
                  <td className="px-3 py-2">
                    {puedeEditar && s.emitidos === 0 ? (
                      <Input
                        size="sm"
                        aria-label={`Serie ${s.serie}`}
                        className="w-24 font-mono uppercase"
                        maxLength={4}
                        value={valor(s, 'serie')}
                        onChange={(e) => editar(s.id, { serie: e.target.value.toUpperCase() })}
                      />
                    ) : (
                      <span className="font-mono">{s.serie}</span>
                    )}
                  </td>
                  <td className="px-3 py-2">
                    {puedeEditar ? (
                      <Input
                        size="sm"
                        type="number"
                        min={0}
                        aria-label={`Último número de ${s.serie}`}
                        className="w-32"
                        value={String(valor(s, 'ultimoNumero'))}
                        onChange={(e) => editar(s.id, { ultimoNumero: Number(e.target.value) })}
                      />
                    ) : (
                      s.ultimoNumero
                    )}
                  </td>
                  <td className="px-3 py-2 text-ink-soft">{s.emitidos}</td>
                  <td className="px-3 py-2">
                    {puedeEditar ? (
                      <label className="inline-flex cursor-pointer items-center gap-2 text-xs text-ink-muted">
                        <input
                          type="checkbox"
                          checked={valor(s, 'activa')}
                          onChange={(e) => editar(s.id, { activa: e.target.checked })}
                          className="size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
                        />
                        Activa
                      </label>
                    ) : (
                      <Badge tone={s.activa ? 'success' : 'neutral'}>{s.activa ? 'Activa' : 'Inactiva'}</Badge>
                    )}
                  </td>
                  {puedeEditar && (
                    <td className="px-3 py-2">
                      <div className="flex items-center justify-end gap-1">
                        <RowAction
                          label={`Guardar ${s.serie}`}
                          tone="success"
                          disabled={!sucia || guardandoId === s.id}
                          disabledReason="No hay cambios que guardar"
                          onClick={() => void guardarFila(s)}
                        >
                          <Save size={15} />
                        </RowAction>
                        <RowAction
                          label={`Eliminar ${s.serie}`}
                          tone="danger"
                          disabled={s.emitidos > 0}
                          disabledReason="Ya emitió comprobantes: desactívala en vez de eliminarla"
                          onClick={() => eliminar(s)}
                        >
                          <Trash2 size={15} />
                        </RowAction>
                      </div>
                    </td>
                  )}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {puedeEditar && (
        <div className="space-y-3 rounded-field border border-dashed border-line-strong p-3">
          <p className="text-sm font-medium text-ink">Agregar una serie</p>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Select
              label="Documento"
              value={nueva.tipo}
              onChange={(e) => {
                const tipo = e.target.value as TipoCpe
                setNueva({ ...nueva, tipo, aplicaA: esNota(tipo) ? (nueva.aplicaA ?? '01') : null })
              }}
            >
              {TIPOS.map((t) => (
                <option key={t.valor} value={t.valor}>
                  {t.etiqueta}
                </option>
              ))}
            </Select>
            {esNota(nueva.tipo) ? (
              <Select
                label="Corrige"
                value={nueva.aplicaA ?? '01'}
                onChange={(e) => setNueva({ ...nueva, aplicaA: e.target.value as TipoCpe })}
              >
                <option value="01">Facturas</option>
                <option value="03">Boletas</option>
              </Select>
            ) : (
              <div className="hidden sm:block" />
            )}
            <Input
              label="Serie"
              placeholder={`${letraNueva}001`}
              maxLength={4}
              className="font-mono uppercase"
              value={nueva.serie}
              onChange={(e) => setNueva({ ...nueva, serie: e.target.value.toUpperCase() })}
            />
            <Input
              label="Último número"
              type="number"
              min={0}
              value={String(nueva.ultimoNumero)}
              onChange={(e) => setNueva({ ...nueva, ultimoNumero: Number(e.target.value) })}
            />
          </div>
          <p className="text-xs text-ink-soft">
            Empieza con {letraNueva}: así lo exige SUNAT para {esNota(nueva.tipo) ? 'las notas que corrigen ' + (nueva.aplicaA === '03' ? 'boletas' : 'facturas') : nombreTipo(nueva.tipo).toLowerCase() + 's'}.
          </p>
          <div className="flex flex-wrap justify-end gap-2">
            <Button variant="secondary" size="sm" onClick={() => void crearEstandar()}>
              <Sparkles size={15} />
              Crear series estándar
            </Button>
            <Button size="sm" loading={agregando} disabled={nueva.serie.length !== 4} onClick={() => void agregar()}>
              <Plus size={15} />
              Agregar serie
            </Button>
          </div>
        </div>
      )}
      {dialogo}
    </div>
  )
}
