import { useCallback, useEffect, useState } from 'react'
import { LayoutList, MapPin, Pencil, Plus, ShieldCheck, ShieldOff, Star, Warehouse } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Checkbox,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { ubigeoApi } from '../../lib/ubigeoApi'
import type { DepartamentoResponse, DistritoResponse, ProvinciaResponse } from '../../lib/ubigeoApi'
import { almacenApi, TIPOS_ALMACEN } from './inventarioApi'
import type { AlmacenResponse, TipoAlmacen } from './inventarioApi'
import { UbicacionesModal } from './UbicacionesModal'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'

interface FormAlmacen {
  codigo: string
  nombre: string
  tipo: TipoAlmacen
  direccion: string
  departamentoId: number
  provinciaId: number
  distritoId: number
  referencia: string
  responsable: string
  telefono: string
  esPrincipal: boolean
}

const VACIO: FormAlmacen = {
  codigo: '',
  nombre: '',
  tipo: 'ALMACEN',
  direccion: '',
  departamentoId: 0,
  provinciaId: 0,
  distritoId: 0,
  referencia: '',
  responsable: '',
  telefono: '',
  esPrincipal: false,
}

/** La dirección en una línea: calle, distrito y provincia. */
const direccionCompleta = (a: AlmacenResponse) =>
  [a.direccion, a.distrito, a.provincia && a.provincia !== a.distrito ? a.provincia : null]
    .filter(Boolean)
    .join(', ')

