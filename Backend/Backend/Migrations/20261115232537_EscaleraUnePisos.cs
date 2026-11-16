using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// La escalera une pisos: HastaPisoId dice a qué piso llega, y ocupa el mismo lugar en todos los que cruza.
    /// </summary>
    public partial class EscaleraUnePisos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "HastaPisoId",
                table: "ElementosPlano",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ElementosPlano_HastaPisoId",
                table: "ElementosPlano",
                column: "HastaPisoId");

            migrationBuilder.AddForeignKey(
                name: "FK_ElementosPlano_UbicacionesAlmacen_HastaPisoId",
                table: "ElementosPlano",
                column: "HastaPisoId",
                principalTable: "UbicacionesAlmacen",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            // Las escaleras que ya estaban dibujadas (de un solo piso) se unen al piso de arriba o, si no hay, al de
            // abajo. Solo se miran los pisos con código P y número (P1, P2...), que son los que tienen orden.
            migrationBuilder.Sql(@"
                UPDATE ElementosPlano e
                SET e.HastaPisoId = (
                    SELECT u.Id FROM UbicacionesAlmacen u
                    WHERE u.AlmacenId = e.AlmacenId AND u.PadreId IS NULL AND u.Tipo = 'PISO' AND u.Id <> e.PisoId
                      AND u.Codigo REGEXP '^[Pp][0-9]+$'
                    ORDER BY
                      CASE WHEN CAST(SUBSTRING(u.Codigo, 2) AS UNSIGNED) >
                                (SELECT CAST(SUBSTRING(o.Codigo, 2) AS UNSIGNED) FROM UbicacionesAlmacen o WHERE o.Id = e.PisoId)
                           THEN 0 ELSE 1 END,
                      CASE WHEN CAST(SUBSTRING(u.Codigo, 2) AS UNSIGNED) >
                                (SELECT CAST(SUBSTRING(o.Codigo, 2) AS UNSIGNED) FROM UbicacionesAlmacen o WHERE o.Id = e.PisoId)
                           THEN CAST(SUBSTRING(u.Codigo, 2) AS SIGNED) ELSE -CAST(SUBSTRING(u.Codigo, 2) AS SIGNED) END
                    LIMIT 1)
                WHERE e.Tipo = 'ESCALERA' AND e.HastaPisoId IS NULL AND e.PisoId IS NOT NULL
                  AND (SELECT o.Codigo FROM UbicacionesAlmacen o WHERE o.Id = e.PisoId) REGEXP '^[Pp][0-9]+$';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ElementosPlano_UbicacionesAlmacen_HastaPisoId",
                table: "ElementosPlano");

            migrationBuilder.DropIndex(
                name: "IX_ElementosPlano_HastaPisoId",
                table: "ElementosPlano");

            migrationBuilder.DropColumn(
                name: "HastaPisoId",
                table: "ElementosPlano");
        }
    }
}
