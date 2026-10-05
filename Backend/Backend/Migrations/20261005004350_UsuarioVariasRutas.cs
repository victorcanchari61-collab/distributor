using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class UsuarioVariasRutas : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UsuarioRutas",
                columns: table => new
                {
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    RutaId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UsuarioRutas", x => new { x.UsuarioId, x.RutaId });
                    table.ForeignKey(
                        name: "FK_UsuarioRutas_Rutas_RutaId",
                        column: x => x.RutaId,
                        principalTable: "Rutas",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UsuarioRutas_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_UsuarioRutas_RutaId",
                table: "UsuarioRutas",
                column: "RutaId");

            // La ruta que ya tenia cada uno pasa a ser la primera de sus rutas, antes de borrar la columna.
            migrationBuilder.Sql(
                "INSERT INTO UsuarioRutas (UsuarioId, RutaId) SELECT Id, RutaId FROM Usuarios WHERE RutaId IS NOT NULL;");

            migrationBuilder.DropForeignKey(
                name: "FK_Usuarios_Rutas_RutaId",
                table: "Usuarios");

            migrationBuilder.DropIndex(
                name: "IX_Usuarios_RutaId",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "RutaId",
                table: "Usuarios");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "RutaId",
                table: "Usuarios",
                type: "int",
                nullable: true);

            // De vuelta a una sola: se queda con la primera.
            migrationBuilder.Sql(
                "UPDATE Usuarios u SET RutaId = (SELECT MIN(r.RutaId) FROM UsuarioRutas r WHERE r.UsuarioId = u.Id);");

            migrationBuilder.DropTable(
                name: "UsuarioRutas");

            migrationBuilder.CreateIndex(
                name: "IX_Usuarios_RutaId",
                table: "Usuarios",
                column: "RutaId");

            migrationBuilder.AddForeignKey(
                name: "FK_Usuarios_Rutas_RutaId",
                table: "Usuarios",
                column: "RutaId",
                principalTable: "Rutas",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