export function AlmacenesPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<AlmacenResponse | null>(null)
  const [form, setForm] = useState<FormAlmacen>(VACIO)
  const [guardando, setGuardando] = useState(false)

  // El almacén cuyas ubicaciones se están viendo.
  const [conLugares, setConLugares] = useState<number | null>(null)

  const [departamentos, setDepartamentos] = useState<DepartamentoResponse[]>([])
  const [provincias, setProvincias] = useState<ProvinciaResponse[]>([])
  const [distritos, setDistritos] = useState<DistritoResponse[]>([])

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setAlmacenes(await almacenApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los almacenes.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['almacenes', 'ubicaciones'], cargar)

  // El ubigeo oficial se pide una sola vez, al abrir el primer formulario.
  const cargarUbigeo = useCallback(async () => {
    if (departamentos.length > 0) return
    try {
      const [dep, prov, dist] = await Promise.all([
        ubigeoApi.departamentos(),
        ubigeoApi.provincias(),
        ubigeoApi.distritos(),
      ])
      setDepartamentos(dep)
      setProvincias(prov)
      setDistritos(dist)
    } catch {
      /* Sin ubigeo se puede guardar el almacén igual, solo sin distrito. */
    }
  }, [departamentos.length])

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setAbierto(true)
    void cargarUbigeo()
  }

  const abrirEdicion = (a: AlmacenResponse) => {
    setEditando(a)
    setForm({
      codigo: a.codigo,
      nombre: a.nombre,
      tipo: a.tipo,
      direccion: a.direccion ?? '',
      departamentoId: a.departamentoId ?? 0,
      provinciaId: a.provinciaId ?? 0,
      distritoId: a.distritoId ?? 0,
      referencia: a.referencia ?? '',
      responsable: a.responsable ?? '',
      telefono: a.telefono ?? '',
      esPrincipal: a.esPrincipal,
    })
    setAbierto(true)
    void cargarUbigeo()
  }

  const guardar = async () => {
    if (!form.codigo.trim()) return toast.error('Ingresa el código.')
    if (!form.nombre.trim()) return toast.error('Ingresa el nombre.')

    setGuardando(true)
    try {
      const cuerpo = {
        codigo: form.codigo.trim(),
        nombre: form.nombre.trim(),
        tipo: form.tipo,
        direccion: form.direccion.trim() || null,
        distritoId: form.distritoId || null,
        referencia: form.referencia.trim() || null,
        responsable: form.responsable.trim() || null,
        telefono: form.telefono.trim() || null,
        esPrincipal: form.esPrincipal,
      }
      if (editando) {
        await almacenApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      } else {
        await almacenApi.create(cuerpo)
      }
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Almacén actualizado' : 'Almacén creado')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar el almacén.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (a: AlmacenResponse) =>
    confirmar({
      titulo: `${a.activo ? 'Desactivar' : 'Activar'} ${a.nombre}`,
      mensaje: a.activo
        ? 'Deja de recibir movimientos nuevos. Su historial se conserva.'
        : 'Vuelve a estar disponible para movimientos.',
      confirmar: a.activo ? 'Desactivar' : 'Activar',
      tono: a.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await almacenApi.update(a.id, {
            codigo: a.codigo,
            nombre: a.nombre,
            tipo: a.tipo,
            direccion: a.direccion,
            distritoId: a.distritoId,
            referencia: a.referencia,
            responsable: a.responsable,
            telefono: a.telefono,
            esPrincipal: a.esPrincipal,
            activo: !a.activo,
          })
          await cargar()
          toast.exito(`${a.nombre} ${a.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  /** Los valores que de verdad hay en esa columna, para elegir y no teclear. */
  const distintos = (valores: (string | null)[]) =>
    [...new Set(valores.map((v) => v?.trim()).filter((v): v is string => !!v))]
      .sort((a, b) => a.localeCompare(b, 'es'))
      .map((v) => ({ value: v, label: v }))

  const columns: DataTableColumn<AlmacenResponse>[] = [
    // Nombre y código se buscan con el buscador de arriba, no en el panel.
    {
      key: 'nombre',
      label: 'Nombre',
      filterable: false,
      render: (row) => (
        <span className="flex items-center gap-2">
          {row.nombre}
          {row.esPrincipal && <Badge tone="sys">Principal</Badge>}
        </span>
      ),
    },
    { key: 'codigo', label: 'Código', filterable: false, render: (row) => <Badge>{row.codigo}</Badge> },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: TIPOS_ALMACEN.map((t) => ({ value: t.value, label: t.label })),
      value: (row) => row.tipo,
      render: (row) => row.tipoEtiqueta,
    },
    {
      key: 'direccion',
      label: 'Dirección',
      filterType: 'select',
      filterOptions: distintos(almacenes.map((a) => a.distrito)),
      // El filtro es por distrito: es lo que de verdad se repite entre almacenes.
      value: (row) => row.distrito ?? '',
      render: (row) => direccionCompleta(row) || <span className="text-ink-soft">—</span>,
    },
    {
      key: 'referencia',
      label: 'Referencia',
      filterable: false,
      value: (row) => row.referencia ?? '',
      render: (row) => row.referencia || <span className="text-ink-soft">—</span>,
    },
    {
      key: 'responsable',
      label: 'Responsable',
      filterType: 'select',
      filterOptions: distintos(almacenes.map((a) => a.responsable)),
      value: (row) => row.responsable ?? '',
      render: (row) => row.responsable || <span className="text-ink-soft">—</span>,
    },
    {
      key: 'telefono',
      label: 'Teléfono',
      filterable: false,
      value: (row) => row.telefono ?? '',
      render: (row) => row.telefono || <span className="text-ink-soft">—</span>,
    },
    {
      key: 'ubicaciones',
      label: 'Lugares',
      align: 'right',
      filterable: false,
      render: (row) => (row.ubicaciones > 0 ? row.ubicaciones : <span className="text-ink-soft">—</span>),
    },
    /*
     * Cantidades e importes no entran al panel: el unico control es un
     * buscador de texto, y "9" contra "S/ 9.00" no encuentra lo esperado.
     */
    { key: 'productos', label: 'Productos', align: 'right', filterable: false },
    {
      key: 'valorizado',
      label: 'Valorizado',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.valorizado.toFixed(2)}`,
    },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>
          {row.activo ? 'Activo' : 'Inactivo'}
        </Badge>
      ),
    },
  ]

  const almacenConLugares = almacenes.find((a) => a.id === conLugares) ?? null

  return (
    <ListPage
      icon={<Warehouse size={20} />}
      title="Almacenes"
      description="Dónde se guarda la mercadería: sus datos, su dirección y cómo está organizado por dentro."
      actions={
        puede('inv.almacenes', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo almacén
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Almacenes"
            value={String(almacenes.length)}
            icon={<Warehouse size={18} />}
          />
          <StatCard
            label="Lugares definidos"
            value={String(almacenes.reduce((n, a) => n + a.ubicaciones, 0))}
            hint="pisos y cuartos"
            icon={<MapPin size={18} />}
            tono="neutral"
          />
          <StatCard
            label="Valor total"
            value={`S/ ${almacenes.reduce((n, a) => n + a.valorizado, 0).toFixed(2)}`}
            icon={<Star size={18} />}
            tono="success"
            hint="al costo de compra"
          />
        </>
      }
      columns={columns}
      rows={almacenes}
      cardIcon={Warehouse}
      searchPlaceholder="Buscar almacén..."
      empty={cargando ? 'Cargando almacenes...' : 'Todavía no hay almacenes.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ubicaciones de ${row.nombre}`} tone="view" onClick={() => setConLugares(row.id)}>
            <LayoutList size={15} />
          </RowAction>
          {puede('inv.almacenes', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {!row.esPrincipal && puede('inv.almacenes', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => cambiarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="lg"
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo almacén'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear almacén'}
            </Button>
          </>
        }
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Input
            label="Código"
            placeholder="ALM-02"
            value={form.codigo}
            onChange={(e) => setForm({ ...form, codigo: e.target.value.toUpperCase() })}
          />
          <Desplegable
            label="Tipo"
            value={form.tipo}
            onChange={(v) => setForm({ ...form, tipo: v as TipoAlmacen })}
            options={TIPOS_ALMACEN.map((t) => ({ value: t.value, label: t.label }))}
          />
          <Input
            label="Nombre"
            className="sm:col-span-2"
            placeholder="Depósito norte"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <p className="-mb-2 text-xs font-semibold tracking-wide text-ink-soft uppercase sm:col-span-2">Ubicación</p>
          <Input
            label="Dirección"
            optional
            className="sm:col-span-2"
            placeholder="Av. Grau 123, Mz B Lt 7"
            value={form.direccion}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />
          <Desplegable
            label="Departamento"
            optional
            value={form.departamentoId}
            onChange={(v) => setForm({ ...form, departamentoId: Number(v), provinciaId: 0, distritoId: 0 })}
            options={[{ value: 0, label: 'Elegir' }, ...departamentos.map((d) => ({ value: d.id, label: d.nombre }))]}
          />
          <Desplegable
            label="Provincia"
            optional
            disabled={!form.departamentoId}
            value={form.provinciaId}
            onChange={(v) => setForm({ ...form, provinciaId: Number(v), distritoId: 0 })}
            options={[
              { value: 0, label: 'Elegir' },
              ...provincias
                .filter((p) => p.departamentoId === form.departamentoId)
                .map((p) => ({ value: p.id, label: p.nombre })),
            ]}
          />
          <Desplegable
            label="Distrito"
            optional
            disabled={!form.provinciaId}
            value={form.distritoId}
            onChange={(v) => setForm({ ...form, distritoId: Number(v) })}
            options={[
              { value: 0, label: 'Elegir' },
              ...distritos
                .filter((d) => d.provinciaId === form.provinciaId)
                .map((d) => ({ value: d.id, label: d.nombre })),
            ]}
          />
          <Input
            label="Referencia"
            optional
            placeholder="Frente al mercado, portón verde"
            value={form.referencia}
            onChange={(e) => setForm({ ...form, referencia: e.target.value })}
          />

          <p className="-mb-2 text-xs font-semibold tracking-wide text-ink-soft uppercase sm:col-span-2">A cargo</p>
          <Input
            label="Responsable"
            optional
            value={form.responsable}
            onChange={(e) => setForm({ ...form, responsable: e.target.value })}
          />
          <Input
            label="Teléfono"
            optional
            inputMode="tel"
            value={form.telefono}
            onChange={(e) => setForm({ ...form, telefono: e.target.value })}
          />

          <div className="sm:col-span-2">
            <Checkbox
              label="Almacén principal"
              checked={form.esPrincipal}
              onChange={(e) => setForm({ ...form, esPrincipal: e.target.checked })}
            />
            <p className="mt-1 text-xs text-ink-soft">
              Solo uno puede serlo: es el que sale por defecto en pedidos y ventas, y del que se muestra
              el stock al buscar productos. Marcarlo aquí desmarca al anterior.
            </p>
          </div>

          {!editando && (
            <p className="rounded-field bg-surface-alt px-3 py-2 text-sm text-ink-muted sm:col-span-2">
              Los pisos y cuartos se arman después, con el botón «Ubicaciones» de la lista.
            </p>
          )}
        </div>
      </Modal>

      {almacenConLugares && (
        <UbicacionesModal almacen={almacenConLugares} onClose={() => setConLugares(null)} onCambio={() => void cargar()} />
      )}

      {dialogo}
    </ListPage>
  )
}
