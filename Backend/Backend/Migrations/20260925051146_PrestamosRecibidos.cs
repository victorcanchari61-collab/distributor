using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class PrestamosRecibidos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Financiamientos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Acreedor = table.Column<string>(type: "varchar(120)", maxLength: 120, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    MontoRecibido = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    TotalADevolver = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    MovimientoCuentaId = table.Column<int>(type: "int", nullable: true),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Financiamientos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Financiamientos_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Financiamientos_MovimientosCuenta_MovimientoCuentaId",
                        column: x => x.MovimientoCuentaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Financiamientos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "PagosFinanciamiento",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    FinanciamientoId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CuentaFinancieraId = table.Column<int>(type: "int", nullable: false),
                    MovimientoCuentaId = table.Column<int>(type: "int", nullable: true),
                    Anulado = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PagosFinanciamiento", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PagosFinanciamiento_CuentasFinancieras_CuentaFinancieraId",
                        column: x => x.CuentaFinancieraId,
                        principalTable: "CuentasFinancieras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PagosFinanciamiento_Financiamientos_FinanciamientoId",
                        column: x => x.FinanciamientoId,
                        principalTable: "Financiamientos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PagosFinanciamiento_MovimientosCuenta_MovimientoCuentaId",
                        column: x => x.MovimientoCuentaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PagosFinanciamiento_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Financiamientos_CuentaFinancieraId",
                table: "Financiamientos",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_Financiamientos_MovimientoCuentaId",
                table: "Financiamientos",
                column: "MovimientoCuentaId");

            migrationBuilder.CreateIndex(
                name: "IX_Financiamientos_UsuarioId",
                table: "Financiamientos",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_PagosFinanciamiento_CuentaFinancieraId",
                table: "PagosFinanciamiento",
                column: "CuentaFinancieraId");

            migrationBuilder.CreateIndex(
                name: "IX_PagosFinanciamiento_FinanciamientoId",
                table: "PagosFinanciamiento",
                column: "FinanciamientoId");

            migrationBuilder.CreateIndex(
                name: "IX_PagosFinanciamiento_MovimientoCuentaId",
                table: "PagosFinanciamiento",
                column: "MovimientoCuentaId");

            migrationBuilder.CreateIndex(
                name: "IX_PagosFinanciamiento_UsuarioId",
                table: "PagosFinanciamiento",
                column: "UsuarioId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PagosFinanciamiento");

            migrationBuilder.DropTable(
                name: "Financiamientos");
        }
    }
}
