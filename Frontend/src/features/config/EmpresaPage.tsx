import { useCallback, useEffect, useRef, useState } from 'react'
import { Building2, Save, Upload } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  DocumentoInput,
  Input,
  PageHeader,
  PageSection,
  Select,
  Tabs,
  useToast,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { empresaApi } from './empresaApi'
import type { EmpresaRequest, EmpresaResponse } from './empresaApi'
import { SeriesEmpresa } from './SeriesEmpresa'
import { WhatsAppEmpresa } from './WhatsAppEmpresa'
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
  whatsAppAutomatico: false,
  whatsAppPlantilla: '',
  activa: true,
}

const aFormulario = (e: EmpresaResponse): EmpresaRequest => ({
  razonSocial: e.razonSocial,
  nombreComercial: e.nombreComercial,
  ruc: e.ruc,
  direccion: e.direccion ?? '',
  departamento: e.departamento ?? '',
  provincia: e.provincia ?? '',
  distrito: e.distrito ?? '',
  telefono: e.telefono ?? '',
  email: e.email ?? '',
  sitioWeb: e.sitioWeb ?? '',
  representanteLegal: e.representanteLegal ?? '',
  ubigeo: e.ubigeo ?? '',
  usuarioSol: e.usuarioSol ?? '',
  // La clave no vuelve del servidor: vacía deja la que está.
  claveSol: '',
  modoPrueba: e.modoPrueba,
  whatsAppAutomatico: e.whatsAppAutomatico,
  whatsAppPlantilla: e.whatsAppPlantilla ?? '',
  activa: true,
})

type Pestana = 'datos' | 'facturacion' | 'series' | 'whatsapp'

/**
 * La empresa del sistema: una sola, así que no hay lista. Es un formulario con tres pestañas: sus datos (los que
 * salen en documentos y reportes), lo que SUNAT pide para facturar y las series de comprobantes con su numeración.
 * Si todavía no existe, el mismo formulario la crea.
 */
