using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class DevolucionesAProveedor : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Quien maneja las compras maneja también lo que se le devuelve al proveedor: mismas acciones que en
            // Mis compras (ver, crear, anular, cobrar, exportar).
            migrationBuilder.Sql(@"
                INSERT IGNORE INTO RolPermisos (RolId, Submodulo, Accion)
                SELECT rp.RolId, 'compras.devoluciones', rp.Accion FROM RolPermisos rp
                WHERE rp.Submodulo = 'compras.compras' AND rp.Accion IN ('ver', 'crear', 'anular', 'cobrar', 'exportar');");
            migrationBuilder.AlterColumn<int>(
                name: "MetodoPagoId",
                table: "CompraPago",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<bool>(
                name: "SaldoFavor",
                table: "CompraPago",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "DevolucionesProveedor",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Numero = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CompraId = table.Column<int>(type: "int", nullable: false),
                    ProveedorId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Estado = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Motivo = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AlmacenId = table.Column<int>(type: "int", nullable: true),
                    DocumentoInventarioId = table.Column<int>(type: "int", nullable: true),
                    FechaReposicion = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    SerieNotaCredito = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    NumeroNotaCredito = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    MontoDescuento = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    SaldoFavorGenerado = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DevolucionesProveedor", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DevolucionesProveedor_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DevolucionesProveedor_Compras_CompraId",
                        column: x => x.CompraId,
                        principalTable: "Compras",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DevolucionesProveedor_DocumentosInventario_DocumentoInventar~",
                        column: x => x.DocumentoInventarioId,
                        principalTable: "DocumentosInventario",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DevolucionesProveedor_Proveedores_ProveedorId",
                        column: x => x.ProveedorId,
                        principalTable: "Proveedores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DevolucionesProveedor_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "DevolucionProveedorDetalles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    DevolucionProveedorId = table.Column<int>(type: "int", nullable: false),
                    CompraDetalleId = table.Column<int>(type: "int", nullable: false),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CostoUnitario = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Origen = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Resolucion = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CantidadPresentacionDescontada = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DevolucionProveedorDetalles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DevolucionProveedorDetalles_CompraDetalle_CompraDetalleId",
                        column: x => x.CompraDetalleId,
                        principalTable: "CompraDetalle",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DevolucionProveedorDetalles_DevolucionesProveedor_Devolucion~",
                        column: x => x.DevolucionProveedorId,
                        principalTable: "DevolucionesProveedor",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DevolucionProveedorDetalles_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MovimientosSaldoProveedor",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProveedorId = table.Column<int>(type: "int", nullable: false),
                    Tipo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Monto = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    DevolucionProveedorId = table.Column<int>(type: "int", nullable: true),
                    CompraPagoId = table.Column<int>(type: "int", nullable: true),
                    MetodoPagoId = table.Column<int>(type: "int", nullable: true),
                    MovimientoCuentaId = table.Column<int>(type: "int", nullable: true),
                    Anulado = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MovimientosSaldoProveedor", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MovimientosSaldoProveedor_CompraPago_CompraPagoId",
                        column: x => x.CompraPagoId,
                        principalTable: "CompraPago",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosSaldoProveedor_DevolucionesProveedor_DevolucionPr~",
                        column: x => x.DevolucionProveedorId,
                        principalTable: "DevolucionesProveedor",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosSaldoProveedor_MetodosPago_MetodoPagoId",
                        column: x => x.MetodoPagoId,
                        principalTable: "MetodosPago",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosSaldoProveedor_MovimientosCuenta_MovimientoCuenta~",
                        column: x => x.MovimientoCuentaId,
                        principalTable: "MovimientosCuenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosSaldoProveedor_Proveedores_ProveedorId",
                        column: x => x.ProveedorId,
                        principalTable: "Proveedores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MovimientosSaldoProveedor_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_AlmacenId",
                table: "DevolucionesProveedor",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_CompraId",
                table: "DevolucionesProveedor",
                column: "CompraId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_DocumentoInventarioId",
                table: "DevolucionesProveedor",
                column: "DocumentoInventarioId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_Estado",
                table: "DevolucionesProveedor",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_Fecha",
                table: "DevolucionesProveedor",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_Numero",
                table: "DevolucionesProveedor",
                column: "Numero",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_ProveedorId",
                table: "DevolucionesProveedor",
                column: "ProveedorId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionesProveedor_UsuarioId",
                table: "DevolucionesProveedor",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionProveedorDetalles_CompraDetalleId",
                table: "DevolucionProveedorDetalles",
                column: "CompraDetalleId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionProveedorDetalles_DevolucionProveedorId",
                table: "DevolucionProveedorDetalles",
                column: "DevolucionProveedorId");

            migrationBuilder.CreateIndex(
                name: "IX_DevolucionProveedorDetalles_ProductoId",
                table: "DevolucionProveedorDetalles",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosSaldoProveedor_CompraPagoId",
                table: "MovimientosSaldoProveedor",
                column: "CompraPagoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosSaldoProveedor_DevolucionProveedorId",
                table: "MovimientosSaldoProveedor",
                column: "DevolucionProveedorId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosSaldoProveedor_MetodoPagoId",
                table: "MovimientosSaldoProveedor",
                column: "MetodoPagoId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosSaldoProveedor_MovimientoCuentaId",
                table: "MovimientosSaldoProveedor",
                column: "MovimientoCuentaId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosSaldoProveedor_ProveedorId_Fecha",
                table: "MovimientosSaldoProveedor",
                columns: new[] { "ProveedorId", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosSaldoProveedor_UsuarioId",
                table: "MovimientosSaldoProveedor",
                column: "UsuarioId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM RolPermisos WHERE Submodulo = 'compras.devoluciones';");
            migrationBuilder.DropTable(
                name: "DevolucionProveedorDetalles");

            migrationBuilder.DropTable(
                name: "MovimientosSaldoProveedor");

            migrationBuilder.DropTable(
                name: "DevolucionesProveedor");

            migrationBuilder.DropColumn(
                name: "SaldoFavor",
                table: "CompraPago");

            migrationBuilder.AlterColumn<int>(
                name: "MetodoPagoId",
                table: "CompraPago",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);
        }
    }
}
