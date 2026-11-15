import { useCallback, useEffect, useMemo, useState } from 'react'
import { Building2, DoorOpen, Plus } from 'lucide-react'
import { FaPencil, FaPlus, FaTrash, FaXmark } from 'react-icons/fa6'
import type { LucideIcon } from 'lucide-react'
import { Alert, Badge, BuscadorModal, Button, Checkbox, Input, Modal, RowAction, useConfirmacion, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { productoApi } from '../maestros/productoApi'
import type { ProductoResponse } from '../maestros/productoApi'
import { ubicacionApi } from './inventarioApi'
import type { AlmacenResponse, TipoUbicacion, UbicacionProductoResponse, UbicacionResponse } from './inventarioApi'

const ICONOS: Record<TipoUbicacion, LucideIcon> = {
  PISO: Building2,
  CUARTO: DoorOpen,
}

/** Cómo se dice cada nivel en pantalla, y con qué letra empieza su código. */
const NIVEL: Record<TipoUbicacion, { uno: string; ejemplos: string; letra: string }> = {
  PISO: { uno: 'piso', ejemplos: 'Primer piso, Azotea, Sótano...', letra: 'P' },
  CUARTO: { uno: 'cuarto', ejemplos: 'Cocina, Sala, Abarrotes...', letra: 'C' },
}

/**
 * El código que le toca al próximo lugar de un nivel: la letra del nivel y el número que sigue al más alto entre los
 * hermanos (con P1 y P2, sale P3). Es la misma regla del servidor. Sale puesto en el formulario y se puede cambiar.
 */
function siguienteCodigo(hermanos: UbicacionResponse[], tipo: TipoUbicacion): string {
  const letra = NIVEL[tipo].letra
  const ocupados = new Set(hermanos.map((h) => h.codigo.toUpperCase()))
  let n = Math.max(0, ...hermanos.map((h) => {
    const m = new RegExp(`^${letra}(\\d+)$`, 'i').exec(h.codigo)
    return m ? Number(m[1]) : 0
  })) + 1
  while (ocupados.has(`${letra}${n}`)) n++
  return `${letra}${n}`
}

interface FormLugar {
  /** Nulo: se está creando. */
  id: number | null
  padreId: number | null
  /** La ruta del lugar de arriba, solo para mostrar dónde va a quedar. */
  dentroDe: string | null
  /** Lo decide dónde se crea: en la raíz, lo que use el almacén; adentro de un piso, un cuarto. No se cambia. */
  tipo: TipoUbicacion
  /** Al crear sale puesto el siguiente del nivel (P3, C2...); se puede cambiar. */
  codigo: string
  nombre: string
  activo: boolean
}

/**
 * Los lugares de un almacén: pisos y cuartos.
 *
 * Son dos niveles: el almacén tiene pisos y cada piso sus cuartos (P1-C2). Un almacén de un solo ambiente no usa
 * pisos: tiene sus cuartos sueltos. Lo decide el primer lugar que se crea, y desde ahí la pantalla solo ofrece eso.
 * El nivel sale de dónde se hace clic y el código sale puesto: la persona solo escribe el nombre. Hoy sirve para
 * decir DÓNDE está cada producto; el stock se sigue contando por almacén.
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

  // Lo que usa el almacén en la raíz: pisos, o cuartos sueltos. Nulo mientras está vacío (se elige al crear el primero).
  const tipoRaiz: TipoUbicacion | null = useMemo(() => {
    const raiz = lugares.filter((l) => l.padreId === null)
    if (raiz.some((l) => l.tipo === 'PISO')) return 'PISO'
    return raiz.length > 0 ? 'CUARTO' : null
  }, [lugares])

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

  const nuevo = (padre: UbicacionResponse | null, tipo: TipoUbicacion) => {
    const nivel: TipoUbicacion = padre ? 'CUARTO' : tipo
    const padreId = padre?.id ?? null
    setForm({
      id: null,
      padreId,
      dentroDe: padre ? `${padre.ruta}${padre.nombre ? ` · ${padre.nombre}` : ''}` : null,
      tipo: nivel,
      codigo: siguienteCodigo(lugares.filter((l) => l.padreId === padreId), nivel),
      nombre: '',
      activo: true,
    })
  }

  const editar = (l: UbicacionResponse) =>
    setForm({
      id: l.id,
      padreId: l.padreId,
      dentroDe: l.ruta,
      tipo: l.tipo,
      codigo: l.codigo,
      nombre: l.nombre ?? '',
      activo: l.activo,
    })

  const guardar = async () => {
    if (!form) return
    if (form.id === null && !form.nombre.trim()) return toast.error(`Ponle un nombre al ${NIVEL[form.tipo].uno}.`)
    if (!form.codigo.trim()) return toast.error('Ponle un código al lugar.')

    setGuardando(true)
    try {
      if (form.id === null) {
        const creado = await ubicacionApi.crear(almacen.id, {
          padreId: form.padreId,
          tipo: form.tipo,
          codigo: form.codigo.trim(),
          nombre: form.nombre.trim(),
        })
        setElegido(creado.id)
      } else {
        await ubicacionApi.actualizar(form.id, { codigo: form.codigo.trim(), nombre: form.nombre.trim() || null, activo: form.activo })
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
      description="Pisos y cuartos o zonas. Sirve para saber dónde está cada producto."
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
          {puedeCrear && tipoRaiz && (
            <div className="flex flex-wrap gap-2">
              <Button size="sm" onClick={() => nuevo(null, tipoRaiz)} iconRight={<Plus size={14} />}>
                Nuevo {NIVEL[tipoRaiz].uno}
              </Button>
            </div>
          )}

          <div className="max-h-[26rem] overflow-y-auto rounded-panel border border-line bg-white">
            {cargando ? (
              <p className="p-6 text-center text-sm text-ink-soft">Cargando lugares...</p>
            ) : lugares.length === 0 ? (
              <div className="p-6 text-center">
                <p className="font-medium text-ink">Este almacén todavía no tiene lugares</p>
                <p className="mx-auto mt-1 max-w-sm text-sm text-ink-soft">¿Cómo está armado?</p>
                {puedeCrear && (
                  <div className="mx-auto mt-4 grid max-w-md gap-2 sm:grid-cols-2">
                    <button
                      type="button"
                      onClick={() => nuevo(null, 'PISO')}
                      className="cursor-pointer rounded-panel border border-line p-3 text-left hover:border-[rgb(var(--sys-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.05)]"
                    >
                      <Building2 size={18} className="text-[rgb(var(--sys-rgb))]" />
                      <p className="mt-1 text-sm font-semibold text-ink">Tiene pisos</p>
                      <p className="text-xs text-ink-soft">Primero creas los pisos y después, adentro de cada uno, sus cuartos.</p>
                    </button>
                    <button
                      type="button"
                      onClick={() => nuevo(null, 'CUARTO')}
                      className="cursor-pointer rounded-panel border border-line p-3 text-left hover:border-[rgb(var(--sys-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.05)]"
                    >
                      <DoorOpen size={18} className="text-[rgb(var(--sys-rgb))]" />
                      <p className="mt-1 text-sm font-semibold text-ink">Un solo ambiente</p>
                      <p className="text-xs text-ink-soft">Sin pisos: creas directo sus cuartos o zonas (cocina, abarrotes...).</p>
                    </button>
                  </div>
                )}
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
                            <RowAction label={`Agregar un cuarto en ${l.ruta}`} tone="success" onClick={() => nuevo(l, 'CUARTO')}>
                              <FaPlus size={14} />
                            </RowAction>
                          )}
                          {puedeEditar && (
                            <RowAction label={`Editar ${l.ruta}`} onClick={() => editar(l)}>
                              <FaPencil size={14} />
                            </RowAction>
                          )}
                          {puedeEliminar && (
                            <RowAction label={`Eliminar ${l.ruta}`} tone="danger" onClick={() => eliminar(l)}>
                              <FaTrash size={14} />
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
                          <FaXmark size={14} />
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
        title={form ? (form.id === null ? `Nuevo ${NIVEL[form.tipo].uno}` : `Editar ${NIVEL[form.tipo].uno} ${form.dentroDe ?? ''}`) : ''}
        description={form?.id === null ? (form.dentroDe ? `Adentro de ${form.dentroDe}` : `En ${almacen.nombre}`) : undefined}
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
            <div className="grid grid-cols-[6rem_minmax(0,1fr)] gap-3">
              <Input
                label="Código"
                value={form.codigo}
                maxLength={20}
                onChange={(e) => setForm({ ...form, codigo: e.target.value.toUpperCase().replace(/[^A-Z0-9._]/g, '') })}
              />
              <Input
                label="Nombre"
                autoFocus
                placeholder={NIVEL[form.tipo].ejemplos}
                value={form.nombre}
                maxLength={80}
                onChange={(e) => setForm({ ...form, nombre: e.target.value })}
                onKeyDown={(e) => e.key === 'Enter' && void guardar()}
              />
            </div>
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
