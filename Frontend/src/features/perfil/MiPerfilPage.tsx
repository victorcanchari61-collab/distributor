import { useCallback, useEffect, useRef, useState } from 'react'
import { Camera, KeyRound, Trash2, UserRound } from 'lucide-react'
import { Alert, Button, Card, Input, PageHeader } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { updateUsuario } from '../../lib/authStorage'
import { archivoApi, urlImagen } from '../tms/flotaApi'
import { perfilApi } from './perfilApi'

const PASSWORD_VACIO = { actual: '', nueva: '', repetir: '' }

/**
 * Mi perfil: los datos personales y la contrasena de quien tiene la sesion.
 *
 * El rol y el estado no aparecen aqui a proposito: son cosa de un
 * administrador desde Usuarios, y el backend tampoco los acepta por esta via.
 */
export function MiPerfilPage() {
  const [form, setForm] = useState({
    nombre: '',
    email: '',
    dni: '',
    telefono: '',
    foto: null as string | null,
  })
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [subiendo, setSubiendo] = useState(false)
  const [error, setError] = useState('')
  const [guardado, setGuardado] = useState(false)
  const entradaFoto = useRef<HTMLInputElement>(null)

  const [password, setPassword] = useState(PASSWORD_VACIO)
  const [cambiando, setCambiando] = useState(false)
  const [errorPassword, setErrorPassword] = useState('')
  const [passwordCambiada, setPasswordCambiada] = useState(false)

  const cargar = useCallback(async () => {
    try {
      const perfil = await perfilApi.get()
      setForm({
        nombre: perfil.nombre,
        email: perfil.email,
        dni: perfil.dni ?? '',
        telefono: perfil.telefono ?? '',
        foto: perfil.foto,
      })
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar tu perfil.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  /** La foto se sube al elegirla: guardar despues solo manda la ruta. */
  const elegirFoto = async (archivo: File | undefined) => {
    if (!archivo) return

    setSubiendo(true)
    setError('')
    try {
      const { ruta } = await archivoApi.subirImagen(archivo, 'usuarios')
      setForm((prev) => ({ ...prev, foto: ruta }))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos subir la imagen.')
    } finally {
      setSubiendo(false)
      // Se limpia para que volver a elegir el mismo archivo dispare el change.
      if (entradaFoto.current) entradaFoto.current.value = ''
    }
  }

  const guardar = async () => {
    setError('')
    setGuardado(false)

    if (!form.nombre.trim()) return setError('Ingresa tu nombre.')
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return setError('El correo no es válido.')
    if (form.dni && !/^[0-9]{8}$/.test(form.dni)) return setError('El DNI debe tener 8 dígitos.')

    setGuardando(true)
    try {
      const actualizado = await perfilApi.update({
        nombre: form.nombre.trim(),
        email: form.email.trim(),
        dni: form.dni || null,
        telefono: form.telefono.trim() || null,
        foto: form.foto,
      })

      // La sesion guardada y App se actualizan para que el nombre y la foto
      // nuevos se vean en la barra sin recargar la pagina.
      updateUsuario(actualizado)
      window.dispatchEvent(new CustomEvent('perfil:actualizado', { detail: actualizado }))
      setForm({
        nombre: actualizado.nombre,
        email: actualizado.email,
        dni: actualizado.dni ?? '',
        telefono: actualizado.telefono ?? '',
        foto: actualizado.foto,
      })
      setGuardado(true)
    } catch (e) {
      setError(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar tus datos.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const cambiarPassword = async () => {
    setErrorPassword('')
    setPasswordCambiada(false)

    if (!password.actual) return setErrorPassword('Ingresa tu contraseña actual.')
    if (password.nueva.length < 6) {
      return setErrorPassword('La nueva contraseña debe tener al menos 6 caracteres.')
    }
    if (password.nueva !== password.repetir) {
      return setErrorPassword('Las contraseñas nuevas no coinciden.')
    }

    setCambiando(true)
    try {
      await perfilApi.cambiarPassword({
        passwordActual: password.actual,
        passwordNueva: password.nueva,
      })
      setPassword(PASSWORD_VACIO)
      setPasswordCambiada(true)
    } catch (e) {
      setErrorPassword(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos cambiar la contraseña.',
      )
    } finally {
      setCambiando(false)
    }
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-5">
      <PageHeader
        icon={<UserRound size={20} />}
        title="Mi perfil"
        description="Tus datos personales y tu contraseña."
      />

      {cargando ? (
        <Card>
          <p className="text-sm text-ink-muted">Cargando tu perfil...</p>
        </Card>
      ) : (
        <>
          <Card className="flex flex-col gap-5">
            <h2 className="text-base font-bold text-ink">Datos personales</h2>

            {error && <Alert>{error}</Alert>}

            <div className="flex flex-wrap items-center gap-4">
              <div className="flex size-24 shrink-0 items-center justify-center overflow-hidden rounded-full border border-line bg-slate-50 text-2xl font-bold text-ink-soft">
                {form.foto ? (
                  <img
                    src={urlImagen(form.foto)}
                    alt="Foto de perfil"
                    className="size-full object-cover"
                  />
                ) : (
                  form.nombre.charAt(0).toUpperCase() || '?'
                )}
              </div>

              <div className="flex flex-col items-start gap-1.5">
                <Button
                  variant="secondary"
                  size="sm"
                  loading={subiendo}
                  onClick={() => entradaFoto.current?.click()}
                >
                  <Camera size={15} />
                  {form.foto ? 'Cambiar foto' : 'Subir foto'}
                </Button>

                {form.foto && !subiendo && (
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setForm((prev) => ({ ...prev, foto: null }))}
                  >
                    <Trash2 size={14} />
                    Quitar
                  </Button>
                )}

                <span className="text-xs text-ink-soft">JPG, PNG o WEBP. Hasta 5 MB.</span>
              </div>

              <input
                ref={entradaFoto}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => void elegirFoto(e.target.files?.[0])}
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Input
                label="Nombre"
                placeholder="Ej. Lucía Torres"
                value={form.nombre}
                disabled={guardando}
                onChange={(e) => setForm({ ...form, nombre: e.target.value })}
              />
              <Input
                label="Correo electrónico"
                type="email"
                autoComplete="off"
                placeholder="usuario@distributor.com"
                value={form.email}
                disabled={guardando}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
              <Input
                label="DNI"
                optional
                inputMode="numeric"
                maxLength={8}
                placeholder="45871203"
                value={form.dni}
                disabled={guardando}
                onChange={(e) => setForm({ ...form, dni: e.target.value.replace(/\D/g, '') })}
              />
              <Input
                label="Teléfono"
                optional
                inputMode="tel"
                maxLength={20}
                placeholder="987 654 321"
                value={form.telefono}
                disabled={guardando}
                onChange={(e) => setForm({ ...form, telefono: e.target.value })}
              />
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <Button loading={guardando} disabled={subiendo} onClick={() => void guardar()}>
                Guardar cambios
              </Button>
              {guardado && (
                <span className="text-sm font-medium text-emerald-700">Tus datos se guardaron.</span>
              )}
            </div>
          </Card>

          <Card className="flex flex-col gap-5">
            <div>
              <h2 className="text-base font-bold text-ink">Cambiar contraseña</h2>
              <p className="mt-0.5 text-sm text-ink-muted">
                Se pide la actual para que nadie la cambie desde una sesión ajena.
              </p>
            </div>

            {errorPassword && <Alert>{errorPassword}</Alert>}

            <div className="grid gap-4 sm:grid-cols-3">
              <Input
                label="Contraseña actual"
                type="password"
                revealable
                autoComplete="current-password"
                value={password.actual}
                disabled={cambiando}
                onChange={(e) => setPassword({ ...password, actual: e.target.value })}
              />
              <Input
                label="Nueva contraseña"
                type="password"
                revealable
                autoComplete="new-password"
                placeholder="Mínimo 6 caracteres"
                value={password.nueva}
                disabled={cambiando}
                onChange={(e) => setPassword({ ...password, nueva: e.target.value })}
              />
              <Input
                label="Repetir nueva"
                type="password"
                revealable
                autoComplete="new-password"
                value={password.repetir}
                disabled={cambiando}
                onChange={(e) => setPassword({ ...password, repetir: e.target.value })}
              />
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <Button
                variant="secondary"
                loading={cambiando}
                onClick={() => void cambiarPassword()}
              >
                <KeyRound size={15} />
                Cambiar contraseña
              </Button>
              {passwordCambiada && (
                <span className="text-sm font-medium text-emerald-700">
                  Contraseña actualizada.
                </span>
              )}
            </div>
          </Card>
        </>
      )}
    </div>
  )
}
