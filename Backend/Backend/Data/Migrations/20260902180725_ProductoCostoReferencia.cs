using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Data.Migrations
{
    /// <inheritdoc />
    public partial class ProductoCostoReferencia : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "CostoReferencia",
                table: "Productos",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CostoReferencia",
                table: "Productos");
        }
    }
}
