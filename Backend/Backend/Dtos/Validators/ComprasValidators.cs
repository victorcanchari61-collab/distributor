using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class LineaCompraRequestValidator : AbstractValidator<LineaCompraRequest>
{
    public LineaCompraRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
        RuleFor(x => x.CostoPresentacion)
            .GreaterThan(0).WithMessage("Indica el costo pactado con el proveedor");
    }
}

public class CrearOrdenCompraRequestValidator : AbstractValidator<CrearOrdenCompraRequest>
{
    public CrearOrdenCompraRequestValidator()
    {
        RuleFor(x => x.ProveedorId).GreaterThan(0).WithMessage("Elige el proveedor");
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaCompraRequestValidator());
    }
}

public class CrearCompraRequestValidator : AbstractValidator<CrearCompraRequest>
{
    public CrearCompraRequestValidator()
    {
        RuleFor(x => x.ProveedorId).GreaterThan(0).WithMessage("Elige el proveedor");

        RuleFor(x => x.TipoComprobante)
            .Must(t => string.IsNullOrWhiteSpace(t) || TipoComprobanteCompra.Todos.Contains(t))
            .WithMessage("Tipo de comprobante inválido");
        RuleFor(x => x.SerieComprobante).MaximumLength(10);
        RuleFor(x => x.NumeroComprobante).MaximumLength(20);
        RuleFor(x => x.FormaPago)
            .Must(f => string.IsNullOrWhiteSpace(f) || FormaPagoCompra.Todas.Contains(f))
            .WithMessage("Forma de pago inválida");
        RuleFor(x => x.InstrumentoPago)
            .Must(i => string.IsNullOrWhiteSpace(i) || InstrumentoPagoCompra.Todos.Contains(i))
            .WithMessage("Instrumento de pago inválido");

        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaCompraRequestValidator());
    }
}

public class LineaRecepcionRequestValidator : AbstractValidator<LineaRecepcionRequest>
{
    public LineaRecepcionRequestValidator()
    {
        RuleFor(x => x.CompraDetalleId).GreaterThan(0).WithMessage("Elige la línea a recibir");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
    }
}

public class CrearRecepcionRequestValidator : AbstractValidator<CrearRecepcionRequest>
{
    public CrearRecepcionRequestValidator()
    {
        RuleFor(x => x.CompraId).GreaterThan(0).WithMessage("Elige la compra");
        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén");
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Indica qué llegó");
        RuleForEach(x => x.Detalle).SetValidator(new LineaRecepcionRequestValidator());
    }
}
