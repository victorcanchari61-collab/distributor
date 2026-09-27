using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class CobrosDigitalesVerificados : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "EstadoVerificacion",
                table: "PagoVenta",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "NumeroOperacion",
                table: "PagoVenta",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ObservacionVerificacion",
                table: "PagoVenta",
                type: "varchar(250)",
                maxLength: 250,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "VerificadoEn",
                table: "PagoVenta",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "VerificadoPorId",
                table: "PagoVenta",
                type: "int",
                nullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "CierreCajaId",
                table: "DescuentosFaltante",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<int>(
                name: "PagoVentaId",
                table: "DescuentosFaltante",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_PagoVenta_EstadoVerificacion_Fecha",
                table: "PagoVenta",
                columns: new[] { "EstadoVerificacion", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_PagoVenta_NumeroOperacion",
                table: "PagoVenta",
                column: "NumeroOperacion");

            migrationBuilder.CreateIndex(
                name: "IX_PagoVenta_VerificadoPorId",
                table: "PagoVenta",
                column: "VerificadoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_DescuentosFaltante_PagoVentaId",
                table: "DescuentosFaltante",
                column: "PagoVentaId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_DescuentosFaltante_PagoVenta_PagoVentaId",
                table: "DescuentosFaltante",
                column: "PagoVentaId",
                principalTable: "PagoVenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PagoVenta_Usuarios_VerificadoPorId",
                table: "PagoVenta",
                column: "VerificadoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            // Los cobros digitales de antes quedan por verificar, igual que los nuevos.
            migrationBuilder.Sql(
                "UPDATE PagoVenta p JOIN MetodosPago m ON m.Id = p.MetodoPagoId " +
                "SET p.EstadoVerificacion = 'PENDIENTE' WHERE m.Tipo <> 'EFECTIVO';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DescuentosFaltante_PagoVenta_PagoVentaId",
                table: "DescuentosFaltante");

            migrationBuilder.DropForeignKey(
                name: "FK_PagoVenta_Usuarios_VerificadoPorId",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_PagoVenta_EstadoVerificacion_Fecha",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_PagoVenta_NumeroOperacion",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_PagoVenta_VerificadoPorId",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_DescuentosFaltante_PagoVentaId",
                table: "DescuentosFaltante");

            migrationBuilder.DropColumn(
                name: "EstadoVerificacion",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "NumeroOperacion",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "ObservacionVerificacion",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "VerificadoEn",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "VerificadoPorId",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "PagoVentaId",
                table: "DescuentosFaltante");

            migrationBuilder.AlterColumn<int>(
                name: "CierreCajaId",
                table: "DescuentosFaltante",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);
        }
    }
}
