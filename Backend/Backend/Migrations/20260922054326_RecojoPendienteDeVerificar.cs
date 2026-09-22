using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class RecojoPendienteDeVerificar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Anulado",
                table: "RecojosVenta");

            migrationBuilder.AlterColumn<int>(
                name: "AlmacenId",
                table: "RecojosVenta",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<string>(
                name: "Estado",
                table: "RecojosVenta",
                type: "varchar(15)",
                maxLength: 15,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "VerificadoEn",
                table: "RecojosVenta",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "VerificadoPorId",
                table: "RecojosVenta",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_Estado",
                table: "RecojosVenta",
                column: "Estado");

            migrationBuilder.CreateIndex(
                name: "IX_RecojosVenta_VerificadoPorId",
                table: "RecojosVenta",
                column: "VerificadoPorId");

            migrationBuilder.AddForeignKey(
                name: "FK_RecojosVenta_Usuarios_VerificadoPorId",
                table: "RecojosVenta",
                column: "VerificadoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_RecojosVenta_Usuarios_VerificadoPorId",
                table: "RecojosVenta");

            migrationBuilder.DropIndex(
                name: "IX_RecojosVenta_Estado",
                table: "RecojosVenta");

            migrationBuilder.DropIndex(
                name: "IX_RecojosVenta_VerificadoPorId",
                table: "RecojosVenta");

            migrationBuilder.DropColumn(
                name: "Estado",
                table: "RecojosVenta");

            migrationBuilder.DropColumn(
                name: "VerificadoEn",
                table: "RecojosVenta");

            migrationBuilder.DropColumn(
                name: "VerificadoPorId",
                table: "RecojosVenta");

            migrationBuilder.AlterColumn<int>(
                name: "AlmacenId",
                table: "RecojosVenta",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "Anulado",
                table: "RecojosVenta",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);
        }
    }
}
