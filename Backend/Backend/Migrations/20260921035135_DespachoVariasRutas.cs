using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class DespachoVariasRutas : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DespachoRutas",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    DespachoId = table.Column<int>(type: "int", nullable: false),
                    RutaId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DespachoRutas", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DespachoRutas_Despachos_DespachoId",
                        column: x => x.DespachoId,
                        principalTable: "Despachos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DespachoRutas_Rutas_RutaId",
                        column: x => x.RutaId,
                        principalTable: "Rutas",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "RecorridosVehiculo",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    VehiculoId = table.Column<int>(type: "int", nullable: false),
                    Dia = table.Column<string>(type: "varchar(12)", maxLength: 12, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    RutaId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecorridosVehiculo", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecorridosVehiculo_Rutas_RutaId",
                        column: x => x.RutaId,
                        principalTable: "Rutas",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecorridosVehiculo_Vehiculos_VehiculoId",
                        column: x => x.VehiculoId,
                        principalTable: "Vehiculos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_DespachoRutas_DespachoId_RutaId",
                table: "DespachoRutas",
                columns: new[] { "DespachoId", "RutaId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DespachoRutas_RutaId",
                table: "DespachoRutas",
                column: "RutaId");

            migrationBuilder.CreateIndex(
                name: "IX_RecorridosVehiculo_RutaId",
                table: "RecorridosVehiculo",
                column: "RutaId");

            migrationBuilder.CreateIndex(
                name: "IX_RecorridosVehiculo_VehiculoId_Dia_RutaId",
                table: "RecorridosVehiculo",
                columns: new[] { "VehiculoId", "Dia", "RutaId" },
                unique: true);

            // Los despachos que ya existian llevaban una sola ruta: pasan a tenerla como su primera fila
            // de la lista, para que se sigan leyendo igual con el modelo de varias rutas.
            migrationBuilder.Sql(
                "INSERT INTO DespachoRutas (DespachoId, RutaId) SELECT Id, RutaId FROM Despachos;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DespachoRutas");

            migrationBuilder.DropTable(
                name: "RecorridosVehiculo");
        }
    }
}
