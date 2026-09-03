using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class MetodoPagoCatalogo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "InstrumentoPago",
                table: "Compras");

            migrationBuilder.AddColumn<int>(
                name: "MetodoPagoId",
                table: "Compras",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "MetodosPago",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MetodosPago", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "MetodosPago",
                columns: new[] { "Id", "Activo", "Nombre" },
                values: new object[,]
                {
                    { 1, true, "Efectivo" },
                    { 2, true, "Transferencia" },
                    { 3, true, "Depósito" },
                    { 4, true, "Tarjeta" },
                    { 5, true, "Cheque" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Compras_MetodoPagoId",
                table: "Compras",
                column: "MetodoPagoId");

            migrationBuilder.CreateIndex(
                name: "IX_MetodosPago_Nombre",
                table: "MetodosPago",
                column: "Nombre",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Compras_MetodosPago_MetodoPagoId",
                table: "Compras",
                column: "MetodoPagoId",
                principalTable: "MetodosPago",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Compras_MetodosPago_MetodoPagoId",
                table: "Compras");

            migrationBuilder.DropTable(
                name: "MetodosPago");

            migrationBuilder.DropIndex(
                name: "IX_Compras_MetodoPagoId",
                table: "Compras");

            migrationBuilder.DropColumn(
                name: "MetodoPagoId",
                table: "Compras");

            migrationBuilder.AddColumn<string>(
                name: "InstrumentoPago",
                table: "Compras",
                type: "varchar(15)",
                maxLength: 15,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }
    }
}
