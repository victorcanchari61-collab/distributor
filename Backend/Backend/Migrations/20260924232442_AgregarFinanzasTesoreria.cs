using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class AgregarFinanzasTesoreria : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Banco",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "Cci",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "NumeroCuenta",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "Titular",
                table: "MetodosPago");

            migrationBuilder.AddColumn<int>(
                name: "CuentaFinancieraId",
                table: "MetodosPago",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MontoApertura",
                table: "ArqueoCaja",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "MovimientoAperturaId",
                table: "ArqueoCaja",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MovimientoCierreId",
                table: "ArqueoCaja",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CuentasFinancieras",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Naturaleza = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Banco = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    NumeroCuenta = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Cci = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Titular = table.Column<string>(type: "varchar(120)", maxLength: 120, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    SaldoActual = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CuentasFinancieras", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ConciliacionesBancarias",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    SaldoExtracto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    SaldoContable = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConciliacionesBancarias", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConciliacionesBancarias_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ConciliacionesBancarias_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "GastosRecurrentes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    MotivoGastoId = table.Column<int>(type: "int", nullable: false),
                    MontoEstimado = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    DiaVencimiento = table.Column<int>(type: "int", nullable: false),
                    CuentaFinancieraSugeridaId = table.Column<int>(type: "int", nullable: true),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GastosRecurrentes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GastosRecurrentes_CuentasFinancieras_CuentaFinancieraSugerid~",
                        column: x => x.CuentaFinancieraSugeridaId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_GastosRecurrentes_MotivosGasto_MotivoGastoId",
                        column: x => x.MotivoGastoId,
                        principalTable: "MotivosGasto",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MovimientosCuenta",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    Tipo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    SaldoResultante = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    DocumentoOrigen = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    OrigenId = table.Column<int>(type: "int", nullable: true),
                    MovimientoOrigenId = table.Column<int>(type: "int", nullable: true),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MovimientosCuenta", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MovimientosCuenta_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosCuenta_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MovimientosOperativos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    Tipo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    MotivoGastoId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    GastoRecurrenteId = table.Column<int>(type: "int", nullable: true),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    Anulado = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    MovimientoCuentaId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MovimientosOperativos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MovimientosOperativos_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosOperativos_GastosRecurrentes_GastoRecurrenteId",
                        column: x => x.GastoRecurrenteId,
                        principalTable: "GastosRecurrentes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosOperativos_MotivosGasto_MotivoGastoId",
                        column: x => x.MotivoGastoId,
                        principalTable: "MotivosGasto",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosOperativos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "CuentasFinancieras",
                columns: new[] { "Id", "Activo", "Banco", "Cci", "FechaCreacion", "Naturaleza", "Nombre", "NumeroCuenta", "SaldoActual", "Titular" },
                values: new object[] { 1, true, null, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "CAJA", "Caja General", null, 0m, null });

            migrationBuilder.UpdateData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 1,
                column: "CuentaFinancieraId",
                value: null);

            migrationBuilder.CreateIndex(
                name: "IX_MetodosPago_CuentaFinancieraId",
                table: "MetodosPago",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoAperturaId",
                table: "ArqueoCaja",
                column: "MovimientoAperturaId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoCierreId",
                table: "ArqueoCaja",
                column: "MovimientoCierreId");

            migrationBuilder.CreateIndex(
                name: "IX_ConciliacionesBancarias_CuentaFinancieraId",
                table: "ConciliacionesBancarias",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_ConciliacionesBancarias_UsuarioId",
                table: "ConciliacionesBancarias",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_CuentasFinancieras_Nombre",
                table: "CuentasFinancieras",
                column: "Nombre",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GastosRecurrentes_CuentaFinancieraSugeridaId",
                table: "GastosRecurrentes",
                column: "CuentaFinancieraSugeridaId");

            migrationBuilder.CreateIndex(
                name: "IX_GastosRecurrentes_MotivoGastoId",
                table: "GastosRecurrentes",
                column: "MotivoGastoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosCuenta_CuentaFinancieraId_Fecha",
                table: "MovimientosCuenta",
                columns: new[] { "CuentaFinancieraId", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosCuenta_UsuarioId",
                table: "MovimientosCuenta",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosOperativos_CuentaFinancieraId",
                table: "MovimientosOperativos",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosOperativos_GastoRecurrenteId",
                table: "MovimientosOperativos",
                column: "GastoRecurrenteId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosOperativos_MotivoGastoId",
                table: "MovimientosOperativos",
                column: "MotivoGastoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosOperativos_UsuarioId",
                table: "MovimientosOperativos",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoAperturaId",
                table: "ArqueoCaja",
                column: "MovimientoAperturaId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoCierreId",
                table: "ArqueoCaja",
                column: "MovimientoCierreId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_MetodosPago_CuentasFinancieras_CuentaFinancieraId",
                table: "MetodosPago",
                column: "CuentaFinancieraId",
                principalTable: "CuentasFinancieras",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoAperturaId",
                table: "ArqueoCaja");

            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoCierreId",
                table: "ArqueoCaja");

            migrationBuilder.DropForeignKey(
                name: "FK_MetodosPago_CuentasFinancieras_CuentaFinancieraId",
                table: "MetodosPago");

            migrationBuilder.DropTable(
                name: "ConciliacionesBancarias");

            migrationBuilder.DropTable(
                name: "MovimientosCuenta");

            migrationBuilder.DropTable(
                name: "MovimientosOperativos");

            migrationBuilder.DropTable(
                name: "GastosRecurrentes");

            migrationBuilder.DropTable(
                name: "CuentasFinancieras");

            migrationBuilder.DropIndex(
                name: "IX_MetodosPago_CuentaFinancieraId",
                table: "MetodosPago");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_MovimientoAperturaId",
                table: "ArqueoCaja");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_MovimientoCierreId",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "CuentaFinancieraId",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "MontoApertura",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "MovimientoAperturaId",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "MovimientoCierreId",
                table: "ArqueoCaja");

            migrationBuilder.AddColumn<string>(
                name: "Banco",
                table: "MetodosPago",
                type: "varchar(60)",
                maxLength: 60,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Cci",
                table: "MetodosPago",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "NumeroCuenta",
                table: "MetodosPago",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Titular",
                table: "MetodosPago",
                type: "varchar(120)",
                maxLength: 120,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.UpdateData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 1,
                columns: new[] { "Banco", "Cci", "NumeroCuenta", "Titular" },
                values: new object[] { null, null, null, null });
        }
    }
}
