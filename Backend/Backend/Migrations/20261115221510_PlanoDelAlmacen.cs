using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// El plano de cada piso: dónde está dibujado cada lugar (columnas Plano* de UbicacionesAlmacen) y los pasillos y
    /// escaleras (ElementosPlano). Además, el submódulo nuevo inv.plano: quien ya ve "Ubicación de productos" ve el
    /// plano, y quien la edita lo edita. Así nadie pierde lo que hacía al aparecer la pantalla.
    /// </summary>
    public partial class PlanoDelAlmacen : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PlanoAlto",
                table: "UbicacionesAlmacen",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PlanoAncho",
                table: "UbicacionesAlmacen",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PlanoX",
                table: "UbicacionesAlmacen",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PlanoY",
                table: "UbicacionesAlmacen",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ElementosPlano",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    PisoId = table.Column<int>(type: "int", nullable: true),
                    Tipo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    X = table.Column<int>(type: "int", nullable: false),
                    Y = table.Column<int>(type: "int", nullable: false),
                    Ancho = table.Column<int>(type: "int", nullable: false),
                    Alto = table.Column<int>(type: "int", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ElementosPlano", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ElementosPlano_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ElementosPlano_UbicacionesAlmacen_PisoId",
                        column: x => x.PisoId,
                        principalTable: "UbicacionesAlmacen",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_ElementosPlano_AlmacenId_PisoId",
                table: "ElementosPlano",
                columns: new[] { "AlmacenId", "PisoId" });

            migrationBuilder.CreateIndex(
                name: "IX_ElementosPlano_PisoId",
                table: "ElementosPlano",
                column: "PisoId");

            migrationBuilder.Sql(@"
                INSERT IGNORE INTO RolPermisos (RolId, Submodulo, Accion)
                SELECT rp.RolId, 'inv.plano', rp.Accion FROM RolPermisos rp
                WHERE rp.Submodulo = 'inv.ubicaciones' AND rp.Accion IN ('ver', 'editar');");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM RolPermisos WHERE Submodulo = 'inv.plano';");

            migrationBuilder.DropTable(
                name: "ElementosPlano");

            migrationBuilder.DropColumn(
                name: "PlanoAlto",
                table: "UbicacionesAlmacen");

            migrationBuilder.DropColumn(
                name: "PlanoAncho",
                table: "UbicacionesAlmacen");

            migrationBuilder.DropColumn(
                name: "PlanoX",
                table: "UbicacionesAlmacen");

            migrationBuilder.DropColumn(
                name: "PlanoY",
                table: "UbicacionesAlmacen");
        }
    }
}