export function EmpresaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [empresa, setEmpresa] = useState<EmpresaResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [form, setForm] = useState<EmpresaRequest>(VACIA)
  const [pestana, setPestana] = useState<Pestana>('datos')
  const [guardando, setGuardando] = useState(false)
  const [consultando, setConsultando] = useState(false)
  const [avisoSunat, setAvisoSunat] = useState('')
  const [subiendoCert, setSubiendoCert] = useState(false)
  const inputCert = useRef<HTMLInputElement>(null)

  const puedeEditar = empresa ? puede('config.empresa', 'editar') : puede('config.empresa', 'crear')

  const cargar = useCallback(async () => {
    try {
      const lista = await empresaApi.getAll()
      // Hay una sola; si por herencia hubiera más, se trabaja con la que opera el sistema.
      const actual = lista.find((e) => e.activa) ?? lista[0] ?? null
      setEmpresa(actual)
      setForm(actual ? aFormulario(actual) : VACIA)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la empresa.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('empresas', cargar)

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

  /** Lee el .pem en el navegador y lo manda al backend, que lo revisa y lo guarda cifrado. */
  const subirCertificado = async (archivo: File | undefined) => {
    if (!archivo || !empresa) return
    if (archivo.size > 512 * 1024) {
      toast.error('El certificado no debe pasar de 512 KB.')
      return
    }

    setSubiendoCert(true)
    try {
      const resultado = await empresaApi.subirCertificado(empresa.id, await archivo.text())
      setEmpresa(resultado.empresa)
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
      if (empresa) await empresaApi.update(empresa.id, form)
      else await empresaApi.create(form)
      await cargar()
      toast.exito(empresa ? 'Empresa actualizada' : 'Empresa creada')
    } catch (e) {
      toast.error(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos guardar la empresa.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const campo = (clave: keyof EmpresaRequest) => ({
    value: (form[clave] as string | null | undefined) ?? '',
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => setForm({ ...form, [clave]: e.target.value }),
    disabled: !puedeEditar,
  })

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<Building2 size={20} />}
        title="Empresa"
        description="Los datos de la empresa que emite: aparecen en documentos y reportes, y con ellos se factura a SUNAT."
        actions={
          pestana !== 'series' && puedeEditar ? (
            <Button size="sm" loading={guardando} disabled={cargando} onClick={() => void guardar()} iconRight={<Save size={15} />}>
              {empresa ? 'Guardar cambios' : 'Crear empresa'}
            </Button>
          ) : undefined
        }
      />

      {error && <Alert>{error}</Alert>}
      {!cargando && !empresa && !error && (
        <Alert tone="info">Todavía no se registró la empresa. Completa sus datos y créala para poder facturar.</Alert>
      )}

      <Tabs
        active={pestana}
        onChange={(id) => setPestana(id as Pestana)}
        items={[
          { id: 'datos', label: 'Datos' },
          { id: 'facturacion', label: 'Facturación electrónica' },
          { id: 'series', label: 'Series' },
          { id: 'whatsapp', label: 'WhatsApp' },
        ]}
      />

      {pestana === 'datos' && (
        <PageSection title="Datos de la empresa" description="Estos datos aparecen en documentos y reportes.">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {avisoSunat && (
              <p className="rounded-field border border-blue-200 bg-blue-50 px-3 py-2 text-xs text-blue-700 sm:col-span-2">
                {avisoSunat}
              </p>
            )}

            <Input label="Razón social" className="sm:col-span-2" {...campo('razonSocial')} />
            <Input label="Nombre comercial" {...campo('nombreComercial')} />
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
            <Input label="Dirección fiscal" className="sm:col-span-2" {...campo('direccion')} />
            <Input label="Departamento" {...campo('departamento')} />
            <Input label="Provincia" {...campo('provincia')} />
            <Input label="Distrito" {...campo('distrito')} />
            <Input label="Representante legal" {...campo('representanteLegal')} />
            <Input label="Teléfono" {...campo('telefono')} />
            <Input label="Correo" type="email" {...campo('email')} />
            <Input label="Sitio web" placeholder="titanicd.pe" {...campo('sitioWeb')} />
          </div>
        </PageSection>
      )}

      {pestana === 'facturacion' && (
        <PageSection
          title="Facturación electrónica"
          description="Con estos datos se firman y se envían a SUNAT las facturas, boletas y notas de esta empresa."
          actions={
            empresa && <Badge tone={empresa.modoPrueba ? 'warning' : 'success'}>{empresa.modoPrueba ? 'Pruebas' : 'Producción'}</Badge>
          }
        >
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Select
              label="Modo"
              disabled={!puedeEditar}
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
              disabled={!puedeEditar}
              value={form.ubigeo ?? ''}
              onChange={(e) => setForm({ ...form, ubigeo: e.target.value.replace(/\D/g, '') })}
            />
            <Input
              label="Usuario SOL"
              placeholder={form.modoPrueba ? 'MODDATOS' : ''}
              autoComplete="off"
              {...campo('usuarioSol')}
            />
            <Input
              label="Clave SOL"
              type="password"
              autoComplete="new-password"
              placeholder={empresa?.tieneClaveSol ? 'Guardada · escribe otra para cambiarla' : form.modoPrueba ? 'moddatos' : ''}
              {...campo('claveSol')}
            />

            {/* El certificado se sube a una empresa ya guardada. */}
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-field border border-line px-3 py-2.5 sm:col-span-2">
              <div className="min-w-0">
                <p className="text-sm font-medium text-ink">Certificado digital (.pem)</p>
                {empresa ? (
                  empresa.certificadoVenceEl ? (
                    <p className={`text-xs ${empresa.certificadoVencido ? 'text-red-600' : 'text-ink-soft'}`}>
                      {empresa.certificadoTitular ?? 'Certificado cargado'} · {empresa.certificadoVencido ? 'venció' : 'vence'} el{' '}
                      {fechaCorta(empresa.certificadoVenceEl)}
                    </p>
                  ) : (
                    <p className="text-xs text-ink-soft">
                      {empresa.tieneCertificado
                        ? 'Certificado guardado.'
                        : 'Todavía no se subió ninguno. Sin certificado no se pueden firmar comprobantes.'}
                    </p>
                  )
                ) : (
                  <p className="text-xs text-ink-soft">Crea la empresa primero: el certificado se guarda sobre ella.</p>
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
                  disabled={!empresa}
                  loading={subiendoCert}
                  onClick={() => inputCert.current?.click()}
                >
                  <Upload size={15} />
                  {empresa?.tieneCertificado ? 'Reemplazar' : 'Subir certificado'}
                </Button>
              )}
            </div>

            {!form.modoPrueba && (
              <p className="rounded-field border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800 sm:col-span-2">
                En producción cada comprobante que se emita es real y llega a SUNAT. Sube antes el certificado digital de esta empresa.
              </p>
            )}
          </div>
        </PageSection>
      )}

      {pestana === 'whatsapp' && (
        <PageSection
          title="Envío por WhatsApp"
          description="Manda el enlace de descarga de cada comprobante al celular del cliente."
        >
          <WhatsAppEmpresa
            puedeEditar={puedeEditar}
            automatico={form.whatsAppAutomatico}
            plantilla={form.whatsAppPlantilla ?? ''}
            onAutomatico={(v) => setForm({ ...form, whatsAppAutomatico: v })}
            onPlantilla={(v) => setForm({ ...form, whatsAppPlantilla: v })}
          />
        </PageSection>
      )}

      {pestana === 'series' && (
        <PageSection
          title="Series de comprobantes"
          description="Factura, boleta y notas de crédito y débito, cada una con su serie y su numeración."
        >
          {empresa ? (
            <SeriesEmpresa empresaId={empresa.id} puedeEditar={puede('config.empresa', 'editar')} />
          ) : (
            <p className="rounded-field border border-line px-3 py-6 text-center text-sm text-ink-soft">
              Crea la empresa primero: las series y su numeración se registran sobre ella.
            </p>
          )}
        </PageSection>
      )}
    </div>
  )
}
