using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class AlmacenesYUbicaciones : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DistritoId",
                table: "Almacenes",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Referencia",
                table: "Almacenes",
                type: "varchar(250)",
                maxLength: 250,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Responsable",
                table: "Almacenes",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Telefono",
                table: "Almacenes",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Tipo",
                table: "Almacenes",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "ALMACEN")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "UbicacionesAlmacen",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    AlmacenId = table.Column<int>(type: "int", nullable: false),
                    PadreId = table.Column<int>(type: "int", nullable: true),
                    Tipo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Codigo = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UbicacionesAlmacen", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UbicacionesAlmacen_Almacenes_AlmacenId",
                        column: x => x.AlmacenId,
                        principalTable: "Almacenes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UbicacionesAlmacen_UbicacionesAlmacen_PadreId",
                        column: x => x.PadreId,
                        principalTable: "UbicacionesAlmacen",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ProductosUbicacion",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    UbicacionId = table.Column<int>(type: "int", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductosUbicacion", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductosUbicacion_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProductosUbicacion_UbicacionesAlmacen_UbicacionId",
                        column: x => x.UbicacionId,
                        principalTable: "UbicacionesAlmacen",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.UpdateData(
                table: "Almacenes",
                keyColumn: "Id",
                keyValue: 1,
                columns: new[] { "DistritoId", "Referencia", "Responsable", "Telefono", "Tipo" },
                values: new object[] { null, null, null, null, "ALMACEN" });

            migrationBuilder.CreateIndex(
                name: "IX_Almacenes_DistritoId",
                table: "Almacenes",
                column: "DistritoId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductosUbicacion_ProductoId",
                table: "ProductosUbicacion",
                column: "ProductoId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductosUbicacion_UbicacionId_ProductoId",
                table: "ProductosUbicacion",
                columns: new[] { "UbicacionId", "ProductoId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UbicacionesAlmacen_AlmacenId_PadreId_Codigo",
                table: "UbicacionesAlmacen",
                columns: new[] { "AlmacenId", "PadreId", "Codigo" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UbicacionesAlmacen_PadreId",
                table: "UbicacionesAlmacen",
                column: "PadreId");

            migrationBuilder.AddForeignKey(
                name: "FK_Almacenes_Distritos_DistritoId",
                table: "Almacenes",
                column: "DistritoId",
                principalTable: "Distritos",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Almacenes_Distritos_DistritoId",
                table: "Almacenes");

            migrationBuilder.DropTable(
                name: "ProductosUbicacion");

            migrationBuilder.DropTable(
                name: "UbicacionesAlmacen");

            migrationBuilder.DropIndex(
                name: "IX_Almacenes_DistritoId",
                table: "Almacenes");

            migrationBuilder.DropColumn(
                name: "DistritoId",
                table: "Almacenes");

            migrationBuilder.DropColumn(
                name: "Referencia",
                table: "Almacenes");

            migrationBuilder.DropColumn(
                name: "Responsable",
                table: "Almacenes");

            migrationBuilder.DropColumn(
                name: "Telefono",
                table: "Almacenes");

            migrationBuilder.DropColumn(
                name: "Tipo",
                table: "Almacenes");
        }
    }
}
