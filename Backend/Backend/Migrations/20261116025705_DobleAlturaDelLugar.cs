using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// Doble altura de un lugar: PlanoHastaPisoId es el piso de arriba hasta donde está abierto, sin suelo encima.
    /// </summary>
    public partial class DobleAlturaDelLugar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PlanoHastaPisoId",
                table: "UbicacionesAlmacen",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_UbicacionesAlmacen_PlanoHastaPisoId",
                table: "UbicacionesAlmacen",
                column: "PlanoHastaPisoId");

            migrationBuilder.AddForeignKey(
                name: "FK_UbicacionesAlmacen_UbicacionesAlmacen_PlanoHastaPisoId",
                table: "UbicacionesAlmacen",
                column: "PlanoHastaPisoId",
                principalTable: "UbicacionesAlmacen",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_UbicacionesAlmacen_UbicacionesAlmacen_PlanoHastaPisoId",
                table: "UbicacionesAlmacen");

            migrationBuilder.DropIndex(
                name: "IX_UbicacionesAlmacen_PlanoHastaPisoId",
                table: "UbicacionesAlmacen");

            migrationBuilder.DropColumn(
                name: "PlanoHastaPisoId",
                table: "UbicacionesAlmacen");
        }
    }
}
