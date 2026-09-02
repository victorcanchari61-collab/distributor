using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class InventarioMovimientos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Almacenes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Codigo = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Direccion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    EsPrincipal = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Almacenes", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MotivosMovimiento",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Codigo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Tipo = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DelSistema = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    PideCosto = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MotivosMovimiento", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "DocumentosInventario",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Numero = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Tipo = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    MotivoId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Estado = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    DocumentoAnuladoId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentosInventario", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentosInventario_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DocumentosInventario_DocumentosInventario_DocumentoAnuladoId",
                        column: x => x.DocumentoAnuladoId,
                        principalTable: "DocumentosInventario",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DocumentosInventario_MotivosMovimiento_MotivoId",
                        column: x => x.MotivoId,
                        principalTable: "MotivosMovimiento",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DocumentosInventario_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MovimientosInventario",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    DocumentoId = table.Column<int>(type: "int", nullable: false),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    MotivoId = table.Column<int>(type: "int", nullable: false),
                    Tipo = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PresentacionId = table.Column<int>(type: "int", nullable: true),
                    CantidadPresentacion = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CostoUnitario = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CostoTotal = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    MovimientoOrigenId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MovimientosInventario", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MovimientosInventario_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosInventario_DocumentosInventario_DocumentoId",
                        column: x => x.DocumentoId,
                        principalTable: "DocumentosInventario",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MovimientosInventario_MotivosMovimiento_MotivoId",
                        column: x => x.MotivoId,
                        principalTable: "MotivosMovimiento",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosInventario_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosInventario_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "CapasCosto",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    MovimientoId = table.Column<int>(type: "int", nullable: false),
                    CantidadInicial = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CantidadDisponible = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CostoUnitario = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Origen = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CapasCosto", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CapasCosto_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CapasCosto_MovimientosInventario_MovimientoId",
                        column: x => x.MovimientoId,
                        principalTable: "MovimientosInventario",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CapasCosto_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ConsumosCapa",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    MovimientoId = table.Column<int>(type: "int", nullable: false),
                    CapaId = table.Column<int>(type: "int", nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CostoUnitario = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConsumosCapa", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConsumosCapa_CapasCosto_CapaId",
                        column: x => x.CapaId,
                        principalTable: "CapasCosto",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ConsumosCapa_MovimientosInventario_MovimientoId",
                        column: x => x.MovimientoId,
                        principalTable: "MovimientosInventario",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "Almacenes",
                columns: new[] { "Id", "Activo", "Codigo", "Direccion", "EsPrincipal", "FechaCreacion", "Nombre" },
                values: new object[] { 1, true, "PRIN", null, true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Almacén principal" });

            migrationBuilder.InsertData(
                table: "MotivosMovimiento",
                columns: new[] { "Id", "Activo", "Codigo", "DelSistema", "FechaCreacion", "Nombre", "PideCosto", "Tipo" },
                values: new object[,]
                {
                    { 1, true, "CARGA_INICIAL", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Carga inicial", true, "ENTRADA" },
                    { 2, true, "COMPRA", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Recepción de compra", true, "ENTRADA" },
                    { 3, true, "VENTA", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Venta", false, "SALIDA" },
                    { 4, true, "VENTA_ANULADA", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Venta anulada", true, "ENTRADA" },
                    { 5, true, "COMPRA_ANULADA", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Compra anulada", false, "SALIDA" },
                    { 6, true, "DEV_PROVEEDOR", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Devolución a proveedor", false, "SALIDA" },
                    { 7, true, "TRANSF_SALIDA", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Transferencia — salida", false, "SALIDA" },
                    { 8, true, "TRANSF_INGRESO", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Transferencia — ingreso", true, "ENTRADA" },
                    { 9, true, "SOBRANTE", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Sobrante de conteo", true, "ENTRADA" },
                    { 10, true, "FALTANTE", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Faltante de conteo", false, "SALIDA" },
                    { 11, true, "MERMA", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Merma", false, "SALIDA" },
                    { 12, true, "ROTURA", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Rotura", false, "SALIDA" },
                    { 13, true, "VENCIMIENTO", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Vencimiento", false, "SALIDA" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Almacenes_Codigo",
                table: "Almacenes",
                column: "Codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CapasCosto_AlmacenId",
                table: "CapasCosto",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_CapasCosto_MovimientoId",
                table: "CapasCosto",
                column: "MovimientoId");

            migrationBuilder.CreateIndex(
                name: "IX_CapasCosto_ProductoId_AlmacenId_Fecha",
                table: "CapasCosto",
                columns: new[] { "ProductoId", "AlmacenId", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_ConsumosCapa_CapaId",
                table: "ConsumosCapa",
                column: "CapaId");

            migrationBuilder.CreateIndex(
                name: "IX_ConsumosCapa_MovimientoId",
                table: "ConsumosCapa",
                column: "MovimientoId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_AlmacenId",
                table: "DocumentosInventario",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_DocumentoAnuladoId",
                table: "DocumentosInventario",
                column: "DocumentoAnuladoId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_MotivoId",
                table: "DocumentosInventario",
                column: "MotivoId");

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_Numero",
                table: "DocumentosInventario",
                column: "Numero",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DocumentosInventario_UsuarioId",
                table: "DocumentosInventario",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_MotivosMovimiento_Codigo",
                table: "MotivosMovimiento",
                column: "Codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_AlmacenId",
                table: "MovimientosInventario",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_DocumentoId",
                table: "MovimientosInventario",
                column: "DocumentoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_MotivoId",
                table: "MovimientosInventario",
                column: "MotivoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_PresentacionId",
                table: "MovimientosInventario",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosInventario_ProductoId_AlmacenId_Fecha",
                table: "MovimientosInventario",
                columns: new[] { "ProductoId", "AlmacenId", "Fecha" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ConsumosCapa");

            migrationBuilder.DropTable(
                name: "CapasCosto");

            migrationBuilder.DropTable(
                name: "MovimientosInventario");

            migrationBuilder.DropTable(
                name: "DocumentosInventario");

            migrationBuilder.DropTable(
                name: "Almacenes");

            migrationBuilder.DropTable(
                name: "MotivosMovimiento");
        }
    }
}
