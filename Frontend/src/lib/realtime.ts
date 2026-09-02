import { useEffect, useRef } from 'react'
import { HttpTransportType, HubConnectionBuilder, LogLevel, type HubConnection } from '@microsoft/signalr'
import { getToken } from './authStorage'

const HUB_URL = 'http://localhost:5220/hubs/cambios'

export type CambioEvento = {
  modulo: string
  accion: string
  datos: unknown
  fecha: string
}

type Escucha = (evento: CambioEvento) => void

let conexion: HubConnection | null = null
const escuchas = new Set<Escucha>()

/**
 * Una sola conexión para toda la app: cada página se suscribe con
 * suscribirCambios en vez de abrir su propio socket.
 */
function obtenerConexion(): HubConnection {
  if (conexion) return conexion

  conexion = new HubConnectionBuilder()
    .withUrl(HUB_URL, {
      accessTokenFactory: () => getToken() ?? '',
      transport: HttpTransportType.WebSockets,
    })
    .withAutomaticReconnect()
    .configureLogging(LogLevel.Warning)
    .build()

  conexion.on('cambio', (evento: CambioEvento) => {
    for (const escucha of escuchas) escucha(evento)
  })

  void conexion.start().catch(() => {
    // Sin conexión en tiempo real la app sigue funcionando: solo no se
    // actualiza sola. El usuario puede recargar como antes.
  })

  return conexion
}

/**
 * Escucha cambios de uno o varios módulos ("clientes", "stock"...) y llama a
 * `onCambio` cuando alguno ocurre. Devuelve la función para dejar de
 * escuchar; se llama en el cleanup del efecto de React.
 */
export function suscribirCambios(modulos: string | string[], onCambio: (evento: CambioEvento) => void) {
  const lista = Array.isArray(modulos) ? modulos : [modulos]
  obtenerConexion()

  const escucha: Escucha = evento => {
    if (lista.includes(evento.modulo)) onCambio(evento)
  }

  escuchas.add(escucha)
  return () => {
    escuchas.delete(escucha)
  }
}

/**
 * Vuelve a llamar `recargar` cuando algún otro cliente cambia algo en
 * `modulos`. Se usa junto al cargar() que cada página ya tiene:
 *
 *   useRealtime('clientes', cargar)
 */
export function useRealtime(modulos: string | string[], recargar: () => void) {
  const recargarRef = useRef(recargar)
  recargarRef.current = recargar

  // Se compara como texto: un array nuevo en cada render no debe reabrir
  // la suscripción, solo un cambio real en la lista de módulos.
  const clave = Array.isArray(modulos) ? modulos.join(',') : modulos

  useEffect(() => {
    return suscribirCambios(clave.split(','), () => recargarRef.current())
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [clave])
}
