export { AlmacenesPage } from './AlmacenesPage'
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
} from './inventarioApi'
export type {
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
