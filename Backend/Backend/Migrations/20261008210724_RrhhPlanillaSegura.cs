using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class RrhhPlanillaSegura : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Antes del índice único: si ya hay dos marcas vigentes del mismo empleado y día, queda la
            // última y las demás se anulan (no se borran).
            migrationBuilder.Sql(@"
UPDATE Asistencias a
JOIN (SELECT EmpleadoId, Fecha, MAX(Id) AS Ultima
      FROM Asistencias WHERE Anulado = 0
      GROUP BY EmpleadoId, Fecha HAVING COUNT(*) > 1) d
  ON a.EmpleadoId = d.EmpleadoId AND a.Fecha = d.Fecha
SET a.Anulado = 1
WHERE a.Anulado = 0 AND a.Id <> d.Ultima;");

            // Igual con dos planillas vigentes de la misma semana: se queda la pagada (o la última) y
            // los borradores sobrantes se anulan.
            migrationBuilder.Sql(@"
UPDATE PlanillasSemanales p
JOIN (SELECT Desde, MAX(CASE WHEN Estado = 'PAGADA' THEN Id END) AS Pagada, MAX(Id) AS Ultima
      FROM PlanillasSemanales WHERE Estado <> 'ANULADA'
      GROUP BY Desde HAVING COUNT(*) > 1) d
  ON p.Desde = d.Desde
SET p.Estado = 'ANULADA'
WHERE p.Estado = 'BORRADOR' AND p.Id <> COALESCE(d.Pagada, d.Ultima);");

            migrationBuilder.AddColumn<int>(
                name: "DiasSinMarcar",
                table: "PlanillaDetalles",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "SemanaVigente",
                table: "PlanillasSemanales",
                type: "datetime(6)",
                nullable: true,
                computedColumnSql: "CASE WHEN `Estado` <> 'ANULADA' THEN `Desde` END",
                stored: true)
                .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.ComputedColumn);

            migrationBuilder.AddColumn<DateTime>(
                name: "FechaVigente",
                table: "Asistencias",
                type: "datetime(6)",
                nullable: true,
                computedColumnSql: "CASE WHEN `Anulado` = 0 THEN `Fecha` END",
                stored: true)
                .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.ComputedColumn);

            migrationBuilder.CreateIndex(
                name: "IX_PlanillasSemanales_SemanaVigente",
                table: "PlanillasSemanales",
                column: "SemanaVigente",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Asistencias_EmpleadoId_FechaVigente",
                table: "Asistencias",
                columns: new[] { "EmpleadoId", "FechaVigente" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PlanillasSemanales_SemanaVigente",
                table: "PlanillasSemanales");

            migrationBuilder.DropIndex(
                name: "IX_Asistencias_EmpleadoId_FechaVigente",
                table: "Asistencias");

            migrationBuilder.DropColumn(
                name: "SemanaVigente",
                table: "PlanillasSemanales");

            migrationBuilder.DropColumn(
                name: "FechaVigente",
                table: "Asistencias");

            migrationBuilder.DropColumn(
                name: "DiasSinMarcar",
                table: "PlanillaDetalles");
        }
    }
}
