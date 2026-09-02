using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class TransferenciasYPrestamos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Codigo",
                table: "MotivosMovimiento",
                type: "varchar(25)",
                maxLength: 25,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(20)",
                oldMaxLength: 20)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "AlmacenDestinoId",
                table: "DocumentosInventario",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Prestamos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Numero = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Tipo = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Contraparte = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Estado = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Prestamos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Prestamos_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Prestamos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "PrestamoDetalle",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    PrestamoId = table.Column<int>(type: "int", nullable: false),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    PresentacionId = table.Column<int>(type: "int", nullable: true),
                    CantidadPresentacion = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CantidadDevuelta = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    MovimientoId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrestamoDetalle", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PrestamoDetalle_MovimientosInventario_MovimientoId",
                        column: x => x.MovimientoId,
                        principalTable: "MovimientosInventario",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PrestamoDetalle_Prestamos_PrestamoId",
                        column: x => x.PrestamoId,
                        principalTable: "Prestamos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PrestamoDetalle_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PrestamoDetalle_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "MotivosMovimiento",
                columns: new[] { "Id", "Activo", "Codigo", "DelSistema", "FechaCreacion", "Nombre", "PideCosto", "Tipo" },
                values: new object[,]
                {
                    { 14, true, "PRESTAMO_DADO", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Préstamo dado", false, "SALIDA" },
                    { 15, true, "DEV_PRESTAMO_DADO", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Devolución de préstamo dado", true, "ENTRADA" },
                    { 16, true, "PRESTAMO_RECIBIDO", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Préstamo recibido", true, "ENTRADA" },
                    { 17, true, "DEV_PRESTAMO_RECIBIDO", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Devolución de préstamo recibido", false, "SALIDA" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_AlmacenDestinoId",
                table: "DocumentosInventario",
                column: "AlmacenDestinoId");

            migrationBuilder.CreateIndex(
                name: "IX_PrestamoDetalle_MovimientoId",
                table: "PrestamoDetalle",
                column: "MovimientoId");

            migrationBuilder.CreateIndex(
                name: "IX_PrestamoDetalle_PresentacionId",
                table: "PrestamoDetalle",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_PrestamoDetalle_PrestamoId",
                table: "PrestamoDetalle",
                column: "PrestamoId");

            migrationBuilder.CreateIndex(
                name: "IX_PrestamoDetalle_ProductoId",
                table: "PrestamoDetalle",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_Prestamos_AlmacenId",
                table: "Prestamos",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_Prestamos_Numero",
                table: "Prestamos",
                column: "Numero",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Prestamos_UsuarioId",
                table: "Prestamos",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_DocumentosInventario_Almacenes_AlmacenDestinoId",
                table: "DocumentosInventario",
                column: "AlmacenDestinoId",
                principalTable: "Almacenes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DocumentosInventario_Almacenes_AlmacenDestinoId",
                table: "DocumentosInventario");

            migrationBuilder.DropTable(
                name: "PrestamoDetalle");

            migrationBuilder.DropTable(
                name: "Prestamos");

            migrationBuilder.DropIndex(
                name: "IX_DocumentosInventario_AlmacenDestinoId",
                table: "DocumentosInventario");

            migrationBuilder.DeleteData(
                table: "MotivosMovimiento",
                keyColumn: "Id",
                keyValue: 14);

            migrationBuilder.DeleteData(
                table: "MotivosMovimiento",
                keyColumn: "Id",
                keyValue: 15);

            migrationBuilder.DeleteData(
                table: "MotivosMovimiento",
                keyColumn: "Id",
                keyValue: 16);

            migrationBuilder.DeleteData(
                table: "MotivosMovimiento",
                keyColumn: "Id",
                keyValue: 17);

            migrationBuilder.DropColumn(
                name: "AlmacenDestinoId",
                table: "DocumentosInventario");

            migrationBuilder.AlterColumn<string>(
                name: "Codigo",
                table: "MotivosMovimiento",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(25)",
                oldMaxLength: 25)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");
        }
    }
}
