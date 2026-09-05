using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class AgregarUsuarioFechaPagoVenta : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "Fecha",
                table: "PagoVenta",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<int>(
                name: "UsuarioId",
                table: "PagoVenta",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_PagoVenta_UsuarioId_Fecha",
                table: "PagoVenta",
                columns: new[] { "UsuarioId", "Fecha" });

            migrationBuilder.AddForeignKey(
                name: "FK_PagoVenta_Usuarios_UsuarioId",
                table: "PagoVenta",
                column: "UsuarioId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PagoVenta_Usuarios_UsuarioId",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_PagoVenta_UsuarioId_Fecha",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "Fecha",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "UsuarioId",
                table: "PagoVenta");
        }
    }
}
