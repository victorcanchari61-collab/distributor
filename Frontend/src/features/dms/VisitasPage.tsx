import { useCallback, useEffect, useMemo, useState } from 'react'
import { CheckCircle2, MapPin, Phone, Plus, Store } from 'lucide-react'
import { Alert, Badge, ListPage, StatCard } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { rutaApi } from '../tms'
import type { RutaResponse } from '../tms'
import { usuarioApi } from '../config/usuarioApi'
import type { UsuarioResponse } from '../config/usuarioApi'
import { visitaApi } from './visitaApi'
import type { ConsultaVisitas, ResumenVisitas, VisitaResponse } from './visitaApi'

const hoy = () => hoyLocal()

/**
 * La fecha que guardó el filtro, como YYYY-MM-DD.
 *
 * El panel guarda lo que escribe un <input type="date">, es decir ya el texto
 * en ese formato; la fila en cambio expone epoch para poder comparar. Aquí
 * interesa el texto, que es lo que entiende el backend.
 */
const fechaDe = (valor?: string) => (valor && valor.length >= 10 ? valor.slice(0, 10) : undefined)

/**
 * Visitas: a qué clientes toca ir y a cuáles ya se les tomó pedido.
 *
 * No es un documento nuevo ni guarda nada: es una lista de trabajo armada con
 * el día de visita del cliente y los pedidos de esa fecha. Sirve para que el
 * vendedor no dependa de acordarse, y para ver al cierre del día cuántos
 * puestos quedaron sin pasar.
 */
