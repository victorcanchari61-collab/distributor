import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Building2,
  DoorOpen,
  ListPlus,
  Pencil,
  Plus,
  Trash2,
  X,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { Alert, Badge, BuscadorModal, Button, Checkbox, Desplegable, Input, Modal, RowAction, useConfirmacion, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { productoApi } from '../maestros/productoApi'
import type { ProductoResponse } from '../maestros/productoApi'
import { TIPOS_UBICACION, ubicacionApi } from './inventarioApi'
import type { AlmacenResponse, TipoUbicacion, UbicacionProductoResponse, UbicacionResponse } from './inventarioApi'

const ICONOS: Record<TipoUbicacion, LucideIcon> = {
  PISO: Building2,
  CUARTO: DoorOpen,
}

/** El tipo que se propone al crear algo adentro de otro: un piso lleva cuartos; un cuarto no lleva nada adentro. */
const SIGUIENTE: Record<TipoUbicacion, TipoUbicacion> = {
  PISO: 'CUARTO',
  CUARTO: 'CUARTO',
}

interface FormLugar {
  /** Nulo: se está creando. */
  id: number | null
  padreId: number | null
  /** La ruta del lugar de arriba, solo para mostrar dónde va a quedar. */
  dentroDe: string | null
  tipo: TipoUbicacion
  codigo: string
  nombre: string
  activo: boolean
}

interface FormLote {
  padreId: number | null
  dentroDe: string | null
  tipo: TipoUbicacion
  prefijo: string
  desde: string
  hasta: string
  digitos: string
}

const MAX_LOTE = 100

/**
 * Los lugares de un almacén: pisos y cuartos.
 *
 * Es un árbol: cada lugar lleva su código y la ruta (P1-A-03) es como se nombra. Hoy sirve para decir DÓNDE
 * está cada producto; el stock se sigue contando por almacén.
 */
export function UbicacionesModal({
  almacen,
  onClose,
  onCambio,
}: {
  almacen: AlmacenResponse
  onClose: () => void
  /** Se creó, cambió o borró algo: la lista de almacenes tiene que recontar. */
  onCambio: () => void
}) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [lugares, setLugares] = useState<UbicacionResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [elegido, setElegido] = useState<number | null>(null)

  const [productos, setProductos] = useState<UbicacionProductoResponse[]>([])
  const [catalogo, setCatalogo] = useState<ProductoResponse[] | null>(null)
  const [buscando, setBuscando] = useState(false)

  const [form, setForm] = useState<FormLugar | null>(null)
  const [lote, setLote] = useState<FormLote | null>(null)
  const [guardando, setGuardando] = useState(false)

  const puedeCrear = puede('inv.almacenes', 'crear')
  const puedeEditar = puede('inv.almacenes', 'editar')
  const puedeEliminar = puede('inv.almacenes', 'eliminar')

  const cargar = useCallback(async () => {
    try {
      setLugares(await ubicacionApi.listar(almacen.id))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los lugares.')
    } finally {
      setCargando(false)
    }
  }, [almacen.id])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('ubicaciones', cargar)

  const lugarElegido = useMemo(() => lugares.find((l) => l.id === elegido) ?? null, [lugares, elegido])

  // Los productos del lugar elegido, cada vez que se elige otro o cambia algo.
  useEffect(() => {
    if (elegido === null) {
      setProductos([])
      return
    }
    let vigente = true
    ubicacionApi
      .productos(elegido)
      .then((p) => vigente && setProductos(p))
      .catch(() => vigente && setProductos([]))
    return () => {
      vigente = false
    }
  }, [elegido, lugares])

  const avisarCambio = async () => {
    await cargar()
    onCambio()
  }

  // ------------------------------------------------------------- Crear y editar un lugar

  const nuevo = (padre: UbicacionResponse | null) =>
    setForm({
      id: null,
      padreId: padre?.id ?? null,
      dentroDe: padre?.ruta ?? null,
      tipo: padre ? SIGUIENTE[padre.tipo] : 'PISO',
      codigo: '',
      nombre: '',
      activo: true,
    })

  const editar = (l: UbicacionResponse) =>
    setForm({
      id: l.id,
      padreId: l.padreId,
      dentroDe: null,
      tipo: l.tipo,
      codigo: l.codigo,
      nombre: l.nombre ?? '',
      activo: l.activo,
    })

  const guardar = async () => {
    if (!form) return
    if (!form.codigo.trim()) return toast.error('Ponle un código al lugar.')

    setGuardando(true)
    try {
      const cuerpo = { tipo: form.tipo, codigo: form.codigo.trim(), nombre: form.nombre.trim() || null }
      if (form.id === null) {
        const creado = await ubicacionApi.crear(almacen.id, { ...cuerpo, padreId: form.padreId })
        setElegido(creado.id)
      } else {
        await ubicacionApi.actualizar(form.id, { ...cuerpo, activo: form.activo })
      }
      setForm(null)
      await avisarCambio()
      toast.exito(form.id === null ? 'Lugar creado' : 'Lugar actualizado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el lugar.')
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (l: UbicacionResponse) =>
    confirmar({
      titulo: `Eliminar ${l.ruta}`,
      mensaje: 'Solo se borra un lugar vacío: sin lugares adentro ni productos puestos. Si no, desactívalo.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        try {
          await ubicacionApi.eliminar(l.id)
          if (elegido === l.id) setElegido(null)
          await avisarCambio()
          toast.exito('Lugar eliminado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos eliminar el lugar.')
        }
      },
    })

  // ------------------------------------------------------------- Crear varios

  const abrirLote = (padre: UbicacionResponse | null) =>
    setLote({
      padreId: padre?.id ?? null,
      dentroDe: padre?.ruta ?? null,
      tipo: padre ? SIGUIENTE[padre.tipo] : 'PISO',
      prefijo: '',
      desde: '1',
      hasta: '10',
      digitos: '2',
    })

  const vistaLote = useMemo(() => {
    if (!lote) return null
    const desde = Number(lote.desde)
    const hasta = Number(lote.hasta)
    const digitos = Number(lote.digitos) || 2
    if (!Number.isInteger(desde) || !Number.isInteger(hasta) || hasta < desde) return null
    const total = hasta - desde + 1
    const codigo = (n: number) => lote.prefijo.toUpperCase() + String(n).padStart(digitos, '0')
    return { total, primero: codigo(desde), ultimo: codigo(hasta) }
  }, [lote])

  const generar = async () => {
    if (!lote || !vistaLote) return toast.error('Revisa el "desde" y el "hasta".')
    if (vistaLote.total > MAX_LOTE) return toast.error(`Crea hasta ${MAX_LOTE} lugares por vez.`)

    setGuardando(true)
    try {
      const creados = await ubicacionApi.generar(almacen.id, {
        padreId: lote.padreId,
        tipo: lote.tipo,
        prefijo: lote.prefijo.trim() || undefined,
        desde: Number(lote.desde),
        hasta: Number(lote.hasta),
        digitos: Number(lote.digitos) || 2,
      })
      setLote(null)
      await avisarCambio()
      toast.exito(`${creados.length} lugares creados`)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos crear los lugares.')
    } finally {
      setGuardando(false)
    }
  }

  // ------------------------------------------------------------- Productos del lugar

  const abrirBuscador = async () => {
    setBuscando(true)
    if (catalogo === null) {
      try {
        setCatalogo((await productoApi.getAll()).filter((p) => p.activo))
      } catch (e) {
        setBuscando(false)
        toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los productos.')
      }
    }
  }

  const poner = async (producto: ProductoResponse) => {
    if (elegido === null) return
    try {
      setProductos(await ubicacionApi.asignar(elegido, producto.id))
      await avisarCambio()
      toast.exito(`${producto.nombre} puesto en ${lugarElegido?.ruta ?? 'el lugar'}`)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos poner el producto.')
    }
  }

  const quitar = async (p: UbicacionProductoResponse) => {
    if (elegido === null) return
    try {
      setProductos(await ubicacionApi.quitar(elegido, p.productoId))
      await avisarCambio()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos quitar el producto.')
    }
  }

  const columnasProducto: DataTableColumn<ProductoResponse>[] = [
    { key: 'codigo', label: 'Código', filterable: false },
    { key: 'nombre', label: 'Producto', filterable: false },
    { key: 'categoria', label: 'Categoría', render: (p) => p.categoria ?? '—' },
  ]

  const yaPuestos = useMemo(() => new Set(productos.map((p) => p.productoId)), [productos])

  return (
    <Modal
      open
      size="2xl"
      title={`Ubicaciones de ${almacen.nombre}`}
      description="Pisos y cuartos. Sirve para saber dónde está cada producto."
      onClose={onClose}
      footer={
        <Button variant="secondary" size="sm" onClick={onClose}>
          Cerrar
        </Button>
      }
    >
      {error && <Alert>{error}</Alert>}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
        {/* El árbol */}
        <section className="min-w-0 space-y-2">
          {puedeCrear && (
            <div className="flex flex-wrap gap-2">
              <Button size="sm" onClick={() => nuevo(null)} iconRight={<Plus size={14} />}>
                Nuevo lugar
              </Button>
              <Button size="sm" variant="secondary" onClick={() => abrirLote(null)} iconRight={<ListPlus size={14} />}>
                Crear varios
              </Button>
            </div>
          )}

          <div className="max-h-[26rem] overflow-y-auto rounded-panel border border-line bg-white">
            {cargando ? (
              <p className="p-6 text-center text-sm text-ink-soft">Cargando lugares...</p>
            ) : lugares.length === 0 ? (
              <div className="p-8 text-center">
                <p className="font-medium text-ink">Este almacén todavía no tiene lugares definidos</p>
                <p className="mx-auto mt-1 max-w-sm text-sm text-ink-soft">
                  Empieza por los pisos (P1, P2), y adentro de cada uno sus cuartos (C1, C2...).
                </p>
              </div>
            ) : (
              <ul className="divide-y divide-line">
                {lugares.map((l) => {
                  const Icono = ICONOS[l.tipo]
                  return (
                    <li key={l.id}>
                      <div
                        className={`flex items-center gap-2 py-1.5 pr-2 ${l.id === elegido ? 'bg-[rgb(var(--sys-rgb)/0.08)]' : 'hover:bg-surface-alt'} ${l.activo ? '' : 'opacity-60'}`}
                        style={{ paddingLeft: 8 + l.nivel * 18 }}
                      >
                        <button
                          type="button"
                          onClick={() => setElegido(l.id)}
                          className="flex min-w-0 flex-1 cursor-pointer items-center gap-2 text-left"
                        >
                          <Icono size={15} className="shrink-0 text-ink-soft" />
                          <span className="font-semibold text-ink">{l.codigo}</span>
                          <span className="truncate text-sm text-ink-soft">
                            {l.nombre ?? l.tipoEtiqueta}
                          </span>
                          {l.productos > 0 && <Badge tone="sys">{l.productos}</Badge>}
                          {!l.activo && <Badge>Inactivo</Badge>}
                        </button>

                        <span className="flex shrink-0 items-center">
                          {puedeCrear && l.activo && l.tipo === 'PISO' && (
                            <RowAction label={`Agregar adentro de ${l.ruta}`} tone="success" onClick={() => nuevo(l)}>
                              <Plus size={14} />
                            </RowAction>
                          )}
                          {puedeCrear && l.activo && l.tipo === 'PISO' && (
                            <RowAction label={`Crear varios adentro de ${l.ruta}`} tone="view" onClick={() => abrirLote(l)}>
                              <ListPlus size={14} />
                            </RowAction>
                          )}
                          {puedeEditar && (
                            <RowAction label={`Editar ${l.ruta}`} onClick={() => editar(l)}>
                              <Pencil size={14} />
                            </RowAction>
                          )}
                          {puedeEliminar && (
                            <RowAction label={`Eliminar ${l.ruta}`} tone="danger" onClick={() => eliminar(l)}>
                              <Trash2 size={14} />
                            </RowAction>
                          )}
                        </span>
                      </div>
                    </li>
                  )
                })}
              </ul>
            )}
          </div>
        </section>

        {/* Lo que hay en el lugar elegido */}
        <section className="min-w-0 space-y-2 rounded-panel border border-line bg-white p-3">
          {!lugarElegido ? (
            <p className="py-10 text-center text-sm text-ink-soft">
              Elige un lugar para ver qué productos hay puestos ahí.
            </p>
          ) : (
            <>
              <div>
                <p className="text-xs text-ink-soft">{lugarElegido.tipoEtiqueta}</p>
                <h3 className="text-lg font-bold text-ink">{lugarElegido.ruta}</h3>
                {lugarElegido.nombre && <p className="text-sm text-ink-muted">{lugarElegido.nombre}</p>}
              </div>

              <div className="flex items-center justify-between gap-2">
                <p className="text-sm font-semibold text-ink">Productos aquí ({productos.length})</p>
                {puedeEditar && lugarElegido.activo && (
                  <Button size="sm" variant="secondary" onClick={() => void abrirBuscador()} iconRight={<Plus size={14} />}>
                    Poner producto
                  </Button>
                )}
              </div>

              {productos.length === 0 ? (
                <p className="rounded-field border border-dashed border-line px-3 py-6 text-center text-sm text-ink-soft">
                  Todavía no hay productos puestos en este lugar.
                </p>
              ) : (
                <ul className="max-h-72 divide-y divide-line overflow-y-auto">
                  {productos.map((p) => (
                    <li key={p.productoId} className="flex items-center justify-between gap-2 py-1.5">
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-medium text-ink">{p.producto}</span>
                        <span className="text-xs text-ink-soft">
                          {p.codigo}
                          {p.categoria ? ` · ${p.categoria}` : ''}
                        </span>
                      </span>
                      {puedeEditar && (
                        <RowAction label={`Quitar ${p.producto}`} tone="danger" onClick={() => void quitar(p)}>
                          <X size={14} />
                        </RowAction>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </section>
      </div>

      {/* Crear o editar un lugar */}
      <Modal
        open={form !== null}
        size="sm"
        title={form?.id === null ? 'Nuevo lugar' : `Editar ${form?.codigo ?? ''}`}
        description={form?.dentroDe ? `Va adentro de ${form.dentroDe}` : form?.id === null ? 'En la raíz del almacén' : undefined}
        onClose={() => setForm(null)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setForm(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {form?.id === null ? 'Crear' : 'Guardar'}
            </Button>
          </>
        }
      >
        {form && (
          <div className="flex flex-col gap-4">
            <Desplegable
              label="Qué es"
              value={form.tipo}
              onChange={(v) => setForm({ ...form, tipo: v as TipoUbicacion })}
              // Adentro de un piso solo van cuartos; un piso va directo en el almacén.
              options={TIPOS_UBICACION.filter((t) => form.padreId === null || t.value === 'CUARTO').map((t) => ({ value: t.value, label: t.label }))}
            />
            <Input
              label="Código"
              placeholder="P1, C1"
              value={form.codigo}
              maxLength={20}
              onChange={(e) => setForm({ ...form, codigo: e.target.value.toUpperCase().replace(/[^A-Z0-9._]/g, '') })}
            />
            <Input
              label="Nombre"
              optional
              placeholder="Primer piso, Abarrotes..."
              value={form.nombre}
              onChange={(e) => setForm({ ...form, nombre: e.target.value })}
            />
            {form.id !== null && (
              <Checkbox
                label="Activo"
                checked={form.activo}
                onChange={(e) => setForm({ ...form, activo: e.target.checked })}
              />
            )}
          </div>
        )}
      </Modal>

      {/* Crear varios de una vez */}
      <Modal
        open={lote !== null}
        size="sm"
        title="Crear varios lugares"
        description={lote?.dentroDe ? `Adentro de ${lote.dentroDe}` : 'En la raíz del almacén'}
        onClose={() => setLote(null)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setLote(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} disabled={!vistaLote} onClick={() => void generar()}>
              {vistaLote ? `Crear ${vistaLote.total}` : 'Crear'}
            </Button>
          </>
        }
      >
        {lote && (
          <div className="flex flex-col gap-4">
            <Desplegable
              label="Qué son"
              value={lote.tipo}
              onChange={(v) => setLote({ ...lote, tipo: v as TipoUbicacion })}
              options={TIPOS_UBICACION.filter((t) => lote.padreId === null || t.value === 'CUARTO').map((t) => ({ value: t.value, label: t.label }))}
            />
            <Input
              label="Prefijo del código"
              optional
              placeholder="E"
              value={lote.prefijo}
              maxLength={10}
              onChange={(e) => setLote({ ...lote, prefijo: e.target.value.toUpperCase().replace(/[^A-Z0-9._]/g, '') })}
            />
            <div className="grid grid-cols-3 gap-3">
              <Input label="Desde" inputMode="numeric" value={lote.desde} onChange={(e) => setLote({ ...lote, desde: e.target.value.replace(/\D/g, '') })} />
              <Input label="Hasta" inputMode="numeric" value={lote.hasta} onChange={(e) => setLote({ ...lote, hasta: e.target.value.replace(/\D/g, '') })} />
              <Input label="Dígitos" inputMode="numeric" value={lote.digitos} onChange={(e) => setLote({ ...lote, digitos: e.target.value.replace(/\D/g, '') })} />
            </div>
            <p className="rounded-field bg-surface-alt px-3 py-2 text-sm text-ink-muted">
              {vistaLote
                ? vistaLote.total > MAX_LOTE
                  ? `Son ${vistaLote.total}: crea hasta ${MAX_LOTE} por vez.`
                  : `Se crearán ${vistaLote.total}: ${vistaLote.primero}${vistaLote.total > 1 ? ` … ${vistaLote.ultimo}` : ''}`
                : 'Revisa el "desde" y el "hasta".'}
            </p>
          </div>
        )}
      </Modal>

      <BuscadorModal
        open={buscando && catalogo !== null}
        onClose={() => setBuscando(false)}
        title="Poner un producto en este lugar"
        description={lugarElegido ? `Se pondrá en ${lugarElegido.ruta}` : undefined}
        columns={columnasProducto}
        rows={(catalogo ?? []).filter((p) => !yaPuestos.has(p.id))}
        rowKey="id"
        searchPlaceholder="Buscar producto..."
        empty="No hay más productos para poner."
        onSeleccionar={(p) => void poner(p)}
      />

      {dialogo}
    </Modal>
  )
}
