using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class GuardarGestionRequestValidator : AbstractValidator<GuardarGestionRequest>
{
    public GuardarGestionRequestValidator()
    {
        RuleFor(x => x.TipoContacto).Must(t => TipoContacto.Todos.Contains(t))
            .WithMessage("Elige cómo fue el contacto: llamada, WhatsApp, visita o correo");
        RuleFor(x => x.Resultado).Must(r => ResultadoGestion.Todos.Contains(r))
            .WithMessage("Elige el resultado de la gestión");
        RuleFor(x => x.Comentario).MaximumLength(500);

        RuleFor(x => x.ProximoTipoContacto)
            .Must(t => t is null || TipoContacto.Todos.Contains(t))
            .WithMessage("Elige cómo será el próximo contacto: llamada, WhatsApp, visita o correo");
        RuleFor(x => x.ProximaAccion).MaximumLength(150);
    }
}
