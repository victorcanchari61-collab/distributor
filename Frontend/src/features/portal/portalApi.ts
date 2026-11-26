import { apiFetch } from '../../lib/apiClient'
import type { RequestOptions } from '../../lib/apiClient'
import type { CatalogoProducto, CatalogoResponse } from '../maestros/catalogoApi'
import type { Cotizacion } from '../facturacion/cotizacionApi'

/*
 * El portal de clientes habla con /api/portal con SU sesión, no con la del panel: va con `auth: false` (no adjunta
 * ni toca la sesión del personal, ni la cierra si el portal responde 401) y lleva su propio token.
 */

const CLAVE_SESION = 'distribuidora.portal.sesion'

export interface PortalCliente {
  nombre: string
  documento: string
  usuario: string
  vendedor: string | null
  empresa: string
  telefonoEmpresa: string | null
}

export interface PortalSesion {
  token: string
  cliente: PortalCliente
}

export function leerSesion(): PortalSesion | null {
  try {
    const crudo = localStorage.getItem(CLAVE_SESION)
    return crudo ? (JSON.parse(crudo) as PortalSesion) : null
  } catch {
    return null
  }
}

export function guardarSesion(sesion: PortalSesion | null) {
  try {
    if (sesion) localStorage.setItem(CLAVE_SESION, JSON.stringify(sesion))
    else localStorage.removeItem(CLAVE_SESION)
  } catch {
    // Modo privado: la sesión dura lo que la pestaña.
  }
}

function conSesion<T>(path: string, options: RequestOptions = {}) {
  const token = leerSesion()?.token
  return apiFetch<T>(path, {
    ...options,
    auth: false,
    headers: token
      ? {
          ...(options.headers as Record<string, string> | undefined),
          Authorization: `Bearer ${token}`,
        }
      : options.headers,
  })
}

export interface EnlacePortal {
  tipo: 'INVITACION' | 'RECUPERACION'
  cliente: string
  usuarioSugerido: string | null
  usuario: string | null
  empresa: string
}

// Los tipos de la cotización son los mismos que ve el panel.
export type { Cotizacion, EstadoCotizacion, LineaCotizacion } from '../facturacion/cotizacionApi'
export { ESTADO_COTIZACION } from '../facturacion/cotizacionApi'

export const portalApi = {
  enlace: (token: string) =>
    apiFetch<EnlacePortal>(`/portal/enlace/${encodeURIComponent(token)}`, {
      auth: false,
    }),

  activar: (body: { token: string; documento: string; usuario: string; password: string }) =>
    apiFetch<PortalSesion>('/portal/activar', {
      method: 'POST',
      body,
      auth: false,
    }),

  restablecer: (body: { token: string; password: string }) =>
    apiFetch<PortalSesion>('/portal/restablecer', {
      method: 'POST',
      body,
      auth: false,
    }),

  login: (body: { usuario: string; password: string }) =>
    apiFetch<PortalSesion>('/portal/login', {
      method: 'POST',
      body,
      auth: false,
    }),

  olvide: (usuario: string) =>
    apiFetch<{ message: string }>('/portal/olvide', {
      method: 'POST',
      body: { usuario },
      auth: false,
    }),

  yo: () => conSesion<PortalCliente>('/portal/yo'),

  /** El catálogo con los precios de SU lista, con ids para el carrito. */
  catalogo: async (): Promise<CatalogoResponse> => {
    const r = await conSesion<{
      categorias: string[]
      marcas: string[]
      productos: Omit<CatalogoProducto, 'clave'>[]
    }>('/portal/catalogo')
    const sesion = leerSesion()
    return {
      empresa: sesion?.cliente.empresa ?? '',
      telefono: sesion?.cliente.telefonoEmpresa ?? null,
      categorias: r.categorias,
      marcas: r.marcas,
      productos: r.productos.map((p, i) => ({ ...p, clave: p.id ?? i })),
    }
  },

  cotizaciones: () => conSesion<Cotizacion[]>('/portal/cotizaciones'),

  /** Los productos marcados con el corazón (ids). */
  favoritos: () => conSesion<number[]>('/portal/favoritos'),
  marcarFavorito: (productoId: number, favorito: boolean) =>
    conSesion<number[]>(`/portal/favoritos/${productoId}`, {
      method: favorito ? 'PUT' : 'DELETE',
    }),

  enviar: (body: { nota: string | null; detalle: { presentacionId: number; cantidad: number }[] }) =>
    conSesion<Cotizacion>('/portal/cotizaciones', { method: 'POST', body }),

  cancelar: (id: number) =>
    conSesion<Cotizacion>(`/portal/cotizaciones/${id}/cancelar`, {
      method: 'PATCH',
    }),
}

/** Ruta pública del portal: la de los enlaces de WhatsApp. */
export const RUTA_PORTAL = '/portal'
