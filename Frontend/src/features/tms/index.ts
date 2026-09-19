export { MercadosPage } from './MercadosPage'
export { mercadoApi } from './mercadoApi'
export type { MercadoRequest, MercadoResponse } from './mercadoApi'
export { FlotaPage } from './FlotaPage'
export { ConductoresPage } from './ConductoresPage'
export { conductorApi, tipoVehiculoApi, vehiculoApi, archivoApi, urlImagen } from './flotaApi'
export type {
  ConductorRequest,
  ConductorResponse,
  EstadoDocumento,
  ResumenConductoresResponse,
  ResumenFlotaResponse,
  TipoVehiculoRequest,
  TipoVehiculoResponse,
  VehiculoRequest,
  VehiculoResponse,
  VencimientoResponse,
} from './flotaApi'
export { RutasPage } from './RutasPage'
export { rutaApi } from './rutaApi'
export type { RutaRequest, RutaResponse } from './rutaApi'
export { DespachosPage } from './DespachosPage'
export { despachoApi } from './despachoApi'
export type {
  DespachoPedidoResponse,
  DespachoRequest,
  DespachoResponse,
  EstadoDespacho,
  ResumenDespachos,
} from './despachoApi'
export { MotivosNovedadPage } from './MotivosNovedadPage'
export { motivoNovedadApi } from './motivoNovedadApi'
export type { MotivoNovedadOpcion, MotivoNovedadRequest, MotivoNovedadResponse } from './motivoNovedadApi'
export { NovedadesPage } from './NovedadesPage'
export { novedadApi, textoCantidad } from './novedadApi'
export type { EstadoNovedad, NovedadResponse, ResumenNovedades, TipoNovedad } from './novedadApi'
