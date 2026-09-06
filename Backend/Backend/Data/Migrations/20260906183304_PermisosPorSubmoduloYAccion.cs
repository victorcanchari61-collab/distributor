using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class PermisosPorSubmoduloYAccion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Las filas viejas no se pueden convertir: eran un modulo entero
            // con cuatro booleanos, y lo nuevo es una accion sobre un submodulo
            // concreto — "Inventario: editar" no dice si eso incluia ajustes,
            // transferencias o ambos. Inventarlo daria permisos que nadie
            // concedio. Ademas hasta hoy no bloqueaban nada, asi que borrarlas
            // no le quita acceso a nadie que lo tuviera de verdad: la matriz de
            // Accesos se vuelve a marcar una vez, ya con el detalle real.
            // Sin esto, cada fila vieja quedaria con Submodulo y Accion vacios y
            // el indice unico nuevo chocaria en cualquier rol con dos modulos.
            migrationBuilder.Sql("DELETE FROM RolPermisos;");

            // MySQL se apoya en ese indice para la clave foranea de RolId, y no
            // deja soltarlo mientras la FK exista: se quita, se rehace el indice
            // y se vuelve a poner.
            migrationBuilder.DropForeignKey(
                name: "FK_RolPermisos_Roles_RolId",
                table: "RolPermisos");

            migrationBuilder.DropIndex(
                name: "IX_RolPermisos_RolId_Modulo",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Crear",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Editar",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Eliminar",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Modulo",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Ver",
                table: "RolPermisos");

            migrationBuilder.AddColumn<string>(
                name: "Accion",
                table: "RolPermisos",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Submodulo",
                table: "RolPermisos",
                type: "varchar(60)",
                maxLength: 60,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_RolPermisos_RolId_Submodulo_Accion",
                table: "RolPermisos",
                columns: new[] { "RolId", "Submodulo", "Accion" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_RolPermisos_Roles_RolId",
                table: "RolPermisos",
                column: "RolId",
                principalTable: "Roles",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RolPermisos_RolId_Submodulo_Accion",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Accion",
                table: "RolPermisos");

            migrationBuilder.DropColumn(
                name: "Submodulo",
                table: "RolPermisos");

            migrationBuilder.AddColumn<bool>(
                name: "Crear",
                table: "RolPermisos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "Editar",
                table: "RolPermisos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "Eliminar",
                table: "RolPermisos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "Modulo",
                table: "RolPermisos",
                type: "varchar(40)",
                maxLength: 40,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<bool>(
                name: "Ver",
                table: "RolPermisos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_RolPermisos_RolId_Modulo",
                table: "RolPermisos",
                columns: new[] { "RolId", "Modulo" },
                unique: true);
        }
    }
}
