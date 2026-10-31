using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class FacturacionDeLaEmpresa : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CertificadoTitular",
                table: "Empresas",
                type: "varchar(250)",
                maxLength: 250,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "CertificadoVenceEl",
                table: "Empresas",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ClaveSol",
                table: "Empresas",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<bool>(
                name: "ModoPrueba",
                table: "Empresas",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<string>(
                name: "Ubigeo",
                table: "Empresas",
                type: "varchar(6)",
                maxLength: 6,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "UsuarioSol",
                table: "Empresas",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CertificadoTitular",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "CertificadoVenceEl",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "ClaveSol",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "ModoPrueba",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "Ubigeo",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "UsuarioSol",
                table: "Empresas");
        }
    }
}
