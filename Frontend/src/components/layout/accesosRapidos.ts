import type { Accion } from '../../lib/permisos'
import { idPanel } from '../pestanas/estadoPestanas'

/** Un botón de la cabecera de una vista que se puede pulsar desde el menú, sin entrar primero a la vista. */
export interface AccesoRapido {
  /** El texto del botón, tal cual se lee en la cabecera: es como se lo encuentra al abrir la vista. */
  etiqueta: string
  /** Cómo se lee en el menú, si el botón solo dice algo corto ("Nuevo" en Categorías → "Nueva categoría"). */
  texto?: string
  /** El permiso que pide el botón. Sin permiso no se ofrece; si el botón no pide ninguno, se omite. */
  permiso?: Accion
  /** El submódulo de ese permiso, si no es el de la propia vista (los movimientos de la Bóveda, dentro de Cajas). */
  submodulo?: string
  /**
   * Si la vista tiene pestañas internas, el nombre de la pestaña del botón tal cual se lee: se abre antes de buscarlo.
   * Va también en los de la primera pestaña, por si la persona dejó la vista en otra.
   */
  pestana?: string
  /**
   * El botón no abre un modal sino que hace algo en la propia vista (Armar planilla): después de pulsarlo se va a ella
   * para ver el resultado.
   */
  mostrarVista?: boolean
}

const crear = (etiqueta: string, extra?: Partial<AccesoRapido>): AccesoRapido => ({ etiqueta, permiso: 'crear', ...extra })
const exportar = (etiqueta: string, extra?: Partial<AccesoRapido>): AccesoRapido => ({ etiqueta, permiso: 'exportar', ...extra })
const importar: AccesoRapido = { etiqueta: 'Importar', permiso: 'importar' }
const pdfDelTablero = [exportar('PDF', { texto: 'Exportar PDF' })]

/**
 * Los botones de cabecera de cada vista que se pueden usar desde el menú, por id del menú: los que crean algo, importan
 * o exportan. No van los que solo tienen sentido mirando la vista (Actualizar, Guardar, Anular, Depurar…).
 *
 * Las vistas no se montan hasta que se usan, así que no se les puede preguntar: la lista vive aquí. Si un botón cambia
 * de texto y no se actualiza esta lista, el acceso solo abre la vista (no rompe nada).
 *
 * Métodos de pago no va como vista suelta: al montarse redirige a Bancos, y ahí ya está como pestaña.
 */
export const ACCESOS_RAPIDOS: Record<string, AccesoRapido[]> = {
  'dashboard.ventas': pdfDelTablero,
  'dashboard.rentabilidad': pdfDelTablero,
  'dashboard.cobranza': pdfDelTablero,
  'dashboard.compras': pdfDelTablero,
  'dashboard.inventario': pdfDelTablero,
  'dashboard.reparto': pdfDelTablero,
  'dashboard.sinventas': [{ etiqueta: 'Exportar Excel' }],

  'maestros.clientes': [
    crear('Nuevo cliente'),
    importar,
    { etiqueta: 'Categorización', permiso: 'editar', submodulo: 'crm.categorizacion' },
  ],
  'maestros.proveedores': [crear('Nuevo proveedor'), importar],
  'maestros.productos': [
    crear('Nuevo producto', { pestana: 'Productos' }),
    { ...importar, pestana: 'Productos' },
    exportar('Exportar', { pestana: 'Productos' }),
    crear('Nuevo', { texto: 'Nueva categoría', pestana: 'Categorías' }),
    crear('Nuevo', { texto: 'Nueva marca', pestana: 'Marcas' }),
    crear('Nueva unidad', { pestana: 'Unidades' }),
  ],

  'compras.solicitudes': [crear('Nueva solicitud')],
  'compras.ordenes': [crear('Nueva orden')],
  'compras.compras': [crear('Nueva compra')],
  'compras.recepciones': [crear('Nueva recepción')],

  'inv.almacenes': [crear('Nuevo almacén')],
  'inv.ajustes': [crear('Nuevo ajuste', { pestana: 'Ajustes' }), crear('Nuevo motivo', { pestana: 'Motivos' })],
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
  'finanzas.cajas': [
    crear('Asignar caja', { pestana: 'Cajas' }),
    { etiqueta: 'Traer a la Bóveda', permiso: 'transferir', submodulo: 'finanzas.movimientos', pestana: 'Bóveda' },
    { etiqueta: 'Sacar de la Bóveda', permiso: 'transferir', submodulo: 'finanzas.movimientos', pestana: 'Bóveda' },
    crear('Crear bóveda', { pestana: 'Bóveda' }),
  ],
  'finanzas.bancos': [
    crear('Nuevo banco', { pestana: 'Bancos' }),
    crear('Nueva cuenta', { pestana: 'Cuentas Bancarias' }),
    crear('Nuevo método', { pestana: 'Métodos de pago', submodulo: 'finanzas.metodospago' }),
  ],
  'finanzas.movimientos': [
    { etiqueta: 'Nuevo movimiento' },
    { etiqueta: 'Mover plata', permiso: 'transferir' },
    exportar('Exportar'),
  ],
  'finanzas.operativos': [
    crear('Nueva plantilla', { pestana: 'Recurrentes' }),
    crear('Nueva categoría', { pestana: 'Categorías' }),
  ],
  'finanzas.financiamiento': [crear('Nuevo préstamo')],
  'finanzas.resultados': [exportar('Exportar')],

  'tms.mercados': [crear('Nuevo mercado')],
  'tms.rutas': [crear('Nueva ruta')],
  'tms.flota': [crear('Nuevo vehículo', { pestana: 'Vehículos' }), crear('Nuevo tipo', { pestana: 'Tipos de vehículo' })],
  'tms.conductores': [crear('Nuevo conductor')],
  'tms.despachos': [crear('Nuevo despacho')],
  'tms.novedades': [exportar('Reporte PDF')],
  'tms.motivos': [
    crear('Nuevo motivo', { pestana: 'Motivos' }),
    crear('Nuevo resultado', { pestana: 'Resultados de revisión' }),
  ],

  'crm.caida': [exportar('Exportar Excel')],
  'crm.vendedores': [exportar('Exportar Excel')],

  'rrhh.empleados': [crear('Nuevo empleado'), exportar('PDF', { texto: 'Exportar PDF' })],
  'rrhh.asistencia': [crear('Nueva marca'), exportar('PDF del mes', { texto: 'Exportar PDF del mes' })],
  'rrhh.planilla': [
    crear('Armar planilla', { pestana: 'Semana', mostrarVista: true }),
    crear('Pagar', { texto: 'Pagar planilla', pestana: 'Semana' }),
    exportar('Boletas', { texto: 'Exportar boletas', pestana: 'Semana' }),
    exportar('Planilla PDF', { texto: 'Exportar planilla PDF', pestana: 'Semana' }),
  ],
  'rrhh.adelantos': [crear('Nuevo adelanto'), exportar('PDF', { texto: 'Exportar PDF' })],

  'config.usuarios': [crear('Nuevo usuario')],
  'config.roles': [crear('Nuevo rol')],
}
/** Cuánto se espera a que la vista cargue (código y datos) y muestre el botón. */
const ESPERA_MAXIMA = 6000
/** Cuánto se espera, tras pulsar, a que salga el modal (algunos piden datos antes de abrirse). */
const ESPERA_MODAL = 2500

