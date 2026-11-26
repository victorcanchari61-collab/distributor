using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class PortalDeClientes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "CotizacionId",
                table: "Pedidos",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AccesosCliente",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ClienteId = table.Column<int>(type: "int", nullable: false),
                    Usuario = table.Column<string>(type: "varchar(40)", maxLength: 40, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PasswordHash = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    TokenHash = table.Column<string>(type: "varchar(64)", maxLength: 64, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    TokenTipo = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    TokenExpira = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    VersionSesion = table.Column<int>(type: "int", nullable: false),
                    FechaInvitacion = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    InvitadoPorId = table.Column<int>(type: "int", nullable: true),
                    FechaActivacion = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    UltimoIngreso = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccesosCliente", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AccesosCliente_Clientes_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Clientes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AccesosCliente_Usuarios_InvitadoPorId",
                        column: x => x.InvitadoPorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Cotizaciones",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Numero = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ClienteId = table.Column<int>(type: "int", nullable: false),
                    VendedorId = table.Column<int>(type: "int", nullable: true),
                    ListaPrecioId = table.Column<int>(type: "int", nullable: true),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Estado = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nota = table.Column<string>(type: "varchar(300)", maxLength: 300, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Total = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    FechaCierre = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    CerradaPorId = table.Column<int>(type: "int", nullable: true),
                    MotivoDescarte = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Cotizaciones", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Cotizaciones_Clientes_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Clientes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Cotizaciones_ListasPrecio_ListaPrecioId",
                        column: x => x.ListaPrecioId,
                        principalTable: "ListasPrecio",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_Cotizaciones_Usuarios_CerradaPorId",
                        column: x => x.CerradaPorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_Cotizaciones_Usuarios_VendedorId",
                        column: x => x.VendedorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "CotizacionDetalle",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CotizacionId = table.Column<int>(type: "int", nullable: false),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    PresentacionId = table.Column<int>(type: "int", nullable: false),
                    Cantidad = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    PrecioPresentacion = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Subtotal = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CotizacionDetalle", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CotizacionDetalle_Cotizaciones_CotizacionId",
                        column: x => x.CotizacionId,
                        principalTable: "Cotizaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CotizacionDetalle_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CotizacionDetalle_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_CotizacionId",
                table: "Pedidos",
                column: "CotizacionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AccesosCliente_ClienteId",
                table: "AccesosCliente",
                column: "ClienteId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AccesosCliente_InvitadoPorId",
                table: "AccesosCliente",
                column: "InvitadoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_AccesosCliente_TokenHash",
                table: "AccesosCliente",
                column: "TokenHash");

            migrationBuilder.CreateIndex(
                name: "IX_AccesosCliente_Usuario",
                table: "AccesosCliente",
                column: "Usuario",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CotizacionDetalle_CotizacionId",
                table: "CotizacionDetalle",
                column: "CotizacionId");

            migrationBuilder.CreateIndex(
                name: "IX_CotizacionDetalle_PresentacionId",
                table: "CotizacionDetalle",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_CotizacionDetalle_ProductoId",
                table: "CotizacionDetalle",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_Cotizaciones_CerradaPorId",
                table: "Cotizaciones",
                column: "CerradaPorId");

            migrationBuilder.CreateIndex(
                name: "IX_Cotizaciones_ClienteId",
                table: "Cotizaciones",
                column: "ClienteId");

            migrationBuilder.CreateIndex(
                name: "IX_Cotizaciones_Estado_Fecha",
                table: "Cotizaciones",
                columns: new[] { "Estado", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_Cotizaciones_ListaPrecioId",
                table: "Cotizaciones",
                column: "ListaPrecioId");

            migrationBuilder.CreateIndex(
                name: "IX_Cotizaciones_Numero",
                table: "Cotizaciones",
                column: "Numero",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Cotizaciones_VendedorId",
                table: "Cotizaciones",
                column: "VendedorId");

            migrationBuilder.AddForeignKey(
                name: "FK_Pedidos_Cotizaciones_CotizacionId",
                table: "Pedidos",
                column: "CotizacionId",
                principalTable: "Cotizaciones",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            // La bandeja de cotizaciones la ve quien ve pedidos, y la descarta quien puede anularlos: son los que
            // atienden a esos clientes. Después se ajusta por rol en Accesos, como cualquier otro permiso.
            migrationBuilder.Sql(@"
                INSERT IGNORE INTO RolPermisos (RolId, Submodulo, Accion)
                SELECT rp.RolId, 'fact.cotizaciones', CASE rp.Accion WHEN 'ver' THEN 'ver' ELSE 'anular' END
                FROM RolPermisos rp
                WHERE rp.Submodulo = 'fact.pedidos' AND rp.Accion IN ('ver', 'anular');");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM RolPermisos WHERE Submodulo = 'fact.cotizaciones';");

            migrationBuilder.DropForeignKey(
                name: "FK_Pedidos_Cotizaciones_CotizacionId",
                table: "Pedidos");

            migrationBuilder.DropTable(
                name: "AccesosCliente");

            migrationBuilder.DropTable(
                name: "CotizacionDetalle");

            migrationBuilder.DropTable(
                name: "Cotizaciones");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_CotizacionId",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "CotizacionId",
                table: "Pedidos");
        }
    }
}
