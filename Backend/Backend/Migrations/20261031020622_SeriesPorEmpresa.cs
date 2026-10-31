using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// Las series de comprobantes pasan a ser de cada empresa (antes eran globales y nacían sembradas), y el permiso
    /// único "Comprobantes" se reparte en cuatro: facturas, boletas, notas de crédito y notas de débito.
    /// </summary>
    public partial class SeriesPorEmpresa : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Primero nulo: las series que ya existen se asignan a la empresa que opera (o a la primera).
            migrationBuilder.AddColumn<int>(
                name: "EmpresaId",
                table: "SeriesCpe",
                type: "int",
                nullable: true);

            migrationBuilder.Sql(@"
UPDATE SeriesCpe
SET EmpresaId = (SELECT Id FROM Empresas ORDER BY Activa DESC, Id LIMIT 1);");

            // Sin ninguna empresa no hay a quién darle las series sembradas: se vuelven a crear desde la empresa.
            migrationBuilder.Sql("DELETE FROM SeriesCpe WHERE EmpresaId IS NULL;");

            migrationBuilder.AlterColumn<int>(
                name: "EmpresaId",
                table: "SeriesCpe",
                type: "int",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_SeriesCpe_EmpresaId",
                table: "SeriesCpe",
                column: "EmpresaId");

            migrationBuilder.AddForeignKey(
                name: "FK_SeriesCpe_Empresas_EmpresaId",
                table: "SeriesCpe",
                column: "EmpresaId",
                principalTable: "Empresas",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            // Quien podía operar "Comprobantes" conserva la misma acción en los cuatro tipos.
            foreach (var nuevo in new[] { "fact.facturas", "fact.boletas", "fact.notascredito", "fact.notasdebito" })
            {
                migrationBuilder.Sql($@"
INSERT INTO RolPermisos (RolId, Submodulo, Accion)
SELECT RolId, '{nuevo}', Accion FROM RolPermisos WHERE Submodulo = 'fact.comprobantes'
  AND NOT EXISTS (SELECT 1 FROM RolPermisos x WHERE x.RolId = RolPermisos.RolId AND x.Submodulo = '{nuevo}' AND x.Accion = RolPermisos.Accion);");
            }

            migrationBuilder.Sql("DELETE FROM RolPermisos WHERE Submodulo = 'fact.comprobantes';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
INSERT INTO RolPermisos (RolId, Submodulo, Accion)
SELECT DISTINCT RolId, 'fact.comprobantes', Accion FROM RolPermisos
WHERE Submodulo IN ('fact.facturas', 'fact.boletas', 'fact.notascredito', 'fact.notasdebito');");
            migrationBuilder.Sql(
                "DELETE FROM RolPermisos WHERE Submodulo IN ('fact.facturas', 'fact.boletas', 'fact.notascredito', 'fact.notasdebito');");

            migrationBuilder.DropForeignKey(
                name: "FK_SeriesCpe_Empresas_EmpresaId",
                table: "SeriesCpe");

            migrationBuilder.DropIndex(
                name: "IX_SeriesCpe_EmpresaId",
                table: "SeriesCpe");

            migrationBuilder.DropColumn(
                name: "EmpresaId",
                table: "SeriesCpe");
        }
    }
}
