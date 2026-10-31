import { useCallback, useEffect, useRef, useState } from 'react'
import {
  Building2,
  CheckCircle2,
  Circle,
  Pencil,
  Plus,
  ShieldCheck,
  ShieldOff,
  Trash2,
  Upload,
} from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  DocumentoInput,
  Input,
  ListPage,
  Modal,
  RowAction,
  Select,
  Tabs,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { empresaApi } from './empresaApi'
import { SeriesEmpresa } from './SeriesEmpresa'
import type { EmpresaRequest, EmpresaResponse } from './empresaApi'
import { usePermisos } from '../../lib/permisos'
import { fechaCorta } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'

const VACIA: EmpresaRequest = {
  razonSocial: '',
  nombreComercial: '',
  ruc: '',
  direccion: '',
  departamento: '',
  provincia: '',
  distrito: '',
  telefono: '',
  email: '',
  sitioWeb: '',
  representanteLegal: '',
  ubigeo: '',
  usuarioSol: '',
  claveSol: '',
  // Arranca en pruebas: nadie emite de verdad a SUNAT sin haberlo decidido.
  modoPrueba: true,
  activa: false,
}

export function EmpresaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [empresas, setEmpresas] = useState<EmpresaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<EmpresaResponse | null>(null)
  const [abierto, setAbierto] = useState(false)
  const [form, setForm] = useState<EmpresaRequest>(VACIA)
  const [guardando, setGuardando] = useState(false)
  const [consultando, setConsultando] = useState(false)
  const [avisoSunat, setAvisoSunat] = useState('')
  const [subiendoCert, setSubiendoCert] = useState(false)
  const [pestana, setPestana] = useState<'datos' | 'facturacion' | 'series'>('datos')
  const inputCert = useRef<HTMLInputElement>(null)

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setEmpresas(await empresaApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las empresas.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('empresas', cargar)

  const abrirNueva = () => {
    setEditando(null)
    setForm({ ...VACIA, activa: empresas.length === 0 })
    setAvisoSunat('')
    setPestana('datos')
    setAbierto(true)
  }

  /** Trae de SUNAT los datos de la empresa y llena el formulario. */
  const consultarRuc = async (ruc: string) => {
    setConsultando(true)
    setAvisoSunat('')
    try {
      const datos = await consultaApi.ruc(ruc)
      setForm((prev) => ({
        ...prev,
        ruc: datos.ruc,
        razonSocial: datos.razonSocial,
        // SUNAT suele no traer nombre comercial: se deja la razon social.
        nombreComercial: datos.nombreComercial || prev.nombreComercial || datos.razonSocial,
        direccion: datos.direccion ?? prev.direccion,
        departamento: datos.departamento ?? prev.departamento,
        provincia: datos.provincia ?? prev.provincia,
        distrito: datos.distrito ?? prev.distrito,
      }))

      // Un contribuyente de baja o no habido se puede registrar, pero conviene avisarlo.
      const partes = [datos.estado, datos.condicion].filter(Boolean)
      setAvisoSunat(partes.length ? `SUNAT: ${partes.join(' · ')}` : '')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos consultar el RUC.')
    } finally {
      setConsultando(false)
    }
  }

  const abrirEdicion = (empresa: EmpresaResponse) => {
    setEditando(empresa)
    setForm({
      razonSocial: empresa.razonSocial,
      nombreComercial: empresa.nombreComercial,
      ruc: empresa.ruc,
      direccion: empresa.direccion ?? '',
      departamento: empresa.departamento ?? '',
      provincia: empresa.provincia ?? '',
      distrito: empresa.distrito ?? '',
      telefono: empresa.telefono ?? '',
      email: empresa.email ?? '',
      sitioWeb: empresa.sitioWeb ?? '',
      representanteLegal: empresa.representanteLegal ?? '',
      ubigeo: empresa.ubigeo ?? '',
      usuarioSol: empresa.usuarioSol ?? '',
      // La clave no vuelve del servidor: vacía deja la que está.
      claveSol: '',
      modoPrueba: empresa.modoPrueba,
      activa: empresa.activa,
    })
    setAvisoSunat('')
    setPestana('datos')
    setAbierto(true)
  }

  /** Lee el .pem en el navegador y lo manda a la API de facturación, que lo guarda por RUC. */
  const subirCertificado = async (archivo: File | undefined) => {
    if (!archivo || !editando) return
    if (archivo.size > 512 * 1024) {
      toast.error('El certificado no debe pasar de 512 KB.')
      return
    }

    setSubiendoCert(true)
    try {
      const resultado = await empresaApi.subirCertificado(editando.id, await archivo.text())
      setEditando(resultado.empresa)
      setEmpresas((lista) => lista.map((e) => (e.id === resultado.empresa.id ? resultado.empresa : e)))
      if (resultado.advertencias.length > 0) toast.error(resultado.mensaje)
      else toast.exito(resultado.mensaje)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos subir el certificado.')
    } finally {
      setSubiendoCert(false)
      // Sin esto elegir el mismo archivo otra vez no dispara el cambio.
      if (inputCert.current) inputCert.current.value = ''
    }
  }

  const guardar = async () => {
    setGuardando(true)
    try {
      if (editando) await empresaApi.update(editando.id, form)
      else await empresaApi.create(form)
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Empresa actualizada' : 'Empresa creada')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la empresa.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const activar = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await empresaApi.activar(empresa.id)
      await cargar()
      toast.exito(`${empresa.nombreComercial} está activa`)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos activar la empresa.')
    }
  }

  const cambiarHabilitacion = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await (empresa.habilitada
        ? empresaApi.deshabilitar(empresa.id)
        : empresaApi.habilitar(empresa.id))
      await cargar()
      toast.exito(`${empresa.nombreComercial} ${empresa.habilitada ? 'deshabilitada' : 'habilitada'}`)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado de la empresa.')
    }
  }

  const eliminar = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await empresaApi.remove(empresa.id)
      await cargar()
      toast.exito('Empresa eliminada')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos eliminar la empresa.')
    }
  }

  const activa = empresas.find((e) => e.activa)

  const columns: DataTableColumn<EmpresaResponse>[] = [
    // Todos son datos únicos por empresa: no hay nada que agrupar en un
    // select, y razón social y RUC ya se buscan arriba.
    { key: 'razonSocial', label: 'Razón social', filterable: false },
    { key: 'nombreComercial', label: 'Nombre comercial', filterable: false },
    { key: 'ruc', label: 'RUC', filterable: false },
    { key: 'telefono', label: 'Teléfono', filterable: false },
    {
      key: 'sitioWeb',
      label: 'Sitio web',
      filterable: false,
      render: (row) =>
        row.sitioWeb ? (
          <a
            href={row.sitioWeb}
            target="_blank"
            rel="noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="text-blue-600 hover:underline"
          >
            {row.sitioWeb.replace(/^https?:\/\//, '')}
          </a>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      // Con qué entorno de SUNAT emite: en pruebas los comprobantes no valen.
      key: 'modoPrueba',
      label: 'Facturación',
      filterable: false,
      value: (row) => (row.modoPrueba ? 'Pruebas' : 'Producción'),
      render: (row) => <Badge tone={row.modoPrueba ? 'warning' : 'success'}>{row.modoPrueba ? 'Pruebas' : 'Producción'}</Badge>,
    },
    {
      key: 'activa',
      label: 'Estado',
      filterType: 'select',
      // Son tres estados derivados de dos banderas; se comparan contra la
      // etiqueta que `value` expone.
      filterOptions: [
        { value: 'Activa', label: 'Activa' },
        { value: 'Disponible', label: 'Disponible' },
        { value: 'Deshabilitada', label: 'Deshabilitada' },
      ],
      value: (row) => (row.activa ? 'Activa' : row.habilitada ? 'Disponible' : 'Deshabilitada'),
      render: (row) =>
        row.activa ? (
          <Badge tone="success">Activa</Badge>
        ) : row.habilitada ? (
          <Badge tone="sys">Disponible</Badge>
        ) : (
          <Badge>Deshabilitada</Badge>
        ),
    },
  ]

  return (
    <ListPage
      icon={<Building2 size={20} />}
      title="Empresas"
      description="Solo una empresa opera el sistema a la vez."
      actions={
        puede('config.empresa', 'crear') ? (
          <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
            Nueva empresa
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        activa ? (
          <div className="flex flex-wrap items-center gap-3 rounded-panel border border-[rgb(var(--sys-rgb)/0.3)] bg-[rgb(var(--sys-rgb)/0.06)] p-4">
            <CheckCircle2 size={20} className="shrink-0 text-[rgb(var(--sys-ink-rgb))]" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink">Operando como {activa.nombreComercial}</p>
              <p className="truncate text-xs text-ink-muted">
                {activa.razonSocial} · RUC {activa.ruc}
              </p>
            </div>
          </div>
        ) : undefined
      }
      columns={columns}
      rows={empresas}
      cardIcon={Building2}
      searchPlaceholder="Buscar por razón social o RUC..."
      empty={cargando ? 'Cargando empresas...' : 'Todavía no hay empresas registradas.'}
      rowActions={(row) => (
        <>
          {!row.activa && puede('config.empresa', 'editar') && (
            <RowAction
              label={`Activar ${row.nombreComercial}`}
              tone="success"
              disabled={!row.habilitada}
              disabledReason="Está deshabilitada: habilítala antes de activarla"
              onClick={() => void activar(row)}
            >
              <Circle size={15} />
            </RowAction>
          )}

          {puede('config.empresa', 'editar') && (
            <RowAction label={`Editar ${row.nombreComercial}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}

          {/* La empresa activa no se deshabilita: primero se activa otra. */}
          {puede('config.empresa', 'editar') && (
            <RowAction
              label={`${row.habilitada ? 'Deshabilitar' : 'Habilitar'} ${row.nombreComercial}`}
              tone={row.habilitada ? 'warning' : 'success'}
              disabled={row.activa}
              disabledReason="Es la empresa activa: activa otra antes de deshabilitarla"
              onClick={() => void cambiarHabilitacion(row)}
            >
              {row.habilitada ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}

          {puede('config.empresa', 'eliminar') && (
            <RowAction
              label={`Eliminar ${row.nombreComercial}`}
              tone="danger"
              disabled={row.activa}
              disabledReason="Es la empresa activa: no se puede eliminar"
              onClick={() => void eliminar(row)}
            >
              <Trash2 size={15} />
            </RowAction>
          )}
        </>
      )}
      note="Activa es la empresa con la que opera el sistema; deshabilitada se retira sin borrarla y no se puede activar. La empresa activa no se elimina ni se deshabilita: primero activa otra."
    >
      <Modal
        open={abierto}
        title={editando ? 'Editar empresa' : 'Nueva empresa'}
        description="Estos datos aparecen en documentos y reportes."
        size="lg"
        onClose={() => setAbierto(false)}
        footer={
          pestana === 'series' ? (
            // Las series se guardan fila por fila: aquí solo se cierra.
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cerrar
            </Button>
          ) : (
            <>
              <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardar()}>
                {editando ? 'Guardar cambios' : 'Crear empresa'}
              </Button>
            </>
          )
        }
      >
        <Tabs
          className="mb-4"
          active={pestana}
          onChange={(id) => setPestana(id as typeof pestana)}
          items={[
            { id: 'datos', label: 'Datos' },
            { id: 'facturacion', label: 'Facturación electrónica' },
            { id: 'series', label: 'Series' },
          ]}
        />

        {pestana === 'datos' && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {avisoSunat && (
            <p className="rounded-field border border-blue-200 bg-blue-50 px-3 py-2 text-xs text-blue-700 sm:col-span-2">
              {avisoSunat}
            </p>
          )}

          <Input
            label="Razón social"
            className="sm:col-span-2"
            value={form.razonSocial}
            onChange={(e) => setForm({ ...form, razonSocial: e.target.value })}
          />
          <Input
            label="Nombre comercial"
            value={form.nombreComercial}
            onChange={(e) => setForm({ ...form, nombreComercial: e.target.value })}
          />
          {/* Una empresa emisora siempre tiene RUC: el tipo no se elige. */}
          <DocumentoInput
            tipo="RUC"
            tipoFijo
            label="RUC"
            placeholder="20512345678"
            value={form.ruc}
            onChange={(ruc) => setForm({ ...form, ruc })}
            onBuscar={consultarRuc}
            buscando={consultando}
          />
          <Input
            label="Dirección fiscal"
            className="sm:col-span-2"
            value={form.direccion ?? ''}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />
          <Input
            label="Departamento"
            value={form.departamento ?? ''}
            onChange={(e) => setForm({ ...form, departamento: e.target.value })}
          />
          <Input
            label="Provincia"
            value={form.provincia ?? ''}
            onChange={(e) => setForm({ ...form, provincia: e.target.value })}
          />
          <Input
            label="Distrito"
            value={form.distrito ?? ''}
            onChange={(e) => setForm({ ...form, distrito: e.target.value })}
          />
          <Input
            label="Representante legal"
            value={form.representanteLegal ?? ''}
            onChange={(e) => setForm({ ...form, representanteLegal: e.target.value })}
          />
          <Input
            label="Teléfono"
            value={form.telefono ?? ''}
            onChange={(e) => setForm({ ...form, telefono: e.target.value })}
          />
          <Input
            label="Correo"
            type="email"
            value={form.email ?? ''}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
          <Input
            label="Sitio web"
            placeholder="titanicd.pe"
            value={form.sitioWeb ?? ''}
            onChange={(e) => setForm({ ...form, sitioWeb: e.target.value })}
          />

          {/* Desactivar desde aqui no se permite: el backend obliga a activar otra. */}
          {!form.activa && (
            <label className="flex cursor-pointer items-center gap-2 text-sm text-ink-muted sm:col-span-2">
              <input
                type="checkbox"
                checked={form.activa}
                onChange={(e) => setForm({ ...form, activa: e.target.checked })}
                className="size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
              />
              Dejar esta empresa como la activa del sistema
            </label>
          )}
        </div>
        )}

        {pestana === 'facturacion' && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {/* Lo que SUNAT pide para recibir facturas, boletas y notas. */}
          <p className="text-xs text-ink-soft sm:col-span-2">
            Con estos datos se firman y se envían a SUNAT los comprobantes de esta empresa.
          </p>
          <Select
            label="Modo"
            value={form.modoPrueba ? 'prueba' : 'produccion'}
            onChange={(e) => setForm({ ...form, modoPrueba: e.target.value === 'prueba' })}
          >
            <option value="prueba">Pruebas (beta de SUNAT, sin validez tributaria)</option>
            <option value="produccion">Producción (comprobantes reales)</option>
          </Select>
          <Input
            label="Ubigeo del domicilio fiscal"
            placeholder="150101"
            inputMode="numeric"
            maxLength={6}
            value={form.ubigeo ?? ''}
            onChange={(e) => setForm({ ...form, ubigeo: e.target.value.replace(/\D/g, '') })}
          />
          <Input
            label="Usuario SOL"
            placeholder={form.modoPrueba ? 'MODDATOS' : ''}
            autoComplete="off"
            value={form.usuarioSol ?? ''}
            onChange={(e) => setForm({ ...form, usuarioSol: e.target.value })}
          />
          <Input
            label="Clave SOL"
            type="password"
            autoComplete="new-password"
            placeholder={editando?.tieneClaveSol ? 'Guardada · escribe otra para cambiarla' : form.modoPrueba ? 'moddatos' : ''}
            value={form.claveSol ?? ''}
            onChange={(e) => setForm({ ...form, claveSol: e.target.value })}
          />
          {/* El certificado se sube a una empresa ya guardada: va por RUC en la API de facturación. */}
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-field border border-line px-3 py-2.5 sm:col-span-2">
            <div className="min-w-0">
              <p className="text-sm font-medium text-ink">Certificado digital (.pem)</p>
              {editando ? (
                editando.certificadoVenceEl ? (
                  <p className={`text-xs ${editando.certificadoVencido ? 'text-red-600' : 'text-ink-soft'}`}>
                    {editando.certificadoTitular ?? 'Certificado cargado'} · {editando.certificadoVencido ? 'venció' : 'vence'} el{' '}
                    {fechaCorta(editando.certificadoVenceEl)}
                  </p>
                ) : (
                  <p className="text-xs text-ink-soft">
                    {editando.tieneCertificado
                      ? 'Certificado guardado.'
                      : 'Todavía no se subió ninguno. Sin certificado no se pueden firmar comprobantes.'}
                  </p>
                )
              ) : (
                <p className="text-xs text-ink-soft">Guarda la empresa primero: el certificado se sube a su RUC.</p>
              )}
            </div>
            <input
              ref={inputCert}
              type="file"
              accept=".pem,.txt"
              className="hidden"
              onChange={(e) => void subirCertificado(e.target.files?.[0])}
            />
            {puede('config.empresa', 'editar') && (
              <Button
                variant="secondary"
                size="sm"
                disabled={!editando}
                loading={subiendoCert}
                onClick={() => inputCert.current?.click()}
              >
                <Upload size={15} />
                {editando?.tieneCertificado ? 'Reemplazar' : 'Subir certificado'}
              </Button>
            )}
          </div>

          {!form.modoPrueba && (
            <p className="rounded-field border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800 sm:col-span-2">
              En producción cada comprobante que se emita es real y llega a SUNAT. Sube antes el certificado digital de esta empresa.
            </p>
          )}

        </div>
        )}

        {pestana === 'series' &&
          (editando ? (
            <SeriesEmpresa empresaId={editando.id} puedeEditar={puede('config.empresa', 'editar')} />
          ) : (
            <p className="rounded-field border border-line px-3 py-6 text-center text-sm text-ink-soft">
              Guarda la empresa primero: las series y su numeración se registran sobre una empresa creada.
            </p>
          ))}
      </Modal>
    </ListPage>
  )
}

