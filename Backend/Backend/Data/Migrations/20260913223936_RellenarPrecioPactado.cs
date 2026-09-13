using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class RellenarPrecioPactado : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            /*
             * Lo ya guardado: se deduce del importe de la linea.
             *
             * El precio pactado no existia como dato, pero el importe si —es
             * cantidad base por precio base—, y dividirlo entre las
             * presentaciones devuelve lo que se cobro por cada saco. No es
             * inventar un numero: es el mismo total que ya figura en el papel
             * que firmo el cliente.
             *
             * Va en su propia migracion porque la que creo las columnas ya
             * estaba aplicada, y una migracion aplicada no se toca.
             */
            foreach (var tabla in new[] { "PedidoDetalle", "NotaVentaDetalle" })
            {
                migrationBuilder.Sql($@"
                    UPDATE `{tabla}`
                    SET `PrecioPresentacion` = CASE
                        WHEN `CantidadPresentacion` > 0
                            THEN ROUND(`Cantidad` * `PrecioUnitario` / `CantidadPresentacion`, 4)
                        ELSE `PrecioUnitario`
                    END
                    WHERE `PrecioPresentacion` = 0;");
            }
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
