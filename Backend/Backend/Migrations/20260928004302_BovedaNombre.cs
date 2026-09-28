using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class BovedaNombre : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "CuentasFinancieras",
                keyColumn: "Id",
                keyValue: 1,
                column: "Nombre",
                value: "Bóveda");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "CuentasFinancieras",
                keyColumn: "Id",
                keyValue: 1,
                column: "Nombre",
                value: "Caja General");
        }
    }
}
