using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class NovedadesEntrega : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "MotivosNovedad",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    RegresaAlAlmacen = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MotivosNovedad", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "NovedadesEntrega",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Tipo = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PedidoId = table.Column<int>(type: "int", nullable: false),
                    PedidoDetalleId = table.Column<int>(type: "int", nullable: true),
                    NotaVentaId = table.Column<int>(type: "int", nullable: true),
                    DespachoId = table.Column<int>(type: "int", nullable: true),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    PresentacionId = table.Column<int>(type: "int", nullable: true),
                    CantidadPedida = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CantidadEntregada = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Importe = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    MotivoId = table.Column<int>(type: "int", nullable: false),
                    Observacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    Fecha = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Estado = table.Column<string>(type: "varchar(15)", maxLength: 15, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CantidadRegresada = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: true),
                    VerificadoPorId = table.Column<int>(type: "int", nullable: true),
                    VerificadoEn = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    ObservacionVerificacion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NovedadesEntrega", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_Despachos_DespachoId",
                        column: x => x.DespachoId,
                        principalTable: "Despachos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_MotivosNovedad_MotivoId",
                        column: x => x.MotivoId,
                        principalTable: "MotivosNovedad",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_NotasVenta_NotaVentaId",
                        column: x => x.NotaVentaId,
                        principalTable: "NotasVenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_Pedidos_PedidoId",
                        column: x => x.PedidoId,
                        principalTable: "Pedidos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_NovedadesEntrega_Usuarios_VerificadoPorId",
                        column: x => x.VerificadoPorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_MotivosNovedad_Nombre",
                table: "MotivosNovedad",
                column: "Nombre",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_DespachoId_Estado",
                table: "NovedadesEntrega",
                columns: new[] { "DespachoId", "Estado" });

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_MotivoId",
                table: "NovedadesEntrega",
                column: "MotivoId");

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_NotaVentaId",
                table: "NovedadesEntrega",
                column: "NotaVentaId");

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_PedidoId_Tipo",
                table: "NovedadesEntrega",
                columns: new[] { "PedidoId", "Tipo" });

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_PresentacionId",
                table: "NovedadesEntrega",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_ProductoId",
                table: "NovedadesEntrega",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_UsuarioId",
                table: "NovedadesEntrega",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_NovedadesEntrega_VerificadoPorId",
                table: "NovedadesEntrega",
                column: "VerificadoPorId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NovedadesEntrega");

            migrationBuilder.DropTable(
                name: "MotivosNovedad");
        }
    }
}
