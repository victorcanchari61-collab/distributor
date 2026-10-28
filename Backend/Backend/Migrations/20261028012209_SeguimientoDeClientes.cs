using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <summary>
    /// Las gestiones con el cliente pasan a ser como en 7power: tipo de contacto (llamada, WhatsApp, visita o correo),
    /// cinco resultados resumidos, y un siguiente contacto con día y hora que está programado o cumplido.
    ///
    /// Lo que ya hubiera registrado se conserva: la nota pasa a ser el comentario, el resultado se lleva al resumen
    /// que le corresponde y la acción pendiente sin cumplir queda como contacto programado.
    /// </summary>
    public partial class SeguimientoDeClientes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_GestionesCliente_Cumplida_ProximaFecha",
                table: "GestionesCliente");

            migrationBuilder.RenameColumn(
                name: "Tipo",
                table: "GestionesCliente",
                newName: "TipoContacto");

            migrationBuilder.RenameColumn(
                name: "ProximaFecha",
                table: "GestionesCliente",
                newName: "ProximoSeguimiento");

            migrationBuilder.AddColumn<string>(
                name: "Comentario",
                table: "GestionesCliente",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ProximoTipoContacto",
                table: "GestionesCliente",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "SeguimientoEstado",
                table: "GestionesCliente",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            // Lo ya registrado: la nota es el comentario, el resultado va al resumen que le toca y el contacto
            // pendiente (con su día) queda programado o cumplido. La fecha vieja era un día a las 00:00: pasa a las 10:00,
            // la hora que propone la pantalla.
            migrationBuilder.Sql("UPDATE GestionesCliente SET Comentario = Nota;");
            migrationBuilder.Sql(@"
                UPDATE GestionesCliente SET Resultado = CASE Resultado
                    WHEN 'PROMESA_COMPRA' THEN 'OPORTUNIDAD'
                    WHEN 'RECLAMO' THEN 'CON_OBJECIONES'
                    WHEN 'PERDIDO' THEN 'NO_RECUPERABLE'
                    WHEN 'SIN_RESPUESTA' THEN 'SIN_RESPUESTA'
                    ELSE 'SEGUIMIENTO' END;");
            migrationBuilder.Sql(@"
                UPDATE GestionesCliente
                SET SeguimientoEstado = CASE WHEN Cumplida = 1 THEN 'CUMPLIDO' ELSE 'PROGRAMADO' END,
                    ProximoTipoContacto = TipoContacto,
                    ProximoSeguimiento = DATE_ADD(ProximoSeguimiento, INTERVAL 15 HOUR)
                WHERE ProximoSeguimiento IS NOT NULL;");

            migrationBuilder.DropColumn(
                name: "Cumplida",
                table: "GestionesCliente");

            migrationBuilder.DropColumn(
                name: "CumplidaEn",
                table: "GestionesCliente");

            migrationBuilder.DropColumn(
                name: "Nota",
                table: "GestionesCliente");

            migrationBuilder.CreateIndex(
                name: "IX_GestionesCliente_SeguimientoEstado_ProximoSeguimiento",
                table: "GestionesCliente",
                columns: new[] { "SeguimientoEstado", "ProximoSeguimiento" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_GestionesCliente_SeguimientoEstado_ProximoSeguimiento",
                table: "GestionesCliente");

            migrationBuilder.DropColumn(
                name: "Comentario",
                table: "GestionesCliente");

            migrationBuilder.DropColumn(
                name: "ProximoTipoContacto",
                table: "GestionesCliente");

            migrationBuilder.DropColumn(
                name: "SeguimientoEstado",
                table: "GestionesCliente");

            migrationBuilder.RenameColumn(
                name: "TipoContacto",
                table: "GestionesCliente",
                newName: "Tipo");

            migrationBuilder.RenameColumn(
                name: "ProximoSeguimiento",
                table: "GestionesCliente",
                newName: "ProximaFecha");

            migrationBuilder.AddColumn<bool>(
                name: "Cumplida",
                table: "GestionesCliente",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "CumplidaEn",
                table: "GestionesCliente",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Nota",
                table: "GestionesCliente",
                type: "varchar(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_GestionesCliente_Cumplida_ProximaFecha",
                table: "GestionesCliente",
                columns: new[] { "Cumplida", "ProximaFecha" });
        }
    }
}
