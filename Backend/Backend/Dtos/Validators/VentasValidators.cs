using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class LineaVentaRequestValidator : AbstractValidator<LineaVentaRequest>
{
    public LineaVentaRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
        RuleFor(x => x.PrecioUnitario).GreaterThan(0).WithMessage("Indica el precio de venta");
    }
}

public class CrearPedidoRequestValidator : AbstractValidator<CrearPedidoRequest>
{
    public CrearPedidoRequestValidator()
    {
        // Lo mismo que en la venta: o es una de las dos, o no es nada.
        RuleFor(x => x.CondicionPago)
            .Must(f => string.IsNullOrWhiteSpace(f) || FormaPagoVenta.Todas.Contains(f))
            .WithMessage("La condición de pago debe ser CONTADO o CREDITO");

        RuleFor(x => x.ClienteId).GreaterThan(0).WithMessage("Elige el cliente");
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.AlmacenId)
            .NotNull().GreaterThan(0)
            .When(x => x.ReservaStock)
            .WithMessage("Elige el almacén para reservar el stock");
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaVentaRequestValidator());
    }
}

public class PagoVentaRequestValidator : AbstractValidator<PagoVentaRequest>
{
    public PagoVentaRequestValidator()
    {
        RuleFor(x => x.MetodoPagoId).GreaterThan(0).WithMessage("Elige el método de pago");
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto debe ser mayor que cero");
    }
}

public class ConfirmarPedidoRequestValidator : AbstractValidator<ConfirmarPedidoRequest>
{
    public ConfirmarPedidoRequestValidator()
    {
        // Vacio se admite: el servicio usa el almacen de la reserva. Si viene,
        // tiene que ser uno de verdad.
        RuleFor(x => x.AlmacenId)
            .GreaterThan(0).When(x => x.AlmacenId.HasValue)
            .WithMessage("Elige el almacén");

        RuleForEach(x => x.Lineas).ChildRules(l =>
        {
            l.RuleFor(x => x.PedidoDetalleId).GreaterThan(0).WithMessage("Línea inválida");
            l.RuleFor(x => x.Cantidad).GreaterThanOrEqualTo(0).WithMessage("La cantidad no puede ser negativa");
            l.RuleFor(x => x.Observacion).MaximumLength(250).WithMessage("La observación es muy larga (máx. 250)");
        });
    }
}

public class NoEntregadoRequestValidator : AbstractValidator<NoEntregadoRequest>
{
    public NoEntregadoRequestValidator()
    {
        RuleFor(x => x.MotivoId).GreaterThan(0).WithMessage("Elige el motivo por el que no se entregó");
        RuleFor(x => x.Observacion).MaximumLength(250).WithMessage("La observación es muy larga (máx. 250)");
    }
}

public class CrearNotaVentaRequestValidator : AbstractValidator<CrearNotaVentaRequest>
{
    public CrearNotaVentaRequestValidator()
    {
        RuleFor(x => x.ClienteId).GreaterThan(0).WithMessage("Elige el cliente");
        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén");
        RuleFor(x => x.FormaPago)
            .Must(f => string.IsNullOrWhiteSpace(f) || FormaPagoVenta.Todas.Contains(f))
            .WithMessage("Forma de pago inválida");
        RuleForEach(x => x.Pagos).SetValidator(new PagoVentaRequestValidator());

        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaVentaRequestValidator());
    }
}
