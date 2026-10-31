using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class WhatsAppComprobantes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "WhatsAppAutomatico",
                table: "Empresas",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "WhatsAppPlantilla",
                table: "Empresas",
                type: "varchar(1000)",
                maxLength: 1000,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "TokenPublico",
                table: "ComprobantesElectronicos",
                type: "varchar(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "WhatsAppEnviadoEn",
                table: "ComprobantesElectronicos",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WhatsAppError",
                table: "ComprobantesElectronicos",
                type: "varchar(300)",
                maxLength: 300,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "WhatsAppEstado",
                table: "ComprobantesElectronicos",
                type: "varchar(12)",
                maxLength: 12,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "WhatsAppTelefono",
                table: "ComprobantesElectronicos",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            // Los comprobantes que ya existen reciben su token (uno distinto por fila) antes de volverlo único.
            migrationBuilder.Sql("UPDATE ComprobantesElectronicos SET TokenPublico = REPLACE(UUID(), '-', '') WHERE TokenPublico = '';");

            migrationBuilder.CreateIndex(
                name: "IX_ComprobantesElectronicos_TokenPublico",
                table: "ComprobantesElectronicos",
                column: "TokenPublico",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ComprobantesElectronicos_TokenPublico",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "WhatsAppAutomatico",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "WhatsAppPlantilla",
                table: "Empresas");

            migrationBuilder.DropColumn(
                name: "TokenPublico",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "WhatsAppEnviadoEn",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "WhatsAppError",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "WhatsAppEstado",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "WhatsAppTelefono",
                table: "ComprobantesElectronicos");
        }
    }
}
