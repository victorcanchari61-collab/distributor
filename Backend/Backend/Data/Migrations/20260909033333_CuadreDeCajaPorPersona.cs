using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class CuadreDeCajaPorPersona : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            /*
             * Los cierres viejos se borran, no se convierten.
             *
             * Aquello era un unico cierre diario de toda la caja, con "lo
             * esperado" contra "lo contado". Lo nuevo es por persona y separa
             * efectivo de bancos, con los gastos de la ruta aparte: no hay
             * forma de repartir un total global entre personas sin inventar
             * quien trajo que, y un cuadre inventado es peor que no tenerlo.
             *
             * Ademas la columna UsuarioId pasa a ser obligatoria, y las filas
             * viejas podian no tener ninguno.
             */
            migrationBuilder.Sql("DELETE FROM ArqueoCaja;");

            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_Usuarios_UsuarioId",
                table: "ArqueoCaja");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_Fecha",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(name: "MontoEsperado", table: "ArqueoCaja");

            migrationBuilder.AddColumn<decimal>(
                name: "Monedas",
                table: "ArqueoCaja",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.DropColumn(name: "MontoContado", table: "ArqueoCaja");

            migrationBuilder.AddColumn<decimal>(
                name: "EfectivoSistema",
                table: "ArqueoCaja",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AlterColumn<int>(
                name: "UsuarioId",
                table: "ArqueoCaja",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "BancosSistema",
                table: "ArqueoCaja",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "Billetes",
                table: "ArqueoCaja",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Estado",
                table: "ArqueoCaja",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<bool>(
                name: "FaltanteSaldado",
                table: "ArqueoCaja",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "FechaSaldado",
                table: "ArqueoCaja",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RegistradoPorId",
                table: "ArqueoCaja",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ArqueoPagosDigitales",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ArqueoCajaId = table.Column<int>(type: "int", nullable: false),
                    ClienteId = table.Column<int>(type: "int", nullable: true),
                    MetodoPagoId = table.Column<int>(type: "int", nullable: false),
                    NumeroOperacion = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ArqueoPagosDigitales", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_ArqueoCaja_ArqueoCajaId",
                        column: x => x.ArqueoCajaId,
                        principalTable: "ArqueoCaja",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_Clientes_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Clientes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ArqueoPagosDigitales_MetodosPago_MetodoPagoId",
                        column: x => x.MetodoPagoId,
                        principalTable: "MetodosPago",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "MotivosGasto",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MotivosGasto", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ArqueoGastos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ArqueoCajaId = table.Column<int>(type: "int", nullable: false),
                    MotivoGastoId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ArqueoGastos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ArqueoGastos_ArqueoCaja_ArqueoCajaId",
                        column: x => x.ArqueoCajaId,
                        principalTable: "ArqueoCaja",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ArqueoGastos_MotivosGasto_MotivoGastoId",
                        column: x => x.MotivoGastoId,
                        principalTable: "MotivosGasto",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "MotivosGasto",
                columns: new[] { "Id", "Activo", "Descripcion", "FechaCreacion", "Nombre" },
                values: new object[,]
                {
                    { 1, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Pasaje" },
                    { 2, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Combustible" },
                    { 3, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Menú" },
                    { 4, true, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Peaje" },
                    { 5, true, "Cualquier gasto que no encaje en los demás. Conviene detallarlo.", new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "Otro" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_Fecha_UsuarioId",
                table: "ArqueoCaja",
                columns: new[] { "Fecha", "UsuarioId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_RegistradoPorId",
                table: "ArqueoCaja",
                column: "RegistradoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoGastos_ArqueoCajaId",
                table: "ArqueoGastos",
                column: "ArqueoCajaId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoGastos_MotivoGastoId",
                table: "ArqueoGastos",
                column: "MotivoGastoId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_ArqueoCajaId",
                table: "ArqueoPagosDigitales",
                column: "ArqueoCajaId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_ClienteId",
                table: "ArqueoPagosDigitales",
                column: "ClienteId");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoPagosDigitales_MetodoPagoId",
                table: "ArqueoPagosDigitales",
                column: "MetodoPagoId");

            migrationBuilder.CreateIndex(
                name: "IX_MotivosGasto_Nombre",
                table: "MotivosGasto",
                column: "Nombre",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_Usuarios_RegistradoPorId",
                table: "ArqueoCaja",
                column: "RegistradoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_Usuarios_UsuarioId",
                table: "ArqueoCaja",
                column: "UsuarioId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_Usuarios_RegistradoPorId",
                table: "ArqueoCaja");

            migrationBuilder.DropForeignKey(
                name: "FK_ArqueoCaja_Usuarios_UsuarioId",
                table: "ArqueoCaja");

            migrationBuilder.DropTable(
                name: "ArqueoGastos");

            migrationBuilder.DropTable(
                name: "ArqueoPagosDigitales");

            migrationBuilder.DropTable(
                name: "MotivosGasto");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_Fecha_UsuarioId",
                table: "ArqueoCaja");

            migrationBuilder.DropIndex(
                name: "IX_ArqueoCaja_RegistradoPorId",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "BancosSistema",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "Billetes",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "Estado",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "FaltanteSaldado",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "FechaSaldado",
                table: "ArqueoCaja");

            migrationBuilder.DropColumn(
                name: "RegistradoPorId",
                table: "ArqueoCaja");

            migrationBuilder.RenameColumn(
                name: "Monedas",
                table: "ArqueoCaja",
                newName: "MontoEsperado");

            migrationBuilder.RenameColumn(
                name: "EfectivoSistema",
                table: "ArqueoCaja",
                newName: "MontoContado");

            migrationBuilder.AlterColumn<int>(
                name: "UsuarioId",
                table: "ArqueoCaja",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.CreateIndex(
                name: "IX_ArqueoCaja_Fecha",
                table: "ArqueoCaja",
                column: "Fecha",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_ArqueoCaja_Usuarios_UsuarioId",
                table: "ArqueoCaja",
                column: "UsuarioId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}
