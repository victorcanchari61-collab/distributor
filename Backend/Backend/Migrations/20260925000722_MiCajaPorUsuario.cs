using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class MiCajaPorUsuario : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "MovimientoCuentaId",
                table: "PagoVenta",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "UsuarioResponsableId",
                table: "CuentasFinancieras",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MovimientoAperturaDestinoId",
                table: "ArqueoCaja",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MovimientoCierreDestinoId",
                table: "ArqueoCaja",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "SaldoCajaAlCerrar",
                table: "ArqueoCaja",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.UpdateData(
                table: "CuentasFinancieras",
                keyColumn: "Id",
                keyValue: 1,
                column: "UsuarioResponsableId",
                value: null);

            migrationBuilder.CreateIndex(
                name: "IX_PagoVenta_MovimientoCuentaId",
                table: "PagoVenta",
                column: "MovimientoCuentaId");

            migrationBuilder.CreateIndex(
                name: "IX_CuentasFinancieras_UsuarioResponsableId",
                table: "CuentasFinancieras",
                column: "UsuarioResponsableId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoAperturaDestinoId",
                table: "ArqueoCaja",
                column: "MovimientoAperturaDestinoId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_MovimientoCierreDestinoId",
                table: "ArqueoCaja",
                column: "MovimientoCierreDestinoId");

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoAperturaDestinoId",
                table: "ArqueoCaja",
                column: "MovimientoAperturaDestinoId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoCierreDestinoId",
                table: "ArqueoCaja",
                column: "MovimientoCierreDestinoId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_CuentasFinancieras_Usuarios_UsuarioResponsableId",
                table: "CuentasFinancieras",
                column: "UsuarioResponsableId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PagoVenta_MovimientosCuenta_MovimientoCuentaId",
                table: "PagoVenta",
                column: "MovimientoCuentaId",
                principalTable: "MovimientosCuenta",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoAperturaDestinoId",
                table: "ArqueoCaja");

            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_MovimientosCuenta_MovimientoCierreDestinoId",
                table: "ArqueoCaja");

            migrationBuilder.DropForeignKey(
                name: "FK_CuentasFinancieras_Usuarios_UsuarioResponsableId",
                table: "CuentasFinancieras");

            migrationBuilder.DropForeignKey(
                name: "FK_PagoVenta_MovimientosCuenta_MovimientoCuentaId",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_PagoVenta_MovimientoCuentaId",
                table: "PagoVenta");

            migrationBuilder.DropIndex(
                name: "IX_CuentasFinancieras_UsuarioResponsableId",
                table: "CuentasFinancieras");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_MovimientoAperturaDestinoId",
                table: "ArqueoCaja");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_MovimientoCierreDestinoId",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "MovimientoCuentaId",
                table: "PagoVenta");

            migrationBuilder.DropColumn(
                name: "UsuarioResponsableId",
                table: "CuentasFinancieras");

            migrationBuilder.DropColumn(
                name: "MovimientoAperturaDestinoId",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "MovimientoCierreDestinoId",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "SaldoCajaAlCerrar",
                table: "ArqueoCaja");
        }
    }
}
