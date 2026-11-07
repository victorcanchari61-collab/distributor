using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class SolicitudesCompra : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "SolicitudCompraId",
                table: "OrdenesCompra",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "SolicitudesCompra",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Numero = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Urgencia = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Estado = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    MotivoRechazo = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SolicitudesCompra", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SolicitudesCompra_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SolicitudesCompra_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "SolicitudCompraDetalle",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    SolicitudCompraId = table.Column<int>(type: "int", nullable: false),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    PresentacionId = table.Column<int>(type: "int", nullable: true),
                    CantidadPresentacion = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Nota = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SolicitudCompraDetalle", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SolicitudCompraDetalle_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SolicitudCompraDetalle_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SolicitudCompraDetalle_SolicitudesCompra_SolicitudCompraId",
                        column: x => x.SolicitudCompraId,
                        principalTable: "SolicitudesCompra",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_OrdenesCompra_SolicitudCompraId",
                table: "OrdenesCompra",
                column: "SolicitudCompraId");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudCompraDetalle_PresentacionId",
                table: "SolicitudCompraDetalle",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudCompraDetalle_ProductoId",
                table: "SolicitudCompraDetalle",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudCompraDetalle_SolicitudCompraId",
                table: "SolicitudCompraDetalle",
                column: "SolicitudCompraId");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudesCompra_AlmacenId",
                table: "SolicitudesCompra",
                column: "AlmacenId");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudesCompra_Estado",
                table: "SolicitudesCompra",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudesCompra_Fecha",
                table: "SolicitudesCompra",
                column: "Fecha");

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudesCompra_Numero",
                table: "SolicitudesCompra",
                column: "Numero",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SolicitudesCompra_UsuarioId",
                table: "SolicitudesCompra",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_OrdenesCompra_SolicitudesCompra_SolicitudCompraId",
                table: "OrdenesCompra",
                column: "SolicitudCompraId",
                principalTable: "SolicitudesCompra",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            // El rol Almacenero (sembrado) pide lo que hace falta comprar: ve, crea, corrige y anula SUS solicitudes
            // y nada más. Atenderlas (rechazar o hacer la orden de compra) es de quien compra: se da en Accesos.
            foreach (var accion in new[] { "ver", "crear", "editar", "anular" })
            {
                migrationBuilder.Sql($@"
                    INSERT INTO RolPermisos (RolId, Submodulo, Accion)
                    SELECT r.Id, 'compras.solicitudes', '{accion}' FROM Roles r
                    WHERE r.Nombre = 'Almacenero' AND r.DelSistema = 1
                      AND NOT EXISTS (SELECT 1 FROM RolPermisos p
                                      WHERE p.RolId = r.Id AND p.Submodulo = 'compras.solicitudes' AND p.Accion = '{accion}');");
            }

            migrationBuilder.Sql(@"
                INSERT INTO RolAlcances (RolId, Submodulo, Alcance)
                SELECT r.Id, 'compras.solicitudes', 'propios' FROM Roles r
                WHERE r.Nombre = 'Almacenero' AND r.DelSistema = 1
                ON DUPLICATE KEY UPDATE Alcance = 'propios';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM RolAlcances WHERE Submodulo = 'compras.solicitudes';");
            migrationBuilder.Sql("DELETE FROM RolPermisos WHERE Submodulo = 'compras.solicitudes';");

            migrationBuilder.DropForeignKey(
                name: "FK_OrdenesCompra_SolicitudesCompra_SolicitudCompraId",
                table: "OrdenesCompra");

            migrationBuilder.DropTable(
                name: "SolicitudCompraDetalle");

            migrationBuilder.DropTable(
                name: "SolicitudesCompra");

            migrationBuilder.DropIndex(
                name: "IX_OrdenesCompra_SolicitudCompraId",
                table: "OrdenesCompra");

            migrationBuilder.DropColumn(
                name: "SolicitudCompraId",
                table: "OrdenesCompra");
        }
    }
}
