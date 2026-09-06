import { useCallback, useEffect, useState } from 'react'
import {
  Contact,
  MapPin,
  Pencil,
  Plus,
  Route,
  ShieldCheck,
  ShieldOff,
  Trash2,
  Upload,
} from 'lucide-react'
import {
  Alert,
  Badge,
  BotonMas,
  Button,
  Desplegable,
  DocumentoInput,
  ImportarModal,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
} from '../../components/ui'
import type { ConsultaTabla, DataTableColumn, TipoDocumento } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { valorDe } from '../../lib/excel'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { ubigeoApi } from '../../lib/ubigeoApi'
import type { DepartamentoResponse, DistritoResponse, ProvinciaResponse } from '../../lib/ubigeoApi'
import { mercadoApi, rutaApi } from '../tms'
import type { MercadoResponse, RutaResponse } from '../tms'
import { clienteApi } from './clienteApi'
import type { ClienteRequest, ClienteResponse, ResumenClientes } from './clienteApi'

const VACIO: ClienteRequest = {
  documento: '',
  tipoDoc: 'DNI',
  nombre: '',
  direccion: '',
  distritoId: 0,
  telefono: '',
  email: '',
  diaVisita: '',
  rutaId: 0,
  mercadoId: 0,
}

const DIAS = ['LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO']

