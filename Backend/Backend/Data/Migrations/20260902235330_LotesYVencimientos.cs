using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class LotesYVencimientos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "FechaVencimiento",
                table: "CapasCosto",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Lote",
                table: "CapasCosto",
                type: "varchar(40)",
                maxLength: 40,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_CapasCosto_FechaVencimiento",
                table: "CapasCosto",
                column: "FechaVencimiento");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_CapasCosto_FechaVencimiento",
                table: "CapasCosto");

            migrationBuilder.DropColumn(
                name: "FechaVencimiento",
                table: "CapasCosto");

            migrationBuilder.DropColumn(
                name: "Lote",
                table: "CapasCosto");
        }
    }
}
