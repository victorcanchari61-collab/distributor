import { useRef, useState } from 'react'
import { Contact } from 'lucide-react'
import { Badge, BuscadorCampo, BuscadorModal } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn, OpcionBuscador } from '../../components/ui'
import { clienteApi } from './clienteApi'
import type { ClienteOpcion } from './clienteApi'

/** Lo que pide el campo mientras se escribe: las primeras coincidencias. */
const COINCIDENCIAS = 20

const aOpcion = (c: ClienteOpcion): OpcionBuscador<number> => ({
  item: c.id,
  label: c.nombre,
  detalle: c.documento,
  nota: c.distrito ?? undefined,
})

const columnas: DataTableColumn<ClienteOpcion>[] = [
  {
    key: 'documento',
    label: 'Documento',
    render: (row) => (
      <span className="flex items-center gap-2">
        <span className="font-medium text-ink">{row.documento}</span>
        <Badge>{row.tipoDoc}</Badge>
      </span>
    ),
  },
  { key: 'nombre', label: 'Nombre' },
  { key: 'distrito', label: 'Distrito', render: (row) => row.distrito ?? '—' },
  { key: 'ruta', label: 'Ruta', render: (row) => row.ruta ?? '—' },
]

/**
 * El cliente de un pedido o una nota de venta.
 *
 * Busca en el servidor: el campo trae las primeras coincidencias de lo que se
 * escribe y la búsqueda avanzada pagina el padrón. Antes cada pantalla
 * descargaba todos los clientes para esto, y el padrón no para de crecer.
 */
export function SelectorCliente({
  para,
  value,
  nombre,
  onChange,
  label = 'Cliente',
}: {
  /** De qué pantalla: acota a los clientes que quien pide puede vender. */
  para: 'pedidos' | 'notaventa'
  value: number | null
  /** El nombre del cliente ya elegido (al editar), para mostrarlo sin buscarlo. */
  nombre?: string
  onChange: (cliente: ClienteOpcion | null) => void
  label?: string
}) {
  // Los clientes que ya llegaron en alguna búsqueda: al elegir uno por su id
  // hace falta su lista de precios.
  const vistos = useRef(new Map<number, ClienteOpcion>())
  const recordar = (lista: ClienteOpcion[]) => lista.forEach((c) => vistos.current.set(c.id, c))

  const [avanzadoAbierto, setAvanzadoAbierto] = useState(false)
  const [pagina, setPagina] = useState<{ items: ClienteOpcion[]; total: number }>({ items: [], total: 0 })
  const [cargando, setCargando] = useState(false)

  const buscar = async (texto: string) => {
    const r = await clienteApi.buscar(
      { pagina: 1, porPagina: COINCIDENCIAS, buscar: texto, orden: null, sentido: null, filtros: [] },
      para,
    )
    recordar(r.items)
    return r.items.map(aOpcion)
  }

  const consultar = async (consulta: ConsultaTabla) => {
    setCargando(true)
    try {
      const r = await clienteApi.buscar(consulta, para)
      recordar(r.items)
      setPagina({ items: r.items, total: r.total })
    } finally {
      setCargando(false)
    }
  }

  // La pantalla guarda el nombre del elegido: así se muestra aunque no haya
  // salido en ninguna búsqueda (al editar un documento ya hecho).
  const seleccionado = value && nombre ? { item: value, label: nombre } : null

  return (
    <>
      <BuscadorCampo
        label={label}
        value={value}
        onChange={(id) => onChange(id ? (vistos.current.get(id) ?? null) : null)}
        buscar={buscar}
        seleccionado={seleccionado}
        placeholder="Buscar cliente..."
        vacio="Ningún cliente coincide"
        onAvanzado={() => setAvanzadoAbierto(true)}
        avanzadoLabel="Búsqueda avanzada de clientes"
      />
      {avanzadoAbierto && (
        <BuscadorModal
          open
          onClose={() => setAvanzadoAbierto(false)}
          title="Elegir cliente"
          description="Busca por documento, nombre, distrito o ruta."
          columns={columnas}
          rows={pagina.items}
          servidor={{ total: pagina.total, cargando, onConsulta: (q) => void consultar(q) }}
          cardIcon={Contact}
          searchPlaceholder="Buscar cliente..."
          onSeleccionar={(c) => {
            recordar([c])
            onChange(c)
          }}
        />
      )}
    </>
  )
}
