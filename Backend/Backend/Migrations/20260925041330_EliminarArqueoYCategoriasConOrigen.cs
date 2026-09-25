using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class EliminarArqueoYCategoriasConOrigen : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ArqueoGastos");

            migrationBuilder.DropTable(
                name: "ArqueoPagosDigitales");

            migrationBuilder.DropTable(
                name: "ArqueoCaja");

            migrationBuilder.AddColumn<string>(
                name: "Origen",
                table: "MotivosGasto",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Tipo",
                table: "MotivosGasto",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "CierresCaja",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    SaldoSistema = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Billetes = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Monedas = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CuentaDestinoId = table.Column<int>(type: "int", nullable: false),
                    MovimientoSalidaId = table.Column<int>(type: "int", nullable: true),
                    MovimientoEntradaId = table.Column<int>(type: "int", nullable: true),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CierresCaja", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CierresCaja_CuentasFinancieras_CuentaDestinoId",
                        column: x => x.CuentaDestinoId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CierresCaja_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CierresCaja_MovimientosCuenta_MovimientoEntradaId",
                        column: x => x.MovimientoEntradaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CierresCaja_MovimientosCuenta_MovimientoSalidaId",
                        column: x => x.MovimientoSalidaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CierresCaja_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 1,
                columns: new[] { "Origen", "Tipo" },
                values: new object[] { "OPERATIVO", "EGRESO" });

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 2,
                columns: new[] { "Origen", "Tipo" },
                values: new object[] { "OPERATIVO", "EGRESO" });

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 3,
                columns: new[] { "Origen", "Tipo" },
                values: new object[] { "OPERATIVO", "EGRESO" });

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 4,
                columns: new[] { "Origen", "Tipo" },
                values: new object[] { "OPERATIVO", "EGRESO" });

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 5,
                columns: new[] { "Origen", "Tipo" },
                values: new object[] { "OPERATIVO", "EGRESO" });

            migrationBuilder.InsertData(
                table: "MotivosGasto",
                columns: new[] { "Id", "Activo", "Descripcion", "FechaCreacion", "Nombre", "Origen", "Tipo" },
                values: new object[,]
                {
                    { 6, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Planilla", "OPERATIVO", "EGRESO" },
                    { 7, true, "Alquiler del local o almacén, luz, agua, internet.", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Alquiler y servicios", "OPERATIVO", "EGRESO" },
                    { 8, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Mantenimiento de vehículos", "OPERATIVO", "EGRESO" },
                    { 9, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Impuestos (SUNAT)", "OPERATIVO", "EGRESO" },
                    { 10, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Marketing y publicidad", "OPERATIVO", "EGRESO" },
                    { 11, true, "Lo que entra por el negocio sin ser una venta registrada.", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Otros ingresos del negocio", "OPERATIVO", "INGRESO" },
                    { 12, true, "Plata que pone el dueño o un socio.", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Aporte de capital", "NO_OPERATIVO", "INGRESO" },
                    { 13, true, "Venta de un vehículo, equipo o mueble del negocio.", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Venta de activo", "NO_OPERATIVO", "INGRESO" },
                    { 14, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Retiro del dueño", "NO_OPERATIVO", "EGRESO" },
                    { 15, true, "Vehículo, equipo o mueble: no es gasto del mes, es inversión.", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Compra de activo", "NO_OPERATIVO", "EGRESO" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_CierresCaja_CuentaDestinoId",
                table: "CierresCaja",
                column: "CuentaDestinoId");

            migrationBuilder.CreateIndex(
                name: "IX_CierresCaja_CuentaFinancieraId_Fecha",
                table: "CierresCaja",
                columns: new[] { "CuentaFinancieraId", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_CierresCaja_MovimientoEntradaId",
                table: "CierresCaja",
                column: "MovimientoEntradaId");

            migrationBuilder.CreateIndex(
                name: "IX_CierresCaja_MovimientoSalidaId",
                table: "CierresCaja",
                column: "MovimientoSalidaId");

            migrationBuilder.CreateIndex(
                name: "IX_CierresCaja_UsuarioId",
                table: "CierresCaja",
                column: "UsuarioId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CierresCaja");

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 9);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 10);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 11);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 12);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 13);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 14);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 15);

            migrationBuilder.DropColumn(
                name: "Origen",
                table: "MotivosGasto");

            migrationBuilder.DropColumn(
                name: "Tipo",
                table: "MotivosGasto");

            migrationBuilder.CreateTable(
                name: "ArqueoCaja",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    BancosSistema = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Billetes = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    EfectivoSistema = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    FaltanteSaldado = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    FechaSaldado = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    Monedas = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    MontoApertura = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    MovimientoAperturaDestinoId = table.Column<int>(type: "int", nullable: true),
                    MovimientoAperturaId = table.Column<int>(type: "int", nullable: true),
                    MovimientoCierreDestinoId = table.Column<int>(type: "int", nullable: true),
                    MovimientoCierreId = table.Column<int>(type: "int", nullable: true),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    RegistradoPorId = table.Column<int>(type: "int", nullable: true),
                    SaldoCajaAlCerrar = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ArqueoCaja", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoAperturaDestinoId",
                        column: x => x.MovimientoAperturaDestinoId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoAperturaId",
                        column: x => x.MovimientoAperturaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoCierreDestinoId",
                        column: x => x.MovimientoCierreDestinoId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoCierreId",
                        column: x => x.MovimientoCierreId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ArqueoCaja_Usuarios_RegistradoPorId",
                        column: x => x.RegistradoPorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ArqueoCaja_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ArqueoGastos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ArqueoCajaId = table.Column<int>(type: "int", nullable: false),
                    MotivoGastoId = table.Column<int>(type: "int", nullable: false),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ArqueoGastos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ArqueoGastos_ArqueoCaja_ArqueoCajaId",
                        column: x => x.ArqueoCajaId,
                        principalTable: "ArqueoCaja",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ArqueoGastos_MotivosGasto_MotivoGastoId",
                        column: x => x.MotivoGastoId,
                        principalTable: "MotivosGasto",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ArqueoPagosDigitales",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ArqueoCajaId = table.Column<int>(type: "int", nullable: false),
                    ClienteId = table.Column<int>(type: "int", nullable: true),
                    MetodoPagoId = table.Column<int>(type: "int", nullable: false),
                    PagoVentaId = table.Column<int>(type: "int", nullable: true),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    NumeroOperacion = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ArqueoPagosDigitales", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_ArqueoCaja_ArqueoCajaId",
                        column: x => x.ArqueoCajaId,
                        principalTable: "ArqueoCaja",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_Clientes_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Clientes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_MetodosPago_MetodoPagoId",
                        column: x => x.MetodoPagoId,
                        principalTable: "MetodosPago",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_PagoVenta_PagoVentaId",
                        column: x => x.PagoVentaId,
                        principalTable: "PagoVenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_Fecha_UsuarioId",
                table: "ArqueoCaja",
                columns: new[] { "Fecha", "UsuarioId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoAperturaDestinoId",
                table: "ArqueoCaja",
                column: "MovimientoAperturaDestinoId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoAperturaId",
                table: "ArqueoCaja",
                column: "MovimientoAperturaId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoCierreDestinoId",
                table: "ArqueoCaja",
                column: "MovimientoCierreDestinoId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoCierreId",
                table: "ArqueoCaja",
                column: "MovimientoCierreId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_RegistradoPorId",
                table: "ArqueoCaja",
                column: "RegistradoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_UsuarioId",
                table: "ArqueoCaja",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoGastos_ArqueoCajaId",
                table: "ArqueoGastos",
                column: "ArqueoCajaId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoGastos_MotivoGastoId",
                table: "ArqueoGastos",
                column: "MotivoGastoId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_ArqueoCajaId",
                table: "ArqueoPagosDigitales",
                column: "ArqueoCajaId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_ClienteId",
                table: "ArqueoPagosDigitales",
                column: "ClienteId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_MetodoPagoId",
                table: "ArqueoPagosDigitales",
                column: "MetodoPagoId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_PagoVentaId",
                table: "ArqueoPagosDigitales",
                column: "PagoVentaId");
        }
    }
}
