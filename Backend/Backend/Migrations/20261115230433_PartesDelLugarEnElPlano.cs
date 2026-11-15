using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// Las partes extra de un lugar en el plano (un cuarto en forma de L que rodea la escalera): una lista de
    /// rectángulos en JSON. Nula en los que ya existían: siguen siendo un solo rectángulo.
    /// </summary>
    public partial class PartesDelLugarEnElPlano : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PlanoPartes",
                table: "UbicacionesAlmacen",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PlanoPartes",
                table: "UbicacionesAlmacen");
        }
    }
}
