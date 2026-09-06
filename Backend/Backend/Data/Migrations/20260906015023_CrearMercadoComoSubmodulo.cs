using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class CrearMercadoComoSubmodulo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Mercados",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Mercados", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "MercadoId",
                table: "Clientes",
                type: "int",
                nullable: true);

            // Cada valor distinto que ya tenía un cliente en el texto libre
            // "PuntoReparto" se vuelve una fila del nuevo catálogo Mercados,
            // y el cliente queda apuntando a ella — nada se pierde.
            migrationBuilder.Sql(
                "INSERT INTO Mercados (Nombre, Activo, FechaCreacion) " +
                "SELECT DISTINCT PuntoReparto, 1, UTC_TIMESTAMP() FROM Clientes " +
                "WHERE PuntoReparto IS NOT NULL AND PuntoReparto <> '';");

            migrationBuilder.Sql(
                "UPDATE Clientes c INNER JOIN Mercados m ON c.PuntoReparto = m.Nombre " +
                "SET c.MercadoId = m.Id WHERE c.PuntoReparto IS NOT NULL;");

            migrationBuilder.DropColumn(
                name: "PuntoReparto",
                table: "Clientes");

            migrationBuilder.CreateIndex(
                name: "IX_Clientes_MercadoId",
                table: "Clientes",
                column: "MercadoId");

            migrationBuilder.CreateIndex(
                name: "IX_Mercados_Nombre",
                table: "Mercados",
                column: "Nombre",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Clientes_Mercados_MercadoId",
                table: "Clientes",
                column: "MercadoId",
                principalTable: "Mercados",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Clientes_Mercados_MercadoId",
                table: "Clientes");

            migrationBuilder.AddColumn<string>(
                name: "PuntoReparto",
                table: "Clientes",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.Sql(
                "UPDATE Clientes c INNER JOIN Mercados m ON c.MercadoId = m.Id " +
                "SET c.PuntoReparto = m.Nombre;");

            migrationBuilder.DropTable(
                name: "Mercados");

            migrationBuilder.DropIndex(
                name: "IX_Clientes_MercadoId",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "MercadoId",
                table: "Clientes");
        }
    }
}
