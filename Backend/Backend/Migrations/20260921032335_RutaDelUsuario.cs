using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class RutaDelUsuario : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "RutaId",
                table: "Usuarios",
                type: "int",
                nullable: true);

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

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
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
    }
}