export function VisitasPage() {
  const [visitas, setVisitas] = useState<VisitaResponse[]>([])
  const [resumen, setResumen] = useState<ResumenVisitas | null>(null)
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [usuarios, setUsuarios] = useState<UsuarioResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  /*
   * Los filtros viven en el modal de la tabla, no en una barra propia.
   *
   * La tabla los expone como columnas — Día, Ruta, Vendedor, Estado — y esta
   * pantalla solo traduce a la consulta del servidor los que el backend
   * necesita: el rango de fechas acota cuántas filas se piden, y ruta y
   * vendedor evitan traerse la lista entera para descartarla en el navegador.
   */
  const [consulta, setConsulta] = useState<ConsultaVisitas>({ desde: hoy(), hasta: hoy() })

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [lista, res] = await Promise.all([
        visitaApi.listar(consulta),
        visitaApi.resumen(consulta),
      ])
      setVisitas(lista)
      setResumen(res)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las visitas.')
    } finally {
      setCargando(false)
    }
  }, [consulta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Los catálogos de los filtros no dependen del rango elegido.
  useEffect(() => {
    void Promise.all([rutaApi.getAll(), usuarioApi.getAll()])
      .then(([rts, usrs]) => {
        setRutas(rts.filter((r) => r.activo))
        setUsuarios(usrs.filter((u) => u.activo))
      })
      .catch(() => {
        /* Sin catálogos la lista sigue sirviendo: solo se pierde filtrar. */
      })
  }, [])

  // Al tomar un pedido, la lista tiene que reflejarlo sin recargar a mano.
  useRealtime(['pedidos', 'clientes'], cargar)

  /** Traduce lo que eligió el usuario en el modal a la consulta del servidor. */
  const aplicar = useCallback((q: ConsultaTabla) => {
    const filtro = (columna: string) => q.filtros?.find((f) => f.columna === columna)

    const fecha = filtro('fecha')
    const desde = fechaDe(fecha?.valor) ?? hoy()

    setConsulta({
      desde,
      // Sin extremo superior es un día suelto, que es el uso normal.
      hasta: fechaDe(fecha?.valorHasta) ?? desde,
      rutaId: Number(filtro('ruta')?.valor) || undefined,
      vendedorId: Number(filtro('vendedor')?.valor) || undefined,
    })
  }, [])

  const columns: DataTableColumn<VisitaResponse>[] = useMemo(
    () => [
      {
        key: 'fecha',
        label: 'Día',
        filterType: 'date',
        // El filtro local compara epochs; el de servidor sale de aquí también.
        value: (row) => new Date(row.fecha).getTime(),
        render: (row) => (
          <span className="flex flex-col">
            <span>{new Date(row.fecha).toLocaleDateString()}</span>
            <span className="text-xs text-ink-soft capitalize">{row.dia.toLowerCase()}</span>
          </span>
        ),
      },
      {
        key: 'cliente',
        label: 'Cliente',
        render: (row) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{row.cliente}</span>
            <span className="text-xs text-ink-soft">{row.documento}</span>
          </span>
        ),
      },
      {
        key: 'mercado',
        label: 'Dónde',
        // Mercado y dirección juntos: es lo que se lee para llegar al puesto.
        render: (row) => (
          <span className="flex flex-col">
            <span>{row.mercado ?? '—'}</span>
            {row.direccion && <span className="text-xs text-ink-soft">{row.direccion}</span>}
          </span>
        ),
      },
      {
        key: 'telefono',
        label: 'Teléfono',
        filterable: false,
        render: (row) =>
          row.telefono ? (
            <span className="flex items-center gap-1.5">
              <Phone size={13} className="text-ink-soft" />
              {row.telefono}
            </span>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'ruta',
        label: 'Ruta',
        filterType: 'select',
        // El id como valor: es lo que el servidor necesita para acotar.
        filterOptions: rutas.map((r) => ({ value: String(r.id), label: r.nombre })),
        value: (row) => String(row.rutaId ?? ''),
        render: (row) => row.ruta ?? '—',
      },
      {
        key: 'vendedor',
        label: 'Vendedor',
        filterType: 'select',
        filterOptions: usuarios.map((u) => ({ value: String(u.id), label: u.nombre })),
        value: (row) => String(row.vendedorId ?? ''),
        render: (row) => row.vendedor ?? '—',
      },
      {
        key: 'atendido',
        label: 'Estado',
        filterType: 'select',
        filterOptions: [
          { value: 'Pendiente', label: 'Pendiente' },
          { value: 'Con pedido', label: 'Con pedido' },
        ],
        value: (row) => (row.atendido ? 'Con pedido' : 'Pendiente'),
        render: (row) =>
          row.atendido ? (
            <Badge tone="success">{row.pedidoNumero}</Badge>
          ) : (
            <Badge tone="warning">Pendiente</Badge>
          ),
      },
      {
        key: 'total',
        label: 'Pedido',
        align: 'right',
        filterable: false,
        render: (row) =>
          row.atendido ? `S/ ${row.total.toFixed(2)}` : <span className="text-ink-soft">—</span>,
      },
    ],
    [rutas, usuarios],
  )

  const cobertura =
    resumen && resumen.programadas > 0
      ? Math.round((resumen.atendidas / resumen.programadas) * 100)
      : 0

  return (
    <ListPage
      icon={<Store size={20} />}
      title="Visitas"
      description="Los clientes que toca visitar y a cuáles ya se les tomó pedido. Por defecto, los de hoy."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Programadas"
            value={String(resumen?.programadas ?? 0)}
            icon={<Store size={18} />}
          />
          <StatCard
            label="Con pedido"
            value={String(resumen?.atendidas ?? 0)}
            hint={`${cobertura}% de cobertura`}
            icon={<CheckCircle2 size={18} />}
            tono="success"
          />
          <StatCard
            label="Pendientes"
            value={String(resumen?.pendientes ?? 0)}
            hint="todavía sin pasar"
            icon={<MapPin size={18} />}
            tono="warning"
          />
          <StatCard
            label="Pedido del período"
            value={`S/ ${(resumen?.total ?? 0).toFixed(2)}`}
            icon={<Plus size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={visitas}
      onConsulta={aplicar}
      cardIcon={Store}
      searchPlaceholder="Buscar cliente, mercado..."
      empty={cargando ? 'Cargando visitas...' : 'No hay clientes con visita en esos días.'}
      note="Los pendientes salen primero. El pedido se toma desde Facturación → Pedidos."
    />
  )
}
