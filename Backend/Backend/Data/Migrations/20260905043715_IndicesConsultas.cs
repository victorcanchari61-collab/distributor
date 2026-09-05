using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class IndicesConsultas : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Prestamos_Estado",
                table: "Prestamos",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_Prestamos_Fecha",
                table: "Prestamos",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_Estado_ReservaStock",
                table: "Pedidos",
                columns: new[] { "Estado", "ReservaStock" });

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_Fecha",
                table: "Pedidos",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_OrdenesCompra_Estado",
                table: "OrdenesCompra",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_OrdenesCompra_Fecha",
                table: "OrdenesCompra",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_NotasVenta_Estado",
                table: "NotasVenta",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_NotasVenta_Fecha",
                table: "NotasVenta",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_Estado",
                table: "DocumentosInventario",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_Tipo_Fecha",
                table: "DocumentosInventario",
                columns: new[] { "Tipo", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_Compras_Estado",
                table: "Compras",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_Compras_Fecha",
                table: "Compras",
                column: "Fecha");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Prestamos_Estado",
                table: "Prestamos");

            migrationBuilder.DropIndex(
                name: "IX_Prestamos_Fecha",
                table: "Prestamos");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_Estado_ReservaStock",
                table: "Pedidos");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_Fecha",
                table: "Pedidos");

            migrationBuilder.DropIndex(
                name: "IX_OrdenesCompra_Estado",
                table: "OrdenesCompra");

            migrationBuilder.DropIndex(
                name: "IX_OrdenesCompra_Fecha",
                table: "OrdenesCompra");

            migrationBuilder.DropIndex(
                name: "IX_NotasVenta_Estado",
                table: "NotasVenta");

            migrationBuilder.DropIndex(
                name: "IX_NotasVenta_Fecha",
                table: "NotasVenta");

            migrationBuilder.DropIndex(
                name: "IX_DocumentosInventario_Estado",
                table: "DocumentosInventario");

            migrationBuilder.DropIndex(
                name: "IX_DocumentosInventario_Tipo_Fecha",
                table: "DocumentosInventario");

            migrationBuilder.DropIndex(
                name: "IX_Compras_Estado",
                table: "Compras");

            migrationBuilder.DropIndex(
                name: "IX_Compras_Fecha",
                table: "Compras");
        }
    }
}
