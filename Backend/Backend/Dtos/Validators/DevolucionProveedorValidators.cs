using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class LineaDevolucionProveedorRequestValidator : AbstractValidator<LineaDevolucionProveedorRequest>
{
    public LineaDevolucionProveedorRequestValidator()
    {
        RuleFor(x => x.CompraDetalleId).GreaterThan(0).WithMessage("Elige el producto de la compra");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad a devolver debe ser mayor que cero");
        RuleFor(x => x.Origen)
            .Must(o => OrigenDevolucionProveedor.Todos.Contains(o))
            .WithMessage("Indica si lo devuelto ya había llegado o no llegó");
        RuleFor(x => x.Resolucion)
            .Must(r => ResolucionDevolucionProveedor.Todas.Contains(r))
            .WithMessage("Indica si el proveedor lo repone o lo descuenta");
    }
}

public class CrearDevolucionProveedorRequestValidator : AbstractValidator<CrearDevolucionProveedorRequest>
{
    public CrearDevolucionProveedorRequestValidator()
    {
        RuleFor(x => x.CompraId).GreaterThan(0).WithMessage("Elige la compra");
        RuleFor(x => x.Motivo).NotEmpty().WithMessage("Indica por qué se devuelve").MaximumLength(150);
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.SerieNotaCredito).MaximumLength(10);
        RuleFor(x => x.NumeroNotaCredito).MaximumLength(20);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Indica qué productos se devuelven");
        RuleForEach(x => x.Detalle).SetValidator(new LineaDevolucionProveedorRequestValidator());
        RuleFor(x => x.AlmacenId)
            .NotNull()
            .When(x => x.Detalle.Any(l => l.Origen == OrigenDevolucionProveedor.Recibido))
            .WithMessage("Elige de qué almacén sale lo que ya había llegado");
    }
}

public class CobrarSaldoProveedorRequestValidator : AbstractValidator<CobrarSaldoProveedorRequest>
{
    public CobrarSaldoProveedorRequestValidator()
    {
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto debe ser mayor que cero");
        RuleFor(x => x.MetodoPagoId).GreaterThan(0).WithMessage("Elige con qué devolvió la plata");
        RuleFor(x => x.Observacion).MaximumLength(250);
    }
}

public class AplicarSaldoProveedorRequestValidator : AbstractValidator<AplicarSaldoProveedorRequest>
{
    public AplicarSaldoProveedorRequestValidator()
    {
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto debe ser mayor que cero");
    }
}
