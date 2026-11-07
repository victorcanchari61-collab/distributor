using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class LineaSolicitudCompraRequestValidator : AbstractValidator<LineaSolicitudCompraRequest>
{
    public LineaSolicitudCompraRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad tiene que ser mayor que cero");
        RuleFor(x => x.Nota).MaximumLength(150);
    }
}

public class CrearSolicitudCompraRequestValidator : AbstractValidator<CrearSolicitudCompraRequest>
{
    public CrearSolicitudCompraRequestValidator()
    {
        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén para el que se pide");
        RuleFor(x => x.Urgencia)
            .Must(u => string.IsNullOrWhiteSpace(u) || UrgenciaSolicitudCompra.Todas.Contains(u.Trim().ToUpperInvariant()))
            .WithMessage("La urgencia es NORMAL o URGENTE");
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaSolicitudCompraRequestValidator());
    }
}

public class RechazarSolicitudCompraRequestValidator : AbstractValidator<RechazarSolicitudCompraRequest>
{
    public RechazarSolicitudCompraRequestValidator()
    {
        RuleFor(x => x.Motivo).NotEmpty().WithMessage("Escribe por qué se rechaza").MaximumLength(250);
    }
}
