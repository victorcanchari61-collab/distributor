import type { Accion } from '../../lib/permisos'
import { idPanel } from '../pestanas/estadoPestanas'

/** Un botón de la cabecera de una vista que se puede pulsar desde el menú, sin entrar primero a la vista. */
export interface AccesoRapido {
  /** El texto del botón, tal cual se lee en la cabecera: es como se lo encuentra al abrir la vista. */
  etiqueta: string
  /** El permiso que pide el botón. Sin permiso no se ofrece; si el botón no pide ninguno, se omite. */
  permiso?: Accion
}

const crear = (etiqueta: string): AccesoRapido => ({ etiqueta, permiso: 'crear' })

/**
 * Los botones de cabecera de cada vista (las que abren un modal o arman algo nuevo), por id del menú.
 *
 * Las vistas no se montan hasta que se abren, así que no se pueden preguntar: la lista vive aquí. Si un botón cambia
 * de texto y no se actualiza esta lista, el acceso solo abre la vista (no rompe nada). Solo van los botones de la
 * cabecera principal: los de una pestaña interna (Unidades, Tipos de vehículo…) no se ven al abrir la vista.
 */
export const ACCESOS_RAPIDOS: Record<string, AccesoRapido[]> = {
  'maestros.clientes': [crear('Nuevo cliente'), { etiqueta: 'Importar', permiso: 'importar' }],
  'maestros.proveedores': [crear('Nuevo proveedor'), { etiqueta: 'Importar', permiso: 'importar' }],
  'maestros.productos': [crear('Nuevo producto'), { etiqueta: 'Importar', permiso: 'importar' }],

  'compras.solicitudes': [crear('Nueva solicitud')],
  'compras.ordenes': [crear('Nueva orden')],
  'compras.compras': [crear('Nueva compra')],
  'compras.recepciones': [crear('Nueva recepción')],

  'inv.almacenes': [crear('Nuevo almacén')],
  'inv.ajustes': [crear('Nuevo ajuste')],
  'inv.transferencias': [crear('Nueva transferencia')],
  'inv.prestamos': [crear('Nuevo préstamo')],

  'fact.pedidos': [crear('Nuevo pedido')],
  'fact.notaventa': [crear('Nueva venta')],
  'fact.precios': [crear('Nueva lista'), crear('Agregar precio')],
  'fact.facturas': [crear('Nueva factura')],
  'fact.boletas': [crear('Nueva boleta')],

  'finanzas.caja': [
    { etiqueta: 'Ingreso', permiso: 'ingreso' },
    { etiqueta: 'Egreso', permiso: 'egreso' },
    { etiqueta: 'Cerrar caja' },
  ],
  'finanzas.cajas': [crear('Asignar caja')],
  'finanzas.bancos': [crear('Nueva cuenta')],
  'finanzas.metodospago': [crear('Nuevo método')],
  'finanzas.movimientos': [{ etiqueta: 'Nuevo movimiento' }, { etiqueta: 'Mover plata', permiso: 'transferir' }],
  'finanzas.financiamiento': [crear('Nuevo préstamo')],

  'tms.mercados': [crear('Nuevo mercado')],
  'tms.rutas': [crear('Nueva ruta')],
  'tms.flota': [crear('Nuevo vehículo')],
  'tms.conductores': [crear('Nuevo conductor')],
  'tms.despachos': [crear('Nuevo despacho')],
  'tms.motivos': [crear('Nuevo motivo')],

  'rrhh.empleados': [crear('Nuevo empleado')],
  'rrhh.asistencia': [crear('Nueva marca')],
  'rrhh.planilla': [crear('Armar planilla'), crear('Pagar')],
  'rrhh.adelantos': [crear('Nuevo adelanto')],

  'config.usuarios': [crear('Nuevo usuario')],
  'config.roles': [crear('Nuevo rol')],
}

/** Cuánto se espera a que la vista cargue (código y datos) y muestre el botón. */
const ESPERA_MAXIMA = 6000

/**
 * Pulsa el botón de cabecera de una vista que se acaba de abrir.
 *
 * La vista puede tardar en aparecer (se baja su código, llegan sus datos y recién ahí habilita el botón), así que se
 * busca en cada cuadro hasta encontrarlo habilitado o rendirse. Se busca solo dentro del panel de esa pestaña y en la
 * zona de botones de su cabecera (PageHeader la marca con data-acciones-cabecera), para no pulsar uno de otra vista o
 * de una fila de la tabla. Si no aparece, la vista queda abierta y nada más.
 */
export function pulsarAccesoRapido(vista: string, etiqueta: string) {
  const hasta = performance.now() + ESPERA_MAXIMA

  const buscar = () => {
    const botones = document.querySelectorAll<HTMLButtonElement>(`#${idPanel(vista)} [data-acciones-cabecera] button`)
    const boton = [...botones].find((b) => b.textContent?.trim() === etiqueta)
    if (boton && !boton.disabled) {
      boton.click()
      return
    }
    if (performance.now() < hasta) requestAnimationFrame(buscar)
  }

  requestAnimationFrame(buscar)
}
