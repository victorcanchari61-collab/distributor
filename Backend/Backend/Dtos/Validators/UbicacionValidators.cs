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
            .WithMessage("Elige qué es: piso o cuarto");
        RuleFor(x => x.Codigo).MaximumLength(20)
            .Matches(ReglasUbicacion.PatronCodigo).When(x => !string.IsNullOrWhiteSpace(x.Codigo))
            .WithMessage(ReglasUbicacion.MensajeCodigo);
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Ponle un nombre").MaximumLength(80);
    }
}

public class ActualizarUbicacionRequestValidator : AbstractValidator<ActualizarUbicacionRequest>
{
    public ActualizarUbicacionRequestValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().WithMessage("Ponle un código")
            .MaximumLength(20)
            .Matches(ReglasUbicacion.PatronCodigo).WithMessage(ReglasUbicacion.MensajeCodigo);
        RuleFor(x => x.Nombre).MaximumLength(80);
    }
}

public class PosicionPlanoRequestValidator : AbstractValidator<PosicionPlanoRequest>
{
    public PosicionPlanoRequestValidator()
    {
        // O todo o nada: un lugar está dibujado entero o no está en el plano.
        RuleFor(x => x).Must(p => (p.X, p.Y, p.Ancho, p.Alto) is (null, null, null, null)
                                  || (p.X is not null && p.Y is not null && p.Ancho is not null && p.Alto is not null))
            .WithMessage("Falta la posición o el tamaño en el plano");
    }
}

public class ElementoPlanoRequestValidator : AbstractValidator<ElementoPlanoRequest>
{
    public ElementoPlanoRequestValidator()
    {
        RuleFor(x => x.Tipo).Must(t => TipoElementoPlano.Todos.Contains(t)).WithMessage("Elige si es pasillo o escalera");
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Ponle un nombre").MaximumLength(80);
    }
}

public class AsignarProductoUbicacionRequestValidator : AbstractValidator<AsignarProductoUbicacionRequest>
{
    public AsignarProductoUbicacionRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
    }
}

public class AsignarProductosUbicacionRequestValidator : AbstractValidator<AsignarProductosUbicacionRequest>
{
    /// <summary>Tope de una tanda: más que esto es casi seguro seleccionar de más.</summary>
    public const int Maximo = 500;

    public AsignarProductosUbicacionRequestValidator()
    {
        RuleFor(x => x.UbicacionId).GreaterThan(0).WithMessage("Elige el lugar");
        RuleFor(x => x.ProductoIds).NotEmpty().WithMessage("Elige al menos un producto")
            .Must(p => p.Count <= Maximo).WithMessage($"Elige hasta {Maximo} productos por vez");
    }
}

public class QuitarProductosUbicacionRequestValidator : AbstractValidator<QuitarProductosUbicacionRequest>
{
    public QuitarProductosUbicacionRequestValidator()
    {
        RuleFor(x => x.UbicacionId).GreaterThan(0).WithMessage("Elige el lugar");
        RuleFor(x => x.ProductoIds).NotEmpty().WithMessage("Elige al menos un producto");
    }
}
