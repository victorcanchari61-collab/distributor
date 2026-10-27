using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class CategorizacionClientes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CalculosCategorizacion",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Ciclo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    EvaluadoDesde = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    EvaluadoHasta = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    VigenteDesde = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    VigenteHasta = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CalculadoEn = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Automatico = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    Clientes = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CalculosCategorizacion", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CalculosCategorizacion_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "CategoriasCliente",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Codigo = table.Column<string>(type: "varchar(1)", maxLength: 1, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Color = table.Column<string>(type: "varchar(12)", maxLength: 12, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Desde = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CategoriasCliente", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ConfiguracionCategorizacion",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Ciclo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ActualizadoEn = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConfiguracionCategorizacion", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConfiguracionCategorizacion_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ClientesCategoria",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CalculoId = table.Column<int>(type: "int", nullable: false),
                    ClienteId = table.Column<int>(type: "int", nullable: false),
                    Codigo = table.Column<string>(type: "varchar(1)", maxLength: 1, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ClientesCategoria", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ClientesCategoria_CalculosCategorizacion_CalculoId",
                        column: x => x.CalculoId,
                        principalTable: "CalculosCategorizacion",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ClientesCategoria_Clientes_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Clientes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "CategoriasCliente",
                columns: new[] { "Id", "Codigo", "Color", "Desde", "Nombre" },
                values: new object[,]
                {
                    { 1, "A", "sky", 250000m, "Socio" },
                    { 2, "B", "emerald", 35000m, "Distribuidor" },
                    { 3, "C", "amber", 20000m, "Mayorista" },
                    { 4, "D", "orange", 5000m, "Minorista" },
                    { 5, "E", "violet", 1000m, "Emprendedor" },
                    { 6, "F", "slate", 0m, "Inactivo" }
                });

            migrationBuilder.InsertData(
                table: "ConfiguracionCategorizacion",
                columns: new[] { "Id", "ActualizadoEn", "Ciclo", "UsuarioId" },
                values: new object[] { 1, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "TRIMESTRAL", null });

            migrationBuilder.CreateIndex(
                name: "IX_CalculosCategorizacion_UsuarioId",
                table: "CalculosCategorizacion",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_CalculosCategorizacion_VigenteDesde_CalculadoEn",
                table: "CalculosCategorizacion",
                columns: new[] { "VigenteDesde", "CalculadoEn" });

            migrationBuilder.CreateIndex(
                name: "IX_CategoriasCliente_Codigo",
                table: "CategoriasCliente",
                column: "Codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ClientesCategoria_CalculoId_ClienteId",
                table: "ClientesCategoria",
                columns: new[] { "CalculoId", "ClienteId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ClientesCategoria_ClienteId",
                table: "ClientesCategoria",
                column: "ClienteId");

            migrationBuilder.CreateIndex(
                name: "IX_ConfiguracionCategorizacion_UsuarioId",
                table: "ConfiguracionCategorizacion",
                column: "UsuarioId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CategoriasCliente");

            migrationBuilder.DropTable(
                name: "ClientesCategoria");

            migrationBuilder.DropTable(
                name: "ConfiguracionCategorizacion");

            migrationBuilder.DropTable(
                name: "CalculosCategorizacion");
        }
    }
}
