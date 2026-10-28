import { useEffect, useState } from 'react'
import { Input, Select } from '../../components/ui'
import { hoyLocal } from '../../lib/fechas'
import { usuarioApi } from '../config/usuarioApi'
import type { UsuarioResponse } from '../config/usuarioApi'
import { mercadoApi, rutaApi } from '../tms'
import type { MercadoResponse, RutaResponse } from '../tms'

/** El 1 de enero de este año: desde donde miden los reportes si nadie elige fechas. */
export const inicioDeAnio = () => `${hoyLocal().slice(0, 4)}-01-01`

/** Mercados, rutas y vendedores activos para los filtros de los reportes. */
export function useCatalogosCrm() {
  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [usuarios, setUsuarios] = useState<UsuarioResponse[]>([])

  useEffect(() => {
    void Promise.all([mercadoApi.getAll(), rutaApi.getAll(), usuarioApi.getAll()])
      .then(([mer, rut, usr]) => {
        setMercados(mer.filter((m) => m.activo))
        setRutas(rut.filter((r) => r.activo))
        setUsuarios(usr.filter((u) => u.activo))
      })
      .catch(() => {
        /* Sin catálogos el reporte sigue sirviendo: solo se pierde filtrar. */
      })
  }, [])

  return { mercados, rutas, usuarios }
}

/** El rango de fechas de un reporte: del 1 de enero a hoy si nadie lo toca. */
export function FiltroFechas({
  desde,
  hasta,
  onChange,
}: {
  desde: string
  hasta: string
  onChange: (desde: string, hasta: string) => void
}) {
  const porDefecto = desde === inicioDeAnio() && hasta === hoyLocal()

  return (
    <div className="flex items-end gap-2">
      <div className="w-40">
        <Input label="Desde" size="sm" type="date" max={hasta || undefined} value={desde} onChange={(e) => onChange(e.target.value, hasta)} />
      </div>
      <div className="w-40">
        <Input label="Hasta" size="sm" type="date" min={desde || undefined} max={hoyLocal()} value={hasta} onChange={(e) => onChange(desde, e.target.value)} />
      </div>
      {!porDefecto && (
        <button
          type="button"
          onClick={() => onChange(inicioDeAnio(), hoyLocal())}
          className="mb-2 text-xs font-medium whitespace-nowrap text-sky-600 hover:underline"
        >
          1 ene – hoy
        </button>
      )}
    </div>
  )
}

/** Un selector de "todos" más las opciones de un catálogo. */
export function SelectorCatalogo({
  etiqueta,
  todos,
  valor,
  opciones,
  onChange,
}: {
  etiqueta: string
  todos: string
  valor: number | undefined
  opciones: { id: number; nombre: string }[]
  onChange: (id: number | undefined) => void
}) {
  return (
    <div className="w-44">
      <Select label={etiqueta} size="sm" value={valor ?? ''} onChange={(e) => onChange(Number(e.target.value) || undefined)}>
        <option value="">{todos}</option>
        {opciones.map((o) => (
          <option key={o.id} value={o.id}>
            {o.nombre}
          </option>
        ))}
      </Select>
    </div>
  )
}
