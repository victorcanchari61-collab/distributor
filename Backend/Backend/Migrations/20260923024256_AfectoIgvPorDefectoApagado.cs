using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class AfectoIgvPorDefectoApagado : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<bool>(
                name: "AfectoIgv",
                table: "Productos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false,
                oldClrType: typeof(bool),
                oldType: "tinyint(1)",
                oldDefaultValue: true);

            // La migración anterior encendió el IGV en todo el catálogo ya
            // existente (era el valor por defecto entonces). Se apaga de
            // vuelta: el usuario decidió que arranque apagado y lo prenda
            // producto por producto donde sí corresponda.
            migrationBuilder.Sql("UPDATE `Productos` SET `AfectoIgv` = FALSE;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<bool>(
                name: "AfectoIgv",
                table: "Productos",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: true,
                oldClrType: typeof(bool),
                oldType: "tinyint(1)",
                oldDefaultValue: false);
        }
    }
}
