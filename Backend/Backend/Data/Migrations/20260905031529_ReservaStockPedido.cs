using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class ReservaStockPedido : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "AlmacenId",
                table: "Pedidos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ReservaStock",
                table: "Pedidos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_AlmacenId",
                table: "Pedidos",
                column: "AlmacenId");

            migrationBuilder.AddForeignKey(
                name: "FK_Pedidos_Almacenes_AlmacenId",
                table: "Pedidos",
                column: "AlmacenId",
                principalTable: "Almacenes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Pedidos_Almacenes_AlmacenId",
                table: "Pedidos");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_AlmacenId",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "AlmacenId",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "ReservaStock",
                table: "Pedidos");
        }
    }
}
