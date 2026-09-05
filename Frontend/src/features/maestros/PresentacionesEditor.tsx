import { Plus, Trash2 } from 'lucide-react'
import { Badge, Button, Checkbox, Desplegable, Input, RowAction, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import type { PresentacionRequest, UnidadResponse } from './productoApi'

export interface FilaPresentacion extends PresentacionRequest {
  /** Id cuando ya existe en la base; undefined mientras es nueva. */
  id?: number
  esBase?: boolean
  /** Clave estable para la tabla: SysDataTable la necesita aunque la fila sea nueva y no tenga id. */
  clave: string
}

export interface PresentacionesEditorProps {
  filas: FilaPresentacion[]
  unidades: UnidadResponse[]
  /** Código de la unidad base del producto, para leer los factores. */
  unidadBase: string
  onChange: (filas: FilaPresentacion[]) => void
  disabled?: boolean
}

/**
 * Editor de las formas de comprar y vender un producto.
 *
 * El factor es la pieza que hay que entender: dice cuántas unidades base
 * equivale una presentación. Un saco de 50 kg tiene factor 50, y comprar dos
 * mete 100 kg al almacén. Por eso cada fila muestra la equivalencia escrita.
 *
 * La presentación base (factor 1) no aparece aquí: la crea el backend con la
 * unidad base y no se puede borrar ni cambiar.
 */
export function PresentacionesEditor({
  filas,
  unidades,
  unidadBase,
  onChange,
  disabled,
}: PresentacionesEditorProps) {
  const activas = unidades.filter((u) => u.activo)

  const actualizar = (indice: number, cambio: Partial<FilaPresentacion>) =>
    onChange(filas.map((f, i) => (i === indice ? { ...f, ...cambio } : f)))

  const agregar = () =>
    onChange([
      ...filas,
      {
        clave: crypto.randomUUID(),
        unidadId: activas[0]?.id ?? 0,
        nombre: '',
        factor: 0,
        esCompra: true,
        esVenta: true,
        activo: true,
      },
    ])

  const quitar = (clave: string) => onChange(filas.filter((f) => f.clave !== clave))

  const columnas: DataTableColumn<FilaPresentacion>[] = [
    {
      key: 'nombre',
      label: 'Nombre',
      render: (fila) => (
        <Input
          size="sm"
          placeholder="Saco 50 kg"
          value={fila.nombre}
          onChange={(e) => actualizar(filas.indexOf(fila), { nombre: e.target.value })}
          disabled={disabled}
        />
      ),
    },
    {
      key: 'unidad',
      label: 'Unidad',
      render: (fila) => (
        <Desplegable
          value={fila.unidadId}
          onChange={(v) => actualizar(filas.indexOf(fila), { unidadId: Number(v) })}
          disabled={disabled}
          options={activas.map((u) => ({ value: u.id, label: u.codigo, nota: u.nombre }))}
        />
      ),
    },
    {
      key: 'factor',
      label: 'Factor',
      align: 'right',
      value: (fila) => fila.factor,
      render: (fila) => (
        <Input
          size="sm"
          type="number"
          min={0}
          step="0.0001"
          value={fila.factor || ''}
          onChange={(e) => actualizar(filas.indexOf(fila), { factor: Number(e.target.value) })}
          disabled={disabled}
        />
      ),
    },
    {
      key: 'equivalencia',
      label: 'Equivalencia',
      render: (fila) => {
        const unidad = activas.find((u) => u.id === fila.unidadId)
        return (
          // La equivalencia escrita evita el error clasico de poner el
          // factor al reves (1/50 en vez de 50).
          <Badge tone={fila.factor > 0 ? 'sys' : 'neutral'}>
            {fila.factor > 0
              ? `1 ${unidad?.codigo ?? '?'} = ${fila.factor} ${unidadBase}`
              : 'Falta el factor'}
          </Badge>
        )
      },
    },
    {
      key: 'esCompra',
      label: 'Se compra',
      render: (fila) => (
        <Checkbox
          label=""
          checked={fila.esCompra}
          onChange={(e) => actualizar(filas.indexOf(fila), { esCompra: e.target.checked })}
          disabled={disabled}
        />
      ),
    },
    {
      key: 'esVenta',
      label: 'Se vende',
      render: (fila) => (
        <Checkbox
          label=""
          checked={fila.esVenta}
          onChange={(e) => actualizar(filas.indexOf(fila), { esVenta: e.target.checked })}
          disabled={disabled}
        />
      ),
    },
  ]

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-ink">Presentaciones</p>
          <p className="text-xs text-ink-soft">
            Cómo se compra y se vende. El factor dice a cuántos{' '}
            <span className="font-semibold">{unidadBase || 'unidad base'}</span> equivale.
          </p>
        </div>
        <Button variant="secondary" size="sm" onClick={agregar} disabled={disabled}>
          <Plus size={15} />
          Agregar
        </Button>
      </div>

      <SysDataTable<FilaPresentacion>
        columns={columnas}
        rows={filas}
        rowKey="clave"
        toolbar={false}
        empty={`Solo se venderá por ${unidadBase || 'la unidad base'}. Agrega una presentación si además vendes por saco, caja o bolsa.`}
        actions={(fila) => (
          <RowAction
            label={`Quitar ${fila.nombre || 'presentación'}`}
            tone="danger"
            disabled={disabled}
            onClick={() => quitar(fila.clave)}
          >
            <Trash2 size={15} />
          </RowAction>
        )}
      />
    </div>
  )
}
