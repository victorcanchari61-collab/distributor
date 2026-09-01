using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class ClientesProveedoresDocumento : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Proveedores_Ruc",
                table: "Proveedores");

            migrationBuilder.DropIndex(
                name: "IX_Clientes_Ruc",
                table: "Clientes");

            // Renombrar en vez de borrar+crear: asi los registros que ya
            // existen conservan su documento.
            migrationBuilder.RenameColumn(
                name: "Ruc",
                table: "Proveedores",
                newName: "Documento");

            migrationBuilder.RenameColumn(
                name: "Ruc",
                table: "Clientes",
                newName: "Documento");

            migrationBuilder.AlterColumn<string>(
                name: "Documento",
                table: "Proveedores",
                type: "varchar(15)",
                maxLength: 15,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(11)",
                oldMaxLength: 11)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<string>(
                name: "Documento",
                table: "Clientes",
                type: "varchar(15)",
                maxLength: 15,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(11)",
                oldMaxLength: 11)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<string>(
                name: "Telefono",
                table: "Proveedores",
                type: "varchar(40)",
                maxLength: 40,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "varchar(20)",
                oldMaxLength: 20,
                oldNullable: true)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<string>(
                name: "Nombre",
                table: "Proveedores",
                type: "varchar(200)",
                maxLength: 200,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(150)",
                oldMaxLength: 150)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Departamento",
                table: "Proveedores",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Distrito",
                table: "Proveedores",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "NombreComercial",
                table: "Proveedores",
                type: "varchar(150)",
                maxLength: 150,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Rubro",
                table: "Proveedores",
                type: "varchar(120)",
                maxLength: 120,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Telefono2",
                table: "Proveedores",
                type: "varchar(40)",
                maxLength: 40,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "TipoDoc",
                table: "Proveedores",
                type: "varchar(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<string>(
                name: "Telefono",
                table: "Clientes",
                type: "varchar(40)",
                maxLength: 40,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "varchar(20)",
                oldMaxLength: 20,
                oldNullable: true)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "DiaVisita",
                table: "Clientes",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Distrito",
                table: "Clientes",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Mercado",
                table: "Clientes",
                type: "varchar(80)",
                maxLength: 80,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Ruta",
                table: "Clientes",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "TipoDoc",
                table: "Clientes",
                type: "varchar(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            // El tipo se deduce del largo: 8 = DNI, 11 = RUC, resto = codigo interno.
            migrationBuilder.Sql(
                "UPDATE `Clientes` SET `TipoDoc` = CASE CHAR_LENGTH(`Documento`) " +
                "WHEN 8 THEN 'DNI' WHEN 11 THEN 'RUC' ELSE 'CODIGO' END;");
            migrationBuilder.Sql(
                "UPDATE `Proveedores` SET `TipoDoc` = CASE CHAR_LENGTH(`Documento`) " +
                "WHEN 8 THEN 'DNI' WHEN 11 THEN 'RUC' ELSE 'CODIGO' END;");

            migrationBuilder.CreateIndex(
                name: "IX_Proveedores_Documento",
                table: "Proveedores",
                column: "Documento",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Clientes_Documento",
                table: "Clientes",
                column: "Documento",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Proveedores_Documento",
                table: "Proveedores");

            migrationBuilder.DropIndex(
                name: "IX_Clientes_Documento",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "Departamento",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "Distrito",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "Documento",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "NombreComercial",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "Rubro",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "Telefono2",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "TipoDoc",
                table: "Proveedores");

            migrationBuilder.DropColumn(
                name: "DiaVisita",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "Distrito",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "Documento",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "Mercado",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "Ruta",
                table: "Clientes");

            migrationBuilder.DropColumn(
                name: "TipoDoc",
                table: "Clientes");

            migrationBuilder.AlterColumn<string>(
                name: "Telefono",
                table: "Proveedores",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "varchar(40)",
                oldMaxLength: 40,
                oldNullable: true)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<string>(
                name: "Nombre",
                table: "Proveedores",
                type: "varchar(150)",
                maxLength: 150,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(200)",
                oldMaxLength: 200)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Ruc",
                table: "Proveedores",
                type: "varchar(11)",
                maxLength: 11,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<string>(
                name: "Telefono",
                table: "Clientes",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "varchar(40)",
                oldMaxLength: 40,
                oldNullable: true)
                .Annotation("MySql:CharSet", "utf8mb4")
                .OldAnnotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Ruc",
                table: "Clientes",
                type: "varchar(11)",
                maxLength: 11,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Proveedores_Ruc",
                table: "Proveedores",
                column: "Ruc",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Clientes_Ruc",
                table: "Clientes",
                column: "Ruc",
                unique: true);
        }
    }
}
