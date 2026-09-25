using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class CategoriasDelSistema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "EsSistema",
                table: "MotivosGasto",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 1,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 2,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 3,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 4,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 5,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 6,
                columns: new[] { "Descripcion", "EsSistema" },
                values: new object[] { "Se registra sola al pagar la planilla semanal.", true });

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 7,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 8,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 9,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 10,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 11,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 12,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 13,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 14,
                column: "EsSistema",
                value: false);

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 15,
                column: "EsSistema",
                value: false);

            migrationBuilder.InsertData(
                table: "MotivosGasto",
                columns: new[] { "Id", "Activo", "Descripcion", "EsSistema", "FechaCreacion", "Nombre", "Origen", "Tipo" },
                values: new object[,]
                {
                    { 16, true, "Lo cobrado de las notas de venta.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Ventas", "OPERATIVO", "INGRESO" },
                    { 17, true, "Lo que sobra al cerrar una caja.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Sobrante de caja", "OPERATIVO", "INGRESO" },
                    { 18, true, "Faltante de caja descontado al trabajador en su planilla.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Recupero de faltante", "OPERATIVO", "INGRESO" },
                    { 19, true, "Se registra en Préstamos recibidos.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Préstamo recibido", "NO_OPERATIVO", "INGRESO" },
                    { 20, true, "Lo pagado a proveedores por las compras.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Compra de mercadería", "OPERATIVO", "EGRESO" },
                    { 21, true, "Lo que falta al cerrar una caja.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Faltante de caja", "OPERATIVO", "EGRESO" },
                    { 22, true, "Se registra en Préstamos recibidos.", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Pago de préstamo", "NO_OPERATIVO", "EGRESO" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 16);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 17);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 18);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 19);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 20);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 21);

            migrationBuilder.DeleteData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 22);

            migrationBuilder.DropColumn(
                name: "EsSistema",
                table: "MotivosGasto");

            migrationBuilder.UpdateData(
                table: "MotivosGasto",
                keyColumn: "Id",
                keyValue: 6,
                column: "Descripcion",
                value: null);
        }
    }
}
