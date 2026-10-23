using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// El rol Vendedor (Id 2, sembrado) ve sus propios cierres de caja y nada más: Ver con alcance
    /// "solo los suyos", sin Confirmar ni Anular. Quien vende no revisa ni deshace su propio cierre
    /// —anularlo borraría su faltante—; eso queda para quien administra la caja.
    /// </summary>
    public partial class VendedorVeSusCierres : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                INSERT INTO RolPermisos (RolId, Submodulo, Accion)
                SELECT 2, 'finanzas.cierres', 'ver' FROM DUAL
                WHERE EXISTS (SELECT 1 FROM Roles WHERE Id = 2)
                  AND NOT EXISTS (SELECT 1 FROM RolPermisos
                                  WHERE RolId = 2 AND Submodulo = 'finanzas.cierres' AND Accion = 'ver');");

            migrationBuilder.Sql(@"
                DELETE FROM RolPermisos
                WHERE RolId = 2 AND Submodulo = 'finanzas.cierres' AND Accion IN ('confirmar', 'anular');");

            migrationBuilder.Sql(@"
                INSERT INTO RolAlcances (RolId, Submodulo, Alcance)
                SELECT 2, 'finanzas.cierres', 'propios' FROM DUAL
                WHERE EXISTS (SELECT 1 FROM Roles WHERE Id = 2)
                ON DUPLICATE KEY UPDATE Alcance = 'propios';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Vuelve a "todos". Confirmar y Anular no se devuelven: si hacen falta, se dan en Accesos.
            migrationBuilder.Sql("DELETE FROM RolAlcances WHERE RolId = 2 AND Submodulo = 'finanzas.cierres';");
        }
    }
}
