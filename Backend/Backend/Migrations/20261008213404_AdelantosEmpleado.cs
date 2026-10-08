using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class AdelantosEmpleado : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "AdelantosManual",
                table: "PlanillaDetalles",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "AdelantosSaldo",
                table: "PlanillaDetalles",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "AdelantosSugerido",
                table: "PlanillaDetalles",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "DescuentoAdelantos",
                table: "PlanillaDetalles",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "MovimientoAdelantoId",
                table: "PlanillaDetalles",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AdelantosEmpleado",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    EmpleadoId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    DescontarDesde = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CuotaSemanal = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    MontoDescontado = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    MovimientoCuentaId = table.Column<int>(type: "int", nullable: true),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdelantosEmpleado", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdelantosEmpleado_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AdelantosEmpleado_Empleados_EmpleadoId",
                        column: x => x.EmpleadoId,
                        principalTable: "Empleados",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AdelantosEmpleado_MovimientosCuenta_MovimientoCuentaId",
                        column: x => x.MovimientoCuentaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AdelantosEmpleado_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "PlanillaAdelantos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    PlanillaDetalleId = table.Column<int>(type: "int", nullable: false),
                    AdelantoEmpleadoId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanillaAdelantos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanillaAdelantos_AdelantosEmpleado_AdelantoEmpleadoId",
                        column: x => x.AdelantoEmpleadoId,
                        principalTable: "AdelantosEmpleado",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanillaAdelantos_PlanillaDetalles_PlanillaDetalleId",
                        column: x => x.PlanillaDetalleId,
                        principalTable: "PlanillaDetalles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDetalles_MovimientoAdelantoId",
                table: "PlanillaDetalles",
                column: "MovimientoAdelantoId");

            migrationBuilder.CreateIndex(
                name: "IX_AdelantosEmpleado_CuentaFinancieraId",
                table: "AdelantosEmpleado",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_AdelantosEmpleado_EmpleadoId_Estado",
                table: "AdelantosEmpleado",
                columns: new[] { "EmpleadoId", "Estado" });

            migrationBuilder.CreateIndex(
                name: "IX_AdelantosEmpleado_MovimientoCuentaId",
                table: "AdelantosEmpleado",
                column: "MovimientoCuentaId");

            migrationBuilder.CreateIndex(
                name: "IX_AdelantosEmpleado_UsuarioId",
                table: "AdelantosEmpleado",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaAdelantos_AdelantoEmpleadoId",
                table: "PlanillaAdelantos",
                column: "AdelantoEmpleadoId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaAdelantos_PlanillaDetalleId",
                table: "PlanillaAdelantos",
                column: "PlanillaDetalleId");

            migrationBuilder.AddForeignKey(
                name: "FK_PlanillaDetalles_MovimientosCuenta_MovimientoAdelantoId",
                table: "PlanillaDetalles",
                column: "MovimientoAdelantoId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PlanillaDetalles_MovimientosCuenta_MovimientoAdelantoId",
                table: "PlanillaDetalles");

            migrationBuilder.DropTable(
                name: "PlanillaAdelantos");

            migrationBuilder.DropTable(
                name: "AdelantosEmpleado");

            migrationBuilder.DropIndex(
                name: "IX_PlanillaDetalles_MovimientoAdelantoId",
                table: "PlanillaDetalles");

            migrationBuilder.DropColumn(
                name: "AdelantosManual",
                table: "PlanillaDetalles");

            migrationBuilder.DropColumn(
                name: "AdelantosSaldo",
                table: "PlanillaDetalles");

            migrationBuilder.DropColumn(
                name: "AdelantosSugerido",
                table: "PlanillaDetalles");

            migrationBuilder.DropColumn(
                name: "DescuentoAdelantos",
                table: "PlanillaDetalles");

            migrationBuilder.DropColumn(
                name: "MovimientoAdelantoId",
                table: "PlanillaDetalles");
        }
    }
}
