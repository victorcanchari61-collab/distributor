using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class AgregarUsuarioFechaCompraPago : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "Fecha",
                table: "CompraPago",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<int>(
                name: "UsuarioId",
                table: "CompraPago",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_CompraPago_UsuarioId_Fecha",
                table: "CompraPago",
                columns: new[] { "UsuarioId", "Fecha" });

            migrationBuilder.AddForeignKey(
                name: "FK_CompraPago_Usuarios_UsuarioId",
                table: "CompraPago",
                column: "UsuarioId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CompraPago_Usuarios_UsuarioId",
                table: "CompraPago");

            migrationBuilder.DropIndex(
                name: "IX_CompraPago_UsuarioId_Fecha",
                table: "CompraPago");

            migrationBuilder.DropColumn(
                name: "Fecha",
                table: "CompraPago");

            migrationBuilder.DropColumn(
                name: "UsuarioId",
                table: "CompraPago");
        }
    }
}
