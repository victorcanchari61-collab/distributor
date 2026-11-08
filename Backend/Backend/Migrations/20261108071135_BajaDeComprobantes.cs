using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class BajaDeComprobantes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "BajaCorrelativo",
                table: "ComprobantesElectronicos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BajaEstado",
                table: "ComprobantesElectronicos",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "BajaFecha",
                table: "ComprobantesElectronicos",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BajaMensaje",
                table: "ComprobantesElectronicos",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "BajaMotivo",
                table: "ComprobantesElectronicos",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "BajaTicket",
                table: "ComprobantesElectronicos",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BajaCorrelativo",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "BajaEstado",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "BajaFecha",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "BajaMensaje",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "BajaMotivo",
                table: "ComprobantesElectronicos");

            migrationBuilder.DropColumn(
                name: "BajaTicket",
                table: "ComprobantesElectronicos");
        }
    }
}
