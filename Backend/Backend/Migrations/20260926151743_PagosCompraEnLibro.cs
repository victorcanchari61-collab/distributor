using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class PagosCompraEnLibro : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "MovimientoCuentaId",
                table: "CompraPago",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_CompraPago_MovimientoCuentaId",
                table: "CompraPago",
                column: "MovimientoCuentaId");

            migrationBuilder.AddForeignKey(
                name: "FK_CompraPago_MovimientosCuenta_MovimientoCuentaId",
                table: "CompraPago",
                column: "MovimientoCuentaId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CompraPago_MovimientosCuenta_MovimientoCuentaId",
                table: "CompraPago");

            migrationBuilder.DropIndex(
                name: "IX_CompraPago_MovimientoCuentaId",
                table: "CompraPago");

            migrationBuilder.DropColumn(
                name: "MovimientoCuentaId",
                table: "CompraPago");
        }
    }
}
