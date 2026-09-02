using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class CatalogoProductos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Categorias",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Categorias", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ListasPrecio",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    EsPredeterminada = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ListasPrecio", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Marcas",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Marcas", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "UnidadesMedida",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Codigo = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Tipo = table.Column<string>(type: "varchar(10)", maxLength: 10, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Fraccionable = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    DelSistema = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UnidadesMedida", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Productos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Codigo = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Nombre = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descripcion = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CategoriaId = table.Column<int>(type: "int", nullable: true),
                    MarcaId = table.Column<int>(type: "int", nullable: true),
                    UnidadBaseId = table.Column<int>(type: "int", nullable: false),
                    Contenido = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: true),
                    ContenidoUnidadId = table.Column<int>(type: "int", nullable: true),
                    ControlaStock = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    StockMinimo = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Productos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Productos_Categorias_CategoriaId",
                        column: x => x.CategoriaId,
                        principalTable: "Categorias",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Productos_Marcas_MarcaId",
                        column: x => x.MarcaId,
                        principalTable: "Marcas",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Productos_UnidadesMedida_ContenidoUnidadId",
                        column: x => x.ContenidoUnidadId,
                        principalTable: "UnidadesMedida",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Productos_UnidadesMedida_UnidadBaseId",
                        column: x => x.UnidadBaseId,
                        principalTable: "UnidadesMedida",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ProductoPresentaciones",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ProductoId = table.Column<int>(type: "int", nullable: false),
                    UnidadId = table.Column<int>(type: "int", nullable: false),
                    Nombre = table.Column<string>(type: "varchar(80)", maxLength: 80, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Factor = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    EsCompra = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    EsVenta = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    PredeterminadaVenta = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    PredeterminadaCompra = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    CodigoBarras = table.Column<string>(type: "varchar(40)", maxLength: 40, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductoPresentaciones", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductoPresentaciones_Productos_ProductoId",
                        column: x => x.ProductoId,
                        principalTable: "Productos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProductoPresentaciones_UnidadesMedida_UnidadId",
                        column: x => x.UnidadId,
                        principalTable: "UnidadesMedida",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "Precios",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ListaPrecioId = table.Column<int>(type: "int", nullable: false),
                    PresentacionId = table.Column<int>(type: "int", nullable: false),
                    Precio = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    CantidadMinima = table.Column<decimal>(type: "decimal(18,4)", precision: 18, scale: 4, nullable: false),
                    Activo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    FechaActualizacion = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Precios", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Precios_ListasPrecio_ListaPrecioId",
                        column: x => x.ListaPrecioId,
                        principalTable: "ListasPrecio",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Precios_ProductoPresentaciones_PresentacionId",
                        column: x => x.PresentacionId,
                        principalTable: "ProductoPresentaciones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "UnidadesMedida",
                columns: new[] { "Id", "Activo", "Codigo", "DelSistema", "FechaCreacion", "Fraccionable", "Nombre", "Tipo" },
                values: new object[,]
                {
                    { 1, true, "UND", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Unidad", "CONTEO" },
                    { 2, true, "KG", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), true, "Kilogramo", "PESO" },
                    { 3, true, "G", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), true, "Gramo", "PESO" },
                    { 4, true, "LT", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), true, "Litro", "VOLUMEN" },
                    { 5, true, "ML", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Mililitro", "VOLUMEN" },
                    { 6, true, "SAC", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Saco", "CONTEO" },
                    { 7, true, "CJA", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Caja", "CONTEO" },
                    { 8, true, "BOL", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Bolsa", "CONTEO" },
                    { 9, true, "PAQ", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Paquete", "CONTEO" },
                    { 10, true, "DOC", true, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), false, "Docena", "CONTEO" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Categorias_Nombre",
                table: "Categorias",
                column: "Nombre",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ListasPrecio_Nombre",
                table: "ListasPrecio",
                column: "Nombre",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Marcas_Nombre",
                table: "Marcas",
                column: "Nombre",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Precios_ListaPrecioId_PresentacionId_CantidadMinima",
                table: "Precios",
                columns: new[] { "ListaPrecioId", "PresentacionId", "CantidadMinima" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Precios_PresentacionId",
                table: "Precios",
                column: "PresentacionId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductoPresentaciones_ProductoId_Factor",
                table: "ProductoPresentaciones",
                columns: new[] { "ProductoId", "Factor" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProductoPresentaciones_UnidadId",
                table: "ProductoPresentaciones",
                column: "UnidadId");

            migrationBuilder.CreateIndex(
                name: "IX_Productos_CategoriaId",
                table: "Productos",
                column: "CategoriaId");

            migrationBuilder.CreateIndex(
                name: "IX_Productos_Codigo",
                table: "Productos",
                column: "Codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Productos_ContenidoUnidadId",
                table: "Productos",
                column: "ContenidoUnidadId");

            migrationBuilder.CreateIndex(
                name: "IX_Productos_MarcaId",
                table: "Productos",
                column: "MarcaId");

            migrationBuilder.CreateIndex(
                name: "IX_Productos_UnidadBaseId",
                table: "Productos",
                column: "UnidadBaseId");

            migrationBuilder.CreateIndex(
                name: "IX_UnidadesMedida_Codigo",
                table: "UnidadesMedida",
                column: "Codigo",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Precios");

            migrationBuilder.DropTable(
                name: "ListasPrecio");

            migrationBuilder.DropTable(
                name: "ProductoPresentaciones");

            migrationBuilder.DropTable(
                name: "Productos");

            migrationBuilder.DropTable(
                name: "Categorias");

            migrationBuilder.DropTable(
                name: "Marcas");

            migrationBuilder.DropTable(
                name: "UnidadesMedida");
        }
    }
}
