export { AlmacenesPage } from './AlmacenesPage'
export { UbicacionProductosPage } from './UbicacionProductosPage'
export { StockPage } from './StockPage'
export { KardexPage } from './KardexPage'
export { AjustesPage } from './AjustesPage'
export { TransferenciasPage } from './TransferenciasPage'
export { PrestamosPage } from './PrestamosPage'
export { LotesVencimientosPage } from './LotesVencimientosPage'
export { ConteosPage } from './ConteosPage'
export {
  almacenApi,
  motivoApi,
  stockApi,
  kardexApi,
  ajusteApi,
  transferenciaApi,
  prestamoApi,
  recepcionApi,
  loteApi,
  ubicacionApi,
  ubicacionProductoApi,
} from './inventarioApi'
export type { AlmacenOpcion, DisponibleResponse } from './inventarioApi'
export type { ProductosUbicados, ProductoUbicado, UbicacionResponse } from './inventarioApi'
export type {
  ResumenDocumentos,
  ResumenPrestamos,
  ResumenKardex,
  AlmacenResponse,
  MotivoResponse,
  StockResponse,
  CapaResponse,
  KardexResponse,
  DocumentoInventarioResponse,
  LineaDocumentoResponse,
  PrestamoResponse,
  PrestamoDetalleResponse,
  TipoPrestamo,
  EstadoPrestamo,
  CrearRecepcionRequest,
  LineaRecepcionRequest,
  LoteResponse,
  CrearAjusteRequest,
  LineaAjusteRequest,
} from './inventarioApi'