const modalesAbiertos = () => document.querySelectorAll('#modal-root [role="dialog"]').length

/**
 * Pulsa el botón de cabecera de una vista, que puede estar oculta (montada en el fondo o en otra pestaña): su modal sale
 * igual encima de lo que se esté viendo, porque los modales se pintan en #modal-root, fuera de los paneles.
 *
 * La vista puede tardar en aparecer (se baja su código, llegan sus datos y recién ahí habilita el botón), así que se
 * busca en cada cuadro hasta encontrarlo habilitado o rendirse. Si el botón es de una pestaña interna, primero se abre
 * esa pestaña (Tabs la marca con data-pestana). Se busca solo dentro del panel de esa vista y en la zona de botones de
 * su cabecera (PageHeader la marca con data-acciones-cabecera), para no pulsar uno de otra vista o de una fila de la
 * tabla.
 *
 * `irALaVista` se llama cuando lo que hizo el botón no se ve desde aquí: si no abrió un modal sino que cambió la propia
 * vista (Nuevo pedido pasa a un formulario de página completa), si el acceso lo pide (mostrarVista) o si el botón no
 * apareció.
 */
export function pulsarAccesoRapido(
  vista: string,
  { etiqueta, pestana, mostrarVista }: AccesoRapido,
  irALaVista: () => void,
) {
  const hasta = performance.now() + ESPERA_MAXIMA
  const panel = `#${idPanel(vista)}`
  let enSuPestana = !pestana

  /**
   * Tras pulsar: espera el modal. Si en cambio el botón desaparece, la vista cambió (pasó a un formulario de página
   * completa) y hay que mostrarla. Si no pasa ninguna de las dos, el botón hizo algo sin pantalla (una descarga) y no
   * hace falta moverse.
   */
  const esperarModal = (boton: HTMLButtonElement, antes: number) => {
    const limite = performance.now() + ESPERA_MODAL
    const mirar = () => {
      if (modalesAbiertos() > antes || performance.now() >= limite) return
      if (!boton.isConnected) return irALaVista()
      requestAnimationFrame(mirar)
    }
    requestAnimationFrame(mirar)
  }

  const buscar = () => {
    if (!enSuPestana) {
      const tab = [...document.querySelectorAll<HTMLButtonElement>(`${panel} [role="tab"][data-pestana]`)].find(
        (t) => t.dataset.pestana === pestana,
      )
      if (tab) {
        if (tab.getAttribute('aria-selected') !== 'true') tab.click()
        enSuPestana = true
      }
    } else {
      const botones = document.querySelectorAll<HTMLButtonElement>(`${panel} [data-acciones-cabecera] button`)
      const boton = [...botones].find((b) => b.textContent?.trim() === etiqueta)
      if (boton && !boton.disabled) {
        const antes = modalesAbiertos()
        boton.click()
        if (mostrarVista) irALaVista()
        else esperarModal(boton, antes)
        return
      }
    }
    if (performance.now() < hasta) requestAnimationFrame(buscar)
    else irALaVista()
  }

  requestAnimationFrame(buscar)
}