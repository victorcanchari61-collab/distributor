using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class ConfirmarCobrosDigitalesAlCuadrar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PagoVentaId",
                table: "ArqueoPagosDigitales",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_PagoVentaId",
                table: "ArqueoPagosDigitales",
                column: "PagoVentaId");

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoPagosDigitales_PagoVenta_PagoVentaId",
                table: "ArqueoPagosDigitales",
                column: "PagoVentaId",
                principalTable: "PagoVenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoPagosDigitales_PagoVenta_PagoVentaId",
                table: "ArqueoPagosDigitales");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoPagosDigitales_PagoVentaId",
                table: "ArqueoPagosDigitales");

            migrationBuilder.DropColumn(
                name: "PagoVentaId",
                table: "ArqueoPagosDigitales");
        }
    }
}
