using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class ClienteListaPrecioYCondicionPago : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CondicionPago",
                table: "Pedidos",
                type: "longtext",
                nullable: false,
                // Los pedidos que ya existen no tienen condicion acordada: sin
                // esto MySQL los deja en blanco y el repartidor no lee nada.
                // Contado es lo normal y lo que usa el modelo por defecto.
                defaultValue: "CONTADO")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "ListaPrecioId",
                table: "Clientes",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Clientes_ListaPrecioId",
                table: "Clientes",
                column: "ListaPrecioId");

            migrationBuilder.AddForeignKey(
                name: "FK_Clientes_ListasPrecio_ListaPrecioId",
                table: "Clientes",
                column: "ListaPrecioId",
                principalTable: "ListasPrecio",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Clientes_ListasPrecio_ListaPrecioId",
                table: "Clientes");

            migrationBuilder.DropIndex(
                name: "IX_Clientes_ListaPrecioId",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "CondicionPago",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "ListaPrecioId",
                table: "Clientes");
        }
    }
}
