using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class CrearRutaComoSubmodulo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Rutas",
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
                    table.PrimaryKey("PK_Rutas", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "RutaId",
                table: "Clientes",
                type: "int",
                nullable: true);

            // Cada valor distinto que ya tenia un cliente en el texto libre
            // "Ruta" se vuelve una fila del nuevo catalogo Rutas, y el cliente
            // queda apuntando a ella — nada se pierde.
            migrationBuilder.Sql(
                "INSERT INTO Rutas (Nombre, Activo, FechaCreacion) " +
                "SELECT DISTINCT Ruta, 1, UTC_TIMESTAMP() FROM Clientes " +
                "WHERE Ruta IS NOT NULL AND Ruta <> '';");

            migrationBuilder.Sql(
                "UPDATE Clientes c INNER JOIN Rutas r ON c.Ruta = r.Nombre " +
                "SET c.RutaId = r.Id WHERE c.Ruta IS NOT NULL;");

            migrationBuilder.DropColumn(
                name: "Ruta",
                table: "Clientes");

            migrationBuilder.CreateIndex(
                name: "IX_Clientes_RutaId",
                table: "Clientes",
                column: "RutaId");

            migrationBuilder.CreateIndex(
                name: "IX_Rutas_Nombre",
                table: "Rutas",
                column: "Nombre",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Clientes_Rutas_RutaId",
                table: "Clientes",
                column: "RutaId",
                principalTable: "Rutas",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Clientes_Rutas_RutaId",
                table: "Clientes");

            migrationBuilder.AddColumn<string>(
                name: "Ruta",
                table: "Clientes",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.Sql(
                "UPDATE Clientes c INNER JOIN Rutas r ON c.RutaId = r.Id " +
                "SET c.Ruta = r.Nombre;");

            migrationBuilder.DropTable(
                name: "Rutas");

            migrationBuilder.DropIndex(
                name: "IX_Clientes_RutaId",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "RutaId",
                table: "Clientes");
        }
    }
}
