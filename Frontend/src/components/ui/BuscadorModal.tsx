import { Modal } from './Modal'
import { SysDataTable } from './SysDataTable'
import type { SysDataTableProps } from './SysDataTable'
import { Button } from './Button'

export interface BuscadorModalProps<T> extends Omit<SysDataTableProps<T>, 'actions'> {
  open: boolean
  onClose: () => void
  title: string
  description?: string
  /** Se llama con la fila elegida; el modal se cierra solo después. */
  onSeleccionar: (row: T) => void
  elegirLabel?: (row: T) => string
}

/**
 * Elegir UNO de una lista larga: un proveedor, un cliente, un producto.
 *
 * Es SysDataTable (buscador general, filtros por columna, orden) dentro de
 * un Modal, con una columna de acción para elegir la fila en vez de editarla.
 * No junta su propia lógica de búsqueda: reutiliza la que ya tiene la tabla
 * de listados de toda la app, para que un campo de búsqueda se vea y se
 * comporte igual en cualquier pantalla donde se use.
 */
export function BuscadorModal<T>({
  open,
  onClose,
  title,
  description,
  onSeleccionar,
  elegirLabel,
  ...table
}: BuscadorModalProps<T>) {
  return (
    <Modal open={open} title={title} description={description} onClose={onClose} size="lg">
      <SysDataTable
        {...table}
        actions={(row) => (
          <Button
            size="sm"
            onClick={() => {
              onSeleccionar(row)
              onClose()
            }}
          >
            {elegirLabel ? elegirLabel(row) : 'Elegir'}
          </Button>
        )}
      />
    </Modal>
  )
}
