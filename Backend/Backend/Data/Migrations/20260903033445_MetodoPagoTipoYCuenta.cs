using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class MetodoPagoTipoYCuenta : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.AddColumn<string>(
                name: "Banco",
                table: "MetodosPago",
                type: "varchar(60)",
                maxLength: 60,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Cci",
                table: "MetodosPago",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "NumeroCuenta",
                table: "MetodosPago",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Tipo",
                table: "MetodosPago",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Titular",
                table: "MetodosPago",
                type: "varchar(120)",
                maxLength: 120,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.UpdateData(
                table: "MetodosPago",
                keyColumn: "Id",
                keyValue: 1,
                columns: new[] { "Banco", "Cci", "NumeroCuenta", "Tipo", "Titular" },
                values: new object[] { null, null, null, "EFECTIVO", null });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Banco",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "Cci",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "NumeroCuenta",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "Tipo",
                table: "MetodosPago");

            migrationBuilder.DropColumn(
                name: "Titular",
                table: "MetodosPago");

            migrationBuilder.InsertData(
                table: "MetodosPago",
                columns: new[] { "Id", "Activo", "Nombre" },
                values: new object[,]
                {
                    { 2, true, "Transferencia" },
                    { 3, true, "Depósito" },
                    { 4, true, "Tarjeta" },
                    { 5, true, "Cheque" }
                });
        }
    }
}
