using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class AgregarCatalogoBancos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Banco",
                table: "CuentasFinancieras");

            migrationBuilder.AddColumn<int>(
                name: "BancoId",
                table: "CuentasFinancieras",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Bancos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Bancos", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.UpdateData(
                table: "CuentasFinancieras",
                keyColumn: "Id",
                keyValue: 1,
                column: "BancoId",
                value: null);

            migrationBuilder.CreateIndex(
                name: "IX_CuentasFinancieras_BancoId",
                table: "CuentasFinancieras",
                column: "BancoId");

            migrationBuilder.CreateIndex(
                name: "IX_Bancos_Nombre",
                table: "Bancos",
                column: "Nombre",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_CuentasFinancieras_Bancos_BancoId",
                table: "CuentasFinancieras",
                column: "BancoId",
                principalTable: "Bancos",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CuentasFinancieras_Bancos_BancoId",
                table: "CuentasFinancieras");

            migrationBuilder.DropTable(
                name: "Bancos");

            migrationBuilder.DropIndex(
                name: "IX_CuentasFinancieras_BancoId",
                table: "CuentasFinancieras");

            migrationBuilder.DropColumn(
                name: "BancoId",
                table: "CuentasFinancieras");

            migrationBuilder.AddColumn<string>(
                name: "Banco",
                table: "CuentasFinancieras",
                type: "varchar(60)",
                maxLength: 60,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.UpdateData(
                table: "CuentasFinancieras",
                keyColumn: "Id",
                keyValue: 1,
                column: "Banco",
                value: null);
        }
    }
}
