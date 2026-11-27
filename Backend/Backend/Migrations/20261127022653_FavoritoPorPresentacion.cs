using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class FavoritoPorPresentacion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // MySQL no deja quitar el índice que usa la clave foránea del cliente: uno temporal la sostiene mientras tanto.
            migrationBuilder.CreateIndex(
                name: "IX_ClienteFavoritos_ClienteId_tmp",
                table: "ClienteFavoritos",
                column: "ClienteId");

            migrationBuilder.DropIndex(
                name: "IX_ClienteFavoritos_ClienteId_ProductoId",
                table: "ClienteFavoritos");

            migrationBuilder.AddColumn<int>(
                name: "PresentacionId",
                table: "ClienteFavoritos",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Los favoritos de antes eran del producto entero: pasan a ser cada presentación que se vende de ese
            // producto, así nadie pierde lo que marcó. Después se borran las filas de producto (las de 0).
            migrationBuilder.Sql(@"
                INSERT INTO ClienteFavoritos (ClienteId, ProductoId, PresentacionId, Fecha)
                SELECT f.ClienteId, f.ProductoId, pp.Id, f.Fecha
                FROM ClienteFavoritos f
                JOIN ProductoPresentaciones pp ON pp.ProductoId = f.ProductoId AND pp.Activo = 1 AND pp.EsVenta = 1
                WHERE f.PresentacionId = 0;");
            migrationBuilder.Sql("DELETE FROM ClienteFavoritos WHERE PresentacionId = 0;");

            migrationBuilder.CreateIndex(
                name: "IX_ClienteFavoritos_ClienteId_PresentacionId",
                table: "ClienteFavoritos",
                columns: new[] { "ClienteId", "PresentacionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ClienteFavoritos_PresentacionId",
                table: "ClienteFavoritos",
                column: "PresentacionId");

            migrationBuilder.AddForeignKey(
                name: "FK_ClienteFavoritos_ProductoPresentaciones_PresentacionId",
                table: "ClienteFavoritos",
                column: "PresentacionId",
                principalTable: "ProductoPresentaciones",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.DropIndex(
                name: "IX_ClienteFavoritos_ClienteId_tmp",
                table: "ClienteFavoritos");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // MySQL no deja quitar el índice que usa la clave foránea del cliente: uno temporal la sostiene mientras tanto.
            migrationBuilder.CreateIndex(
                name: "IX_ClienteFavoritos_ClienteId_tmp",
                table: "ClienteFavoritos",
                column: "ClienteId");

            migrationBuilder.DropForeignKey(
                name: "FK_ClienteFavoritos_ProductoPresentaciones_PresentacionId",
                table: "ClienteFavoritos");

            migrationBuilder.DropIndex(
                name: "IX_ClienteFavoritos_ClienteId_PresentacionId",
                table: "ClienteFavoritos");

            migrationBuilder.DropIndex(
                name: "IX_ClienteFavoritos_PresentacionId",
                table: "ClienteFavoritos");

            // De vuelta a uno por producto: de las presentaciones de un mismo producto queda la primera que marcó.
            migrationBuilder.Sql(@"
                DELETE f FROM ClienteFavoritos f
                JOIN ClienteFavoritos g ON g.ClienteId = f.ClienteId AND g.ProductoId = f.ProductoId AND g.Id < f.Id;");

            migrationBuilder.DropColumn(
                name: "PresentacionId",
                table: "ClienteFavoritos");

            migrationBuilder.CreateIndex(
                name: "IX_ClienteFavoritos_ClienteId_ProductoId",
                table: "ClienteFavoritos",
                columns: new[] { "ClienteId", "ProductoId" },
                unique: true);

            migrationBuilder.DropIndex(
                name: "IX_ClienteFavoritos_ClienteId_tmp",
                table: "ClienteFavoritos");
        }
    }
}
