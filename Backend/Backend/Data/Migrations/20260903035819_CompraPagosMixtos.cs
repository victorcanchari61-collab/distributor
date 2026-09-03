using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class CompraPagosMixtos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Compras_MetodosPago_MetodoPagoId",
                table: "Compras");

            migrationBuilder.DropIndex(
                name: "IX_Compras_MetodoPagoId",
                table: "Compras");

            migrationBuilder.DropColumn(
                name: "MetodoPagoId",
                table: "Compras");

            migrationBuilder.CreateTable(
                name: "CompraPago",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CompraId = table.Column<int>(type: "int", nullable: false),
                    MetodoPagoId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CompraPago", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CompraPago_Compras_CompraId",
                        column: x => x.CompraId,
                        principalTable: "Compras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CompraPago_MetodosPago_MetodoPagoId",
                        column: x => x.MetodoPagoId,
                        principalTable: "MetodosPago",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_CompraPago_CompraId",
                table: "CompraPago",
                column: "CompraId");

            migrationBuilder.CreateIndex(
                name: "IX_CompraPago_MetodoPagoId",
                table: "CompraPago",
                column: "MetodoPagoId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CompraPago");

            migrationBuilder.AddColumn<int>(
                name: "MetodoPagoId",
                table: "Compras",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Compras_MetodoPagoId",
                table: "Compras",
                column: "MetodoPagoId");

            migrationBuilder.AddForeignKey(
                name: "FK_Compras_MetodosPago_MetodoPagoId",
                table: "Compras",
                column: "MetodoPagoId",
                principalTable: "MetodosPago",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
