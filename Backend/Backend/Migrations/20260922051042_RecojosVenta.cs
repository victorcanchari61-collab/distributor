using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class RecojosVenta : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "RecojoVentaId",
                table: "MovimientosInventario",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RecojoVentaId",
                table: "DocumentosInventario",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "RecojosVenta",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    NotaVentaId = table.Column<int>(type: "int", nullable: false),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    PresentacionId = table.Column<int>(type: "int", nullable: true),
                    CantidadPresentacion = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    PrecioUnitario = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Importe = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    MotivoId = table.Column<int>(type: "int", nullable: false),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    DocumentoInventarioId = table.Column<int>(type: "int", nullable: true),
                    Anulado = table.Column<bool>(type: "tinyint(1)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecojosVenta", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecojosVenta_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecojosVenta_MotivosNovedad_MotivoId",
                        column: x => x.MotivoId,
                        principalTable: "MotivosNovedad",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecojosVenta_NotasVenta_NotaVentaId",
                        column: x => x.NotaVentaId,
                        principalTable: "NotasVenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RecojosVenta_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecojosVenta_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecojosVenta_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_RecojoVentaId",
                table: "MovimientosInventario",
                column: "RecojoVentaId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_RecojoVentaId",
                table: "DocumentosInventario",
                column: "RecojoVentaId");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_AlmacenId",
                table: "RecojosVenta",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_Fecha",
                table: "RecojosVenta",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_MotivoId",
                table: "RecojosVenta",
                column: "MotivoId");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_NotaVentaId",
                table: "RecojosVenta",
                column: "NotaVentaId");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_PresentacionId",
                table: "RecojosVenta",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_ProductoId",
                table: "RecojosVenta",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_UsuarioId",
                table: "RecojosVenta",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_DocumentosInventario_RecojosVenta_RecojoVentaId",
                table: "DocumentosInventario",
                column: "RecojoVentaId",
                principalTable: "RecojosVenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_MovimientosInventario_RecojosVenta_RecojoVentaId",
                table: "MovimientosInventario",
                column: "RecojoVentaId",
                principalTable: "RecojosVenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DocumentosInventario_RecojosVenta_RecojoVentaId",
                table: "DocumentosInventario");

            migrationBuilder.DropForeignKey(
                name: "FK_MovimientosInventario_RecojosVenta_RecojoVentaId",
                table: "MovimientosInventario");

            migrationBuilder.DropTable(
                name: "RecojosVenta");

            migrationBuilder.DropIndex(
                name: "IX_MovimientosInventario_RecojoVentaId",
                table: "MovimientosInventario");

            migrationBuilder.DropIndex(
                name: "IX_DocumentosInventario_RecojoVentaId",
                table: "DocumentosInventario");

            migrationBuilder.DropColumn(
                name: "RecojoVentaId",
                table: "MovimientosInventario");

            migrationBuilder.DropColumn(
                name: "RecojoVentaId",
                table: "DocumentosInventario");
        }
    }
}
