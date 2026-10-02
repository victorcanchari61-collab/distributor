using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class ResultadosRevision : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ResultadoRevisionId",
                table: "NovedadesEntrega",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ResultadosRevision",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    VolvioTodo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ResultadosRevision", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "ResultadosRevision",
                columns: new[] { "Id", "Activo", "Descripcion", "FechaCreacion", "Nombre", "VolvioTodo" },
                values: new object[,]
                {
                    { 1, true, "Está de vuelta en el almacén", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Volvió completa", true },
                    { 2, true, "No volvió todo lo que no se entregó", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Faltó algo", false }
                });

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_ResultadoRevisionId",
                table: "NovedadesEntrega",
                column: "ResultadoRevisionId");

            migrationBuilder.CreateIndex(
                name: "IX_ResultadosRevision_Nombre",
                table: "ResultadosRevision",
                column: "Nombre",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_NovedadesEntrega_ResultadosRevision_ResultadoRevisionId",
                table: "NovedadesEntrega",
                column: "ResultadoRevisionId",
                principalTable: "ResultadosRevision",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            // Las revisiones ya hechas se enlazan a los dos resultados de siempre.
            migrationBuilder.Sql(
                "UPDATE NovedadesEntrega SET ResultadoRevisionId = 1 WHERE Estado = 'RECIBIDA';");
            migrationBuilder.Sql(
                "UPDATE NovedadesEntrega SET ResultadoRevisionId = 2 WHERE Estado = 'FALTANTE';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_NovedadesEntrega_ResultadosRevision_ResultadoRevisionId",
                table: "NovedadesEntrega");

            migrationBuilder.DropTable(
                name: "ResultadosRevision");

            migrationBuilder.DropIndex(
                name: "IX_NovedadesEntrega_ResultadoRevisionId",
                table: "NovedadesEntrega");

            migrationBuilder.DropColumn(
                name: "ResultadoRevisionId",
                table: "NovedadesEntrega");
        }
    }
}
