using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class AgregarPrestamoDetalleIdAMovimiento : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PrestamoDetalleId",
                table: "MovimientosInventario",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_PrestamoDetalleId",
                table: "MovimientosInventario",
                column: "PrestamoDetalleId");

            migrationBuilder.AddForeignKey(
                name: "FK_MovimientosInventario_PrestamoDetalle_PrestamoDetalleId",
                table: "MovimientosInventario",
                column: "PrestamoDetalleId",
                principalTable: "PrestamoDetalle",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MovimientosInventario_PrestamoDetalle_PrestamoDetalleId",
                table: "MovimientosInventario");

            migrationBuilder.DropIndex(
                name: "IX_MovimientosInventario_PrestamoDetalleId",
                table: "MovimientosInventario");

            migrationBuilder.DropColumn(
                name: "PrestamoDetalleId",
                table: "MovimientosInventario");
        }
    }
}
