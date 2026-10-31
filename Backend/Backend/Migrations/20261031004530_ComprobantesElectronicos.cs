using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class ComprobantesElectronicos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ComprobantesElectronicos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Tipo = table.Column<string>(type: "varchar(2)", maxLength: 2, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Serie = table.Column<string>(type: "varchar(4)", maxLength: 4, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Numero = table.Column<int>(type: "int", nullable: false),
                    NotaVentaId = table.Column<int>(type: "int", nullable: true),
                    AfectadoId = table.Column<int>(type: "int", nullable: true),
                    FechaEmision = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    ClienteId = table.Column<int>(type: "int", nullable: true),
                    ClienteTipoDoc = table.Column<string>(type: "varchar(1)", maxLength: 1, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ClienteDocumento = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ClienteNombre = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ClienteDireccion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Moneda = table.Column<string>(type: "varchar(3)", maxLength: 3, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    OpGravada = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    OpExonerada = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Igv = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Total = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CodMotivo = table.Column<string>(type: "varchar(2)", maxLength: 2, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DesMotivo = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DetalleJson = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Estado = table.Column<string>(type: "varchar(12)", maxLength: 12, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CodigoSunat = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    MensajeSunat = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    NotasSunat = table.Column<string>(type: "varchar(1000)", maxLength: 1000, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    NombreArchivo = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Hash = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    QrInfo = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    XmlFirmado = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CdrZip = table.Column<byte[]>(type: "longblob", nullable: true),
                    Entorno = table.Column<string>(type: "varchar(12)", maxLength: 12, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UsuarioId = table.Column<int>(type: "int", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    EnviadoEn = table.Column<DateTime>(type: "datetime(6)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ComprobantesElectronicos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ComprobantesElectronicos_ComprobantesElectronicos_AfectadoId",
                        column: x => x.AfectadoId,
                        principalTable: "ComprobantesElectronicos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ComprobantesElectronicos_NotasVenta_NotaVentaId",
                        column: x => x.NotaVentaId,
                        principalTable: "NotasVenta",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ComprobantesElectronicos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "SeriesCpe",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Tipo = table.Column<string>(type: "varchar(2)", maxLength: 2, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Serie = table.Column<string>(type: "varchar(4)", maxLength: 4, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AplicaA = table.Column<string>(type: "varchar(2)", maxLength: 2, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UltimoNumero = table.Column<int>(type: "int", nullable: false),
                    Activa = table.Column<bool>(type: "tinyint(1)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SeriesCpe", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "SeriesCpe",
                columns: new[] { "Id", "Activa", "AplicaA", "Serie", "Tipo", "UltimoNumero" },
                values: new object[,]
                {
                    { 1, true, null, "F001", "01", 0 },
                    { 2, true, null, "B001", "03", 0 },
                    { 3, true, "01", "FC01", "07", 0 },
                    { 4, true, "03", "BC01", "07", 0 },
                    { 5, true, "01", "FD01", "08", 0 },
                    { 6, true, "03", "BD01", "08", 0 }
                });

            migrationBuilder.CreateIndex(
                name: "IX_ComprobantesElectronicos_AfectadoId",
                table: "ComprobantesElectronicos",
                column: "AfectadoId");

            migrationBuilder.CreateIndex(
                name: "IX_ComprobantesElectronicos_Estado_FechaEmision",
                table: "ComprobantesElectronicos",
                columns: new[] { "Estado", "FechaEmision" });

            migrationBuilder.CreateIndex(
                name: "IX_ComprobantesElectronicos_NotaVentaId",
                table: "ComprobantesElectronicos",
                column: "NotaVentaId");

            migrationBuilder.CreateIndex(
                name: "IX_ComprobantesElectronicos_Serie_Numero",
                table: "ComprobantesElectronicos",
                columns: new[] { "Serie", "Numero" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ComprobantesElectronicos_UsuarioId",
                table: "ComprobantesElectronicos",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_SeriesCpe_Serie",
                table: "SeriesCpe",
                column: "Serie",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ComprobantesElectronicos");

            migrationBuilder.DropTable(
                name: "SeriesCpe");
        }
    }
}
