using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

/// <summary>
/// El código lleva letras, números, punto y guion bajo. El guion queda fuera a propósito: es el que une los
/// códigos de la ruta (P1-A-03), y uno adentro de un código la volvería ambigua.
/// </summary>
internal static class ReglasUbicacion
{
    public const string PatronCodigo = "^[A-Za-z0-9._]+$";
    public const string MensajeCodigo = "El código lleva solo letras, números, punto o guion bajo";
}

public class CrearUbicacionRequestValidator : AbstractValidator<CrearUbicacionRequest>
{
    public CrearUbicacionRequestValidator()
    {
        RuleFor(x => x.Tipo).Must(t => TipoUbicacion.Todos.Contains(t))
            .WithMessage("Elige qué es: piso, zona, pasillo, estante, nivel, posición u otro");
        RuleFor(x => x.Codigo).NotEmpty().WithMessage("Ponle un código")
            .MaximumLength(20)
            .Matches(ReglasUbicacion.PatronCodigo).WithMessage(ReglasUbicacion.MensajeCodigo);
        RuleFor(x => x.Nombre).MaximumLength(80);
    }
}

public class ActualizarUbicacionRequestValidator : AbstractValidator<ActualizarUbicacionRequest>
{
    public ActualizarUbicacionRequestValidator()
    {
        RuleFor(x => x.Tipo).Must(t => TipoUbicacion.Todos.Contains(t))
            .WithMessage("Elige qué es: piso, zona, pasillo, estante, nivel, posición u otro");
        RuleFor(x => x.Codigo).NotEmpty().WithMessage("Ponle un código")
            .MaximumLength(20)
            .Matches(ReglasUbicacion.PatronCodigo).WithMessage(ReglasUbicacion.MensajeCodigo);
        RuleFor(x => x.Nombre).MaximumLength(80);
    }
}

public class GenerarUbicacionesRequestValidator : AbstractValidator<GenerarUbicacionesRequest>
{
    /// <summary>Tope de una tanda: más que esto es casi seguro un error de tipeo (1 a 10000).</summary>
    public const int Maximo = 100;

    public GenerarUbicacionesRequestValidator()
    {
        RuleFor(x => x.Tipo).Must(t => TipoUbicacion.Todos.Contains(t))
            .WithMessage("Elige qué son: pisos, pasillos, estantes, posiciones...");
        RuleFor(x => x.Prefijo).MaximumLength(10)
            .Matches(ReglasUbicacion.PatronCodigo).When(x => !string.IsNullOrEmpty(x.Prefijo))
            .WithMessage(ReglasUbicacion.MensajeCodigo);
        RuleFor(x => x.Desde).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Hasta).GreaterThanOrEqualTo(x => x.Desde).WithMessage("El \"hasta\" no puede ser menor que el \"desde\"")
            .Must((x, hasta) => hasta - x.Desde + 1 <= Maximo).WithMessage($"Crea hasta {Maximo} lugares por vez");
        RuleFor(x => x.Digitos).InclusiveBetween(1, 4);
    }
}

public class AsignarProductoUbicacionRequestValidator : AbstractValidator<AsignarProductoUbicacionRequest>
{
    public AsignarProductoUbicacionRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
    }
}
