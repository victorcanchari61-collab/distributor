using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class CierresYPlanillaSemanal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "SueldoSemanal",
                table: "Empleados",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "Anulado",
                table: "CierresCaja",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "MovimientoAjusteId",
                table: "CierresCaja",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "DescuentosFaltante",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CierreCajaId = table.Column<int>(type: "int", nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    MontoAplicado = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DescuentosFaltante", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DescuentosFaltante_CierresCaja_CierreCajaId",
                        column: x => x.CierreCajaId,
                        principalTable: "CierresCaja",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DescuentosFaltante_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "PlanillasSemanales",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Desde = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Hasta = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: true),
                    FechaPago = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanillasSemanales", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanillasSemanales_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanillasSemanales_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "PlanillaDetalles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    PlanillaSemanalId = table.Column<int>(type: "int", nullable: false),
                    EmpleadoId = table.Column<int>(type: "int", nullable: false),
                    SueldoSemanal = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    DiasNoPagados = table.Column<int>(type: "int", nullable: false),
                    DescuentoInasistencias = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    ExtraFeriados = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Bonos = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    OtrosDescuentos = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    NotaAjuste = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DescuentoFaltantes = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    MovimientoOperativoId = table.Column<int>(type: "int", nullable: true),
                    MovimientoRecuperoId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanillaDetalles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanillaDetalles_Empleados_EmpleadoId",
                        column: x => x.EmpleadoId,
                        principalTable: "Empleados",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanillaDetalles_MovimientosCuenta_MovimientoRecuperoId",
                        column: x => x.MovimientoRecuperoId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanillaDetalles_MovimientosOperativos_MovimientoOperativoId",
                        column: x => x.MovimientoOperativoId,
                        principalTable: "MovimientosOperativos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanillaDetalles_PlanillasSemanales_PlanillaSemanalId",
                        column: x => x.PlanillaSemanalId,
                        principalTable: "PlanillasSemanales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "PlanillaDescuentos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    PlanillaDetalleId = table.Column<int>(type: "int", nullable: false),
                    DescuentoFaltanteId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanillaDescuentos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanillaDescuentos_DescuentosFaltante_DescuentoFaltanteId",
                        column: x => x.DescuentoFaltanteId,
                        principalTable: "DescuentosFaltante",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanillaDescuentos_PlanillaDetalles_PlanillaDetalleId",
                        column: x => x.PlanillaDetalleId,
                        principalTable: "PlanillaDetalles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_CierresCaja_MovimientoAjusteId",
                table: "CierresCaja",
                column: "MovimientoAjusteId");

            migrationBuilder.CreateIndex(
                name: "IX_DescuentosFaltante_CierreCajaId",
                table: "DescuentosFaltante",
                column: "CierreCajaId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DescuentosFaltante_UsuarioId_Estado",
                table: "DescuentosFaltante",
                columns: new[] { "UsuarioId", "Estado" });

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDescuentos_DescuentoFaltanteId",
                table: "PlanillaDescuentos",
                column: "DescuentoFaltanteId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDescuentos_PlanillaDetalleId",
                table: "PlanillaDescuentos",
                column: "PlanillaDetalleId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDetalles_EmpleadoId",
                table: "PlanillaDetalles",
                column: "EmpleadoId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDetalles_MovimientoOperativoId",
                table: "PlanillaDetalles",
                column: "MovimientoOperativoId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDetalles_MovimientoRecuperoId",
                table: "PlanillaDetalles",
                column: "MovimientoRecuperoId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillaDetalles_PlanillaSemanalId",
                table: "PlanillaDetalles",
                column: "PlanillaSemanalId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillasSemanales_CuentaFinancieraId",
                table: "PlanillasSemanales",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillasSemanales_Desde",
                table: "PlanillasSemanales",
                column: "Desde");

            migrationBuilder.CreateIndex(
                name: "IX_PlanillasSemanales_UsuarioId",
                table: "PlanillasSemanales",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_CierresCaja_MovimientosCuenta_MovimientoAjusteId",
                table: "CierresCaja",
                column: "MovimientoAjusteId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CierresCaja_MovimientosCuenta_MovimientoAjusteId",
                table: "CierresCaja");

            migrationBuilder.DropTable(
                name: "PlanillaDescuentos");

            migrationBuilder.DropTable(
                name: "DescuentosFaltante");

            migrationBuilder.DropTable(
                name: "PlanillaDetalles");

            migrationBuilder.DropTable(
                name: "PlanillasSemanales");

            migrationBuilder.DropIndex(
                name: "IX_CierresCaja_MovimientoAjusteId",
                table: "CierresCaja");

            migrationBuilder.DropColumn(
                name: "SueldoSemanal",
                table: "Empleados");

            migrationBuilder.DropColumn(
                name: "Anulado",
                table: "CierresCaja");

            migrationBuilder.DropColumn(
                name: "MovimientoAjusteId",
                table: "CierresCaja");
        }
    }
}
