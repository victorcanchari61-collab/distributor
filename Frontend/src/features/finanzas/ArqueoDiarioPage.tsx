import { useCallback, useEffect, useState } from 'react'
import { Calculator, Coins, HandCoins, Scale } from 'lucide-react'
import { Alert, Badge, Button, Input, ListPage, PageSection, StatCard } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { arqueoApi } from './finanzasApi'
import type { ArqueoCajaResponse, ArqueoResumenResponse } from './finanzasApi'

function hoyISO() {
  return new Date().toISOString().slice(0, 10)
}

/**
 * El cierre de caja del día: solo importa el efectivo — una transferencia o
 * una billetera digital no se cuenta a mano, así que no hay nada que arquear
 * ahí. Lo esperado sale de lo cobrado menos lo pagado en efectivo ese día
 * (notas de venta y compras vigentes, sin los pagos anulados); lo contado se
 * ingresa a mano. Registrar el mismo día de nuevo reemplaza el cierre
 * anterior, para que un conteo corregido no deje dos compitiendo.
 */
export function ArqueoDiarioPage() {
  const [fecha, setFecha] = useState(hoyISO())
  const [resumen, setResumen] = useState<ArqueoResumenResponse | null>(null)
  const [historial, setHistorial] = useState<ArqueoCajaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [montoContado, setMontoContado] = useState('')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  /*
   * Se cierra caja todos los dias, asi que el historial crece 365 filas al
   * ano: la tabla pide solo su pagina. El resumen del dia elegido va aparte,
   * porque no depende de la paginacion.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    try {
      const pagina = await arqueoApi.listar(q)
      setHistorial(pagina.items)
      setTotalRegistros(pagina.total)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el historial de cierres.')
    }
  }, [])

  const cargar = useCallback(async (f: string) => {
    setCargando(true)
    try {
      const res = await arqueoApi.resumen(f)
      setResumen(res)
      setMontoContado(res.arqueo ? String(res.arqueo.montoContado) : '')
      setObservacion(res.arqueo?.observacion ?? '')
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el arqueo del día.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar(fecha)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fecha])

  const registrar = async () => {
    const valor = Number(montoContado)
    if (montoContado.trim() === '' || Number.isNaN(valor) || valor < 0) {
      return setErrorForm('Ingresa cuánto contaste en caja.')
    }

    setGuardando(true)
    setErrorForm('')
    try {
      await arqueoApi.registrar({ fecha, montoContado: valor, observacion: observacion.trim() || null })
      // El cierre recien guardado tiene que aparecer en el historial, no solo
      // en el resumen del dia: se recarga tambien la pagina que se esta viendo.
      await Promise.all([cargar(fecha), consulta ? cargarPagina(consulta) : Promise.resolve()])
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos registrar el cierre.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<ArqueoCajaResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => new Date(row.fecha).toLocaleDateString('es-PE'),
    },
    { key: 'montoEsperado', label: 'Esperado', align: 'right', render: (row) => `S/ ${row.montoEsperado.toFixed(2)}` },
    { key: 'montoContado', label: 'Contado', align: 'right', render: (row) => `S/ ${row.montoContado.toFixed(2)}` },
    {
      key: 'diferencia',
      label: 'Diferencia',
      align: 'right',
      value: (row) => row.diferencia,
      render: (row) => (
        <Badge tone={row.diferencia === 0 ? 'success' : row.diferencia > 0 ? 'sys' : 'danger'}>
          {row.diferencia > 0 ? '+' : ''}S/ {row.diferencia.toFixed(2)}
        </Badge>
      ),
    },
    { key: 'usuario', label: 'Registrado por', render: (row) => row.usuario ?? <span className="text-ink-soft">—</span> },
  ]

  const diferencia = resumen ? Number(montoContado || 0) - resumen.montoEsperado : 0

  return (
    <ListPage
      icon={<Calculator size={20} />}
      title="Arqueo diario"
      description="Cierre de caja del día: solo el efectivo, comparado contra lo que dicen los documentos."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        resumen
          ? [
              <StatCard
                key="cobrado"
                label="Cobrado en efectivo"
                value={`S/ ${resumen.cobradoEfectivo.toFixed(2)}`}
                icon={<HandCoins size={18} />}
                tono="success"
              />,
              <StatCard
                key="pagado"
                label="Pagado en efectivo"
                value={`S/ ${resumen.pagadoEfectivo.toFixed(2)}`}
                icon={<Coins size={18} />}
                tono="warning"
              />,
              <StatCard
                key="esperado"
                label="Esperado en caja"
                value={`S/ ${resumen.montoEsperado.toFixed(2)}`}
                icon={<Scale size={18} />}
              />,
            ]
          : undefined
      }
      columns={columns}
      rows={historial}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={Calculator}
      searchPlaceholder="Buscar por fecha..."
      empty={cargando ? 'Cargando historial...' : 'Todavía no se registró ningún cierre.'}
      banner={
        <PageSection title={`Cerrar caja del ${new Date(`${fecha}T00:00:00`).toLocaleDateString('es-PE')}`}>
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}

            <Input
              label="Fecha"
              type="date"
              value={fecha}
              onChange={(e) => setFecha(e.target.value)}
              className="max-w-[220px]"
            />

            <Input
              label="Monto contado"
              type="number"
              step="0.01"
              placeholder="0.00"
              value={montoContado}
              onChange={(e) => setMontoContado(e.target.value)}
            />

            <Input
              label="Observación"
              optional
              placeholder="Alguna razón de la diferencia..."
              value={observacion}
              onChange={(e) => setObservacion(e.target.value)}
            />

            <div className="flex items-center justify-between rounded-field border border-line px-3 py-2.5">
              <span className="text-xs font-semibold text-ink-soft uppercase tracking-wide">Diferencia</span>
              <span
                className={
                  diferencia === 0
                    ? 'font-semibold text-emerald-600'
                    : diferencia > 0
                      ? 'font-semibold text-[rgb(var(--sys-rgb))]'
                      : 'font-semibold text-red-600'
                }
              >
                {diferencia > 0 ? '+' : ''}S/ {diferencia.toFixed(2)}
              </span>
            </div>

            <Button size="sm" loading={guardando} onClick={() => void registrar()}>
              {resumen?.arqueo ? 'Actualizar cierre' : 'Registrar cierre'}
            </Button>
          </div>
        </PageSection>
      }
    />
  )
}