export function ClientesPage() {
  const { puede } = usePermisos()
  const [clientes, setClientes] = useState<ClienteResponse[]>([])
  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [departamentos, setDepartamentos] = useState<DepartamentoResponse[]>([])
  const [provincias, setProvincias] = useState<ProvinciaResponse[]>([])
  const [distritos, setDistritos] = useState<DistritoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [importando, setImportando] = useState(false)
  const [editando, setEditando] = useState<ClienteResponse | null>(null)
  const [form, setForm] = useState<ClienteRequest>(VACIO)
  // Solo para encadenar los selects del formulario: lo unico que se manda es
  // form.distritoId, pero para mostrar provincias/distritos hay que saber que
  // departamento y provincia se eligieron primero.
  const [ubigeoSel, setUbigeoSel] = useState({ departamentoId: 0, provinciaId: 0 })
  const [guardando, setGuardando] = useState(false)
  const [consultando, setConsultando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [nuevoMercado, setNuevoMercado] = useState(false)
  const [nombreMercado, setNombreMercado] = useState('')
  const [creandoMercado, setCreandoMercado] = useState(false)
  const [errorMercado, setErrorMercado] = useState('')

  const [nuevaRuta, setNuevaRuta] = useState(false)
  const [nombreRuta, setNombreRuta] = useState('')
  const [creandoRuta, setCreandoRuta] = useState(false)
  const [errorRuta, setErrorRuta] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  /*
   * El listado NO se trae entero: la tabla dice qué página necesita y solo esa
   * se pide. Con ~2000 clientes, traerlos todos en cada carga era el grueso
   * del tiempo de la pantalla.
   *
   * Los contadores de arriba y las opciones de los filtros no salen de las
   * filas cargadas (serían las de la página visible, no las del listado), sino
   * de `resumen`, que el backend calcula con conteos.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [total, setTotal] = useState(0)
  const [resumen, setResumen] = useState<ResumenClientes | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    setError('')
    try {
      const pagina = await clienteApi.listar(q)
      setClientes(pagina.items)
      setTotal(pagina.total)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los clientes.')
    } finally {
      setCargando(false)
    }
  }, [])

  /** Todo lo que no cambia al paginar: catálogos del formulario y el resumen. */
  const cargarApoyo = useCallback(async () => {
    try {
      const [res, merc, rts, deps, provs, dists] = await Promise.all([
        clienteApi.resumen(),
        mercadoApi.getAll(),
        rutaApi.getAll(),
        ubigeoApi.departamentos(),
        ubigeoApi.provincias(),
        ubigeoApi.distritos(),
      ])
      setResumen(res)
      setMercados(merc)
      setRutas(rts)
      setDepartamentos(deps)
      setProvincias(provs)
      setDistritos(dists)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los datos de apoyo.')
    }
  }, [])

  /** Tras crear, editar o borrar: se recarga la página actual y los contadores. */
  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarApoyo()])
  }, [consulta, cargarPagina, cargarApoyo])

  useEffect(() => {
    void cargarApoyo()
  }, [cargarApoyo])

  useRealtime(['clientes', 'mercados', 'rutas'], cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setUbigeoSel({ departamentoId: 0, provinciaId: 0 })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (cliente: ClienteResponse) => {
    setEditando(cliente)
    setForm({
      documento: cliente.documento,
      tipoDoc: cliente.tipoDoc,
      nombre: cliente.nombre,
      direccion: cliente.direccion ?? '',
      distritoId: cliente.distritoId ?? 0,
      telefono: cliente.telefono ?? '',
      email: cliente.email ?? '',
      diaVisita: cliente.diaVisita ?? '',
      rutaId: cliente.rutaId ?? 0,
      mercadoId: cliente.mercadoId ?? 0,
    })
    setUbigeoSel({
      departamentoId: cliente.departamentoId ?? 0,
      provinciaId: cliente.provinciaId ?? 0,
    })
    setErrorForm('')
    setAbierto(true)
  }

  /** Con 8 u 11 dígitos se puede traer el nombre de RENIEC o SUNAT. */
  const consultarDocumento = async (documento: string, tipo: TipoDocumento) => {
    setConsultando(true)
    setErrorForm('')
    try {
      if (tipo === 'RUC') {
        const datos = await consultaApi.ruc(documento)
        // El distrito de SUNAT es texto libre: se intenta calzar contra el
        // ubigeo oficial por nombre; si no hay uno igual, se deja sin elegir.
        const encontrado = datos.distrito
          ? distritos.find((d) => d.nombre.toLowerCase() === datos.distrito!.trim().toLowerCase())
          : undefined
        if (encontrado) {
          setUbigeoSel({ departamentoId: encontrado.departamentoId, provinciaId: encontrado.provinciaId })
        }
        setForm((prev) => ({
          ...prev,
          nombre: datos.razonSocial,
          direccion: datos.direccion ?? prev.direccion,
          distritoId: encontrado ? encontrado.id : prev.distritoId,
        }))
      } else if (tipo === 'DNI') {
        const datos = await consultaApi.dni(documento)
        setForm((prev) => ({
          ...prev,
          nombre: `${datos.apellidoPaterno} ${datos.apellidoMaterno} ${datos.nombres}`
            .replace(/\s+/g, ' ')
            .trim(),
        }))
      }
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos consultar el documento.')
    } finally {
      setConsultando(false)
    }
  }

  const guardar = async () => {
    setErrorForm('')
    if (!/^[0-9]{3,15}$/.test(form.documento)) {
      return setErrorForm('El documento debe tener entre 3 y 15 dígitos.')
    }
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre del cliente.')

    setGuardando(true)
    try {
      const cuerpo = {
        ...form,
        mercadoId: form.mercadoId || null,
        rutaId: form.rutaId || null,
        distritoId: form.distritoId || null,
      }
      if (editando) await clienteApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      else await clienteApi.create(cuerpo)
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el cliente.',
      )
    } finally {
      setGuardando(false)
    }
  }

  /** Crea el mercado sin salir del formulario y lo deja elegido en el cliente. */
  const crearMercadoRapido = async () => {
    if (!nombreMercado.trim()) return setErrorMercado('Ingresa el nombre.')

    setCreandoMercado(true)
    setErrorMercado('')
    try {
      const creado = await mercadoApi.create({ nombre: nombreMercado.trim() })
      setForm((f) => ({ ...f, mercadoId: creado.id }))
      await cargar()
      setNombreMercado('')
      setNuevoMercado(false)
    } catch (e) {
      setErrorMercado(e instanceof ApiError ? e.message : 'No pudimos crear el mercado.')
    } finally {
      setCreandoMercado(false)
    }
  }

  /** Crea la ruta sin salir del formulario y la deja elegida en el cliente. */
  const crearRutaRapida = async () => {
    if (!nombreRuta.trim()) return setErrorRuta('Ingresa el nombre.')

    setCreandoRuta(true)
    setErrorRuta('')
    try {
      const creada = await rutaApi.create({ nombre: nombreRuta.trim() })
      setForm((f) => ({ ...f, rutaId: creada.id }))
      await cargar()
      setNombreRuta('')
      setNuevaRuta(false)
    } catch (e) {
      setErrorRuta(e instanceof ApiError ? e.message : 'No pudimos crear la ruta.')
    } finally {
      setCreandoRuta(false)
    }
  }

  const eliminar = (cliente: ClienteResponse) =>
    confirmar({
      titulo: `Eliminar ${cliente.nombre}`,
      mensaje: (
        <>
          Se borra definitivamente y no se puede deshacer. Si solo quieres dejar de usarlo,
          desactívalo en vez de eliminarlo.
        </>
      ),
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await clienteApi.remove(cliente.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el cliente.')
        }
      },
    })

  const cambiarEstado = (cliente: ClienteResponse) =>
    confirmar({
      titulo: `${cliente.activo ? 'Desactivar' : 'Activar'} ${cliente.nombre}`,
      mensaje: cliente.activo
        ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
        : 'Vuelve a estar disponible para usarse.',
      confirmar: cliente.activo ? 'Desactivar' : 'Activar',
      tono: cliente.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await (cliente.activo ? clienteApi.desactivar(cliente.id) : clienteApi.activar(cliente.id))
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  // Contadores del listado completo. Vienen del backend porque en pantalla
  // solo hay una página: contarlos sobre `clientes` daría "30 activos".
  const activos = resumen?.activos ?? 0
  const desactivados = resumen?.desactivados ?? 0
  const conRuta = resumen?.conRuta ?? 0
  const rutasDistintas = resumen?.rutas ?? 0

  // Opciones del filtro "select" de una columna libre: los valores que de
  // verdad existen en TODOS los clientes, no solo en la página cargada.
  const opcionesDistintas = (valores: string[] | undefined) =>
    (valores ?? []).map((v) => ({ value: v, label: v }))

  const columns: DataTableColumn<ClienteResponse>[] = [
    {
      key: 'documento',
      label: 'Documento',
      filterable: false,
      // Solo el número: el tipo tiene su propia columna al lado.
      render: (row) => <span className="font-medium text-ink">{row.documento}</span>,
    },
    {
      key: 'tipoDoc',
      label: 'Tipo de documento',
      filterType: 'select',
      filterOptions: [
        { value: 'DNI', label: 'DNI' },
        { value: 'RUC', label: 'RUC' },
        { value: 'CODIGO', label: 'Código' },
      ],
      value: (row) => row.tipoDoc,
      render: (row) => <Badge>{row.tipoDoc}</Badge>,
    },
    { key: 'nombre', label: 'Nombre', filterable: false },
    {
      key: 'direccion',
      label: 'Dirección',
      filterType: 'select',
      filterOptions: opcionesDistintas(resumen?.direcciones),
    },
    {
      key: 'distrito',
      label: 'Distrito',
      filterType: 'select',
      filterOptions: opcionesDistintas(resumen?.distritos),
    },
    { key: 'telefono', label: 'Teléfono' },
    {
      key: 'diaVisita',
      label: 'Día visita',
      filterType: 'select',
      filterOptions: DIAS.map((d) => ({ value: d, label: d })),
      render: (row) => (row.diaVisita ? <Badge tone="sys">{row.diaVisita}</Badge> : '—'),
    },
    {
      key: 'ruta',
      label: 'Ruta',
      align: 'right',
      filterType: 'select',
      filterOptions: opcionesDistintas(resumen?.rutasNombres),
    },
    {
      key: 'mercado',
      label: 'Mercado',
      align: 'right',
      filterType: 'select',
      filterOptions: opcionesDistintas(resumen?.mercados),
    },
    {
      key: 'fechaCreacion',
      label: 'Fecha de registro',
      filterType: 'date',
      value: (row) => new Date(row.fechaCreacion).getTime(),
      render: (row) => new Date(row.fechaCreacion).toLocaleDateString('es-PE'),
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
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Contact size={20} />}
        title="Clientes"
        description="Bodegas y puestos a los que se vende. El documento puede ser DNI, RUC o un código interno."
        actions={
          <>
            {puede('maestros.clientes', 'importar') && (
              <Button variant="secondary" size="sm" onClick={() => setImportando(true)}>
                <Upload size={15} />
                Importar
              </Button>
            )}
            {puede('maestros.clientes', 'crear') && (
              <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
                Nuevo cliente
              </Button>
            )}
          </>
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard
              label="Clientes activos"
              value={String(activos)}
              icon={<Contact size={18} />}
            />
            <StatCard
              label="Desactivados"
              value={String(desactivados)}
              icon={<ShieldOff size={18} />}
              tono={desactivados > 0 ? 'warning' : 'neutral'}
              hint={desactivados > 0 ? 'no aparecen en nuevas operaciones' : 'ninguno'}
            />
            <StatCard
              label="Con ruta asignada"
              value={String(conRuta)}
              icon={<Route size={18} />}
              tono="success"
              hint={`${activos - conRuta} sin ruta`}
            />
            <StatCard
              label="Rutas"
              value={String(rutasDistintas)}
              icon={<MapPin size={18} />}
              tono="neutral"
              hint="rutas de reparto distintas"
            />
          </>
        }
        columns={columns}
        rows={clientes}
        // Con ~2000 clientes la tabla pide solo la página que muestra: la
        // búsqueda, los filtros y el orden se resuelven en la base.
        servidor={{
          total,
          cargando,
          onConsulta: (q) => {
            setConsulta(q)
            void cargarPagina(q)
          },
        }}
        cardIcon={Contact}
        searchPlaceholder="Buscar por nombre, documento, mercado..."
        empty={cargando ? 'Cargando clientes...' : 'Todavía no hay clientes registrados.'}
        rowActions={(row) => (
          <>
            {puede('maestros.clientes', 'editar') && (
              <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
                <Pencil size={15} />
              </RowAction>
            )}
            {puede('maestros.clientes', 'editar') && (
              <RowAction
                label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
                tone={row.activo ? 'warning' : 'success'}
                onClick={() => cambiarEstado(row)}
              >
                {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
              </RowAction>
            )}
            {puede('maestros.clientes', 'eliminar') && (
              <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
                <Trash2 size={15} />
              </RowAction>
            )}
          </>
        )}
      >
        <Modal
          open={abierto}
          title={editando ? `Editar ${editando.nombre}` : 'Nuevo cliente'}
          description="El documento identifica al cliente y no se puede repetir."
          onClose={() => setAbierto(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardar()}>
                {editando ? 'Guardar cambios' : 'Crear cliente'}
              </Button>
            </>
          }
        >
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {errorForm && (
              <div className="sm:col-span-2">
                <Alert>{errorForm}</Alert>
              </div>
            )}

            <DocumentoInput
              className="sm:col-span-2"
              tipo={(form.tipoDoc as TipoDocumento) ?? 'DNI'}
              onTipoChange={(tipoDoc) => setForm((prev) => ({ ...prev, tipoDoc }))}
              value={form.documento}
              onChange={(documento) => setForm((prev) => ({ ...prev, documento }))}
              onBuscar={consultarDocumento}
              buscando={consultando}
            />

            <Input
              label="Nombre"
              value={form.nombre}
              onChange={(e) => setForm({ ...form, nombre: e.target.value })}
            />

            <Input
              label="Dirección"
              className="sm:col-span-2"
              value={form.direccion ?? ''}
              onChange={(e) => setForm({ ...form, direccion: e.target.value })}
            />

            <Desplegable
              label="Departamento"
              optional
              value={ubigeoSel.departamentoId}
              onChange={(v) => {
                setUbigeoSel({ departamentoId: Number(v), provinciaId: 0 })
                setForm((f) => ({ ...f, distritoId: 0 }))
              }}
              options={[
                { value: 0, label: 'Elegir' },
                ...departamentos.map((d) => ({ value: d.id, label: d.nombre })),
              ]}
            />

            <Desplegable
              label="Provincia"
              optional
              disabled={!ubigeoSel.departamentoId}
              value={ubigeoSel.provinciaId}
              onChange={(v) => {
                setUbigeoSel((s) => ({ ...s, provinciaId: Number(v) }))
                setForm((f) => ({ ...f, distritoId: 0 }))
              }}
              options={[
                { value: 0, label: 'Elegir' },
                ...provincias
                  .filter((p) => p.departamentoId === ubigeoSel.departamentoId)
                  .map((p) => ({ value: p.id, label: p.nombre })),
              ]}
            />

            <Desplegable
              label="Distrito"
              optional
              disabled={!ubigeoSel.provinciaId}
              value={form.distritoId ?? 0}
              onChange={(v) => setForm({ ...form, distritoId: Number(v) })}
              options={[
                { value: 0, label: 'Elegir' },
                ...distritos
                  .filter((d) => d.provinciaId === ubigeoSel.provinciaId)
                  .map((d) => ({ value: d.id, label: d.nombre })),
              ]}
            />

            <Input
              label="Teléfono"
              value={form.telefono ?? ''}
              onChange={(e) => setForm({ ...form, telefono: e.target.value })}
            />

            <label className="block">
              <span className="ui-label mb-1.5">Día de visita</span>
              <select
                value={form.diaVisita ?? ''}
                onChange={(e) => setForm({ ...form, diaVisita: e.target.value })}
                className="h-[var(--height-field-md)] w-full cursor-pointer rounded-field border border-line bg-surface px-3 text-sm text-ink outline-none focus:border-ink-soft"
              >
                <option value="">Sin definir</option>
                {DIAS.map((d) => (
                  <option key={d} value={d}>
                    {d}
                  </option>
                ))}
              </select>
            </label>

            {/* El + crea la ruta sin salir del formulario. */}
            <Desplegable
              label="Ruta"
              optional
              hint={<BotonMas label="Nueva ruta" onClick={() => setNuevaRuta(true)} />}
              value={form.rutaId ?? 0}
              onChange={(v) => setForm({ ...form, rutaId: Number(v) })}
              options={[
                { value: 0, label: 'Sin ruta' },
                ...rutas.filter((r) => r.activo).map((r) => ({ value: r.id, label: r.nombre })),
              ]}
            />

            {/* El + crea el mercado sin salir del formulario. */}
            <Desplegable
              label="Mercado"
              optional
              hint={<BotonMas label="Nuevo mercado" onClick={() => setNuevoMercado(true)} />}
              value={form.mercadoId ?? 0}
              onChange={(v) => setForm({ ...form, mercadoId: Number(v) })}
              options={[
                { value: 0, label: 'Sin mercado' },
                ...mercados.filter((m) => m.activo).map((m) => ({ value: m.id, label: m.nombre })),
              ]}
            />

            <Input
              label="Correo"
              type="email"
              optional
              value={form.email ?? ''}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
          </div>
        </Modal>

        {/* Alta rápida de mercado desde el propio formulario de cliente. */}
        <Modal
          open={nuevoMercado}
          size="sm"
          title="Nuevo mercado"
          description="Se crea y queda elegido en el cliente que estás dando de alta."
          onClose={() => setNuevoMercado(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setNuevoMercado(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={creandoMercado} onClick={() => void crearMercadoRapido()}>
                Crear
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorMercado && <Alert>{errorMercado}</Alert>}

            <Input
              label="Nombre"
              placeholder="Mercado Central, Tienda Norte..."
              value={nombreMercado}
              onChange={(e) => setNombreMercado(e.target.value)}
            />
          </div>
        </Modal>

        {/* Alta rápida de ruta desde el propio formulario de cliente. */}
        <Modal
          open={nuevaRuta}
          size="sm"
          title="Nueva ruta"
          description="Se crea y queda elegida en el cliente que estás dando de alta."
          onClose={() => setNuevaRuta(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setNuevaRuta(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={creandoRuta} onClick={() => void crearRutaRapida()}>
                Crear
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorRuta && <Alert>{errorRuta}</Alert>}

            <Input
              label="Nombre"
              placeholder="Ruta 1, Zona Norte..."
              value={nombreRuta}
              onChange={(e) => setNombreRuta(e.target.value)}
            />
          </div>
        </Modal>

        <ImportarModal<ClienteRequest>
          open={importando}
          onClose={() => setImportando(false)}
          titulo="clientes"
          columnasEsperadas={[
            'Documento',
            'Nombre',
            'Direccion',
            'Distrito',
            'Telefono',
            'Dias Visita',
            'Rutas',
            'Mercado',
          ]}
          mapear={(fila) => ({
            documento: valorDe(fila, 'documento', 'dni', 'ruc', 'nro documento'),
            nombre: valorDe(fila, 'nombre', 'razon social', 'cliente'),
            direccion: valorDe(fila, 'direccion', 'dirección'),
            // Se busca por nombre en el ubigeo oficial: el archivo no trae el id.
            distritoNombre: valorDe(fila, 'distrito'),
            telefono: valorDe(fila, 'telefono', 'teléfono', 'celular'),
            diaVisita: valorDe(fila, 'dias visita', 'dia visita', 'día de visita'),
            // Se resuelve o crea por nombre: el archivo no trae el id de la ruta.
            rutaNombre: valorDe(fila, 'rutas', 'ruta'),
            // Se resuelve o crea por nombre: el archivo no trae el id del mercado.
            mercadoNombre: valorDe(fila, 'mercado', 'punto de reparto'),
          })}
          onImportar={clienteApi.importar}
          onListo={() => void cargar()}
        />

        {dialogo}
      </ListPage>
  )
}
