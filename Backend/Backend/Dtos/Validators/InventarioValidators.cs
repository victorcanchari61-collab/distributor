using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class AlmacenValidator<T> : AbstractValidator<T> where T : AlmacenRequestBase
{
    public AlmacenValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().MaximumLength(15);
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Direccion).MaximumLength(250);
    }
}

public class CreateAlmacenRequestValidator : AlmacenValidator<CreateAlmacenRequest>;

public class UpdateAlmacenRequestValidator : AlmacenValidator<UpdateAlmacenRequest>;

public class MotivoValidator<T> : AbstractValidator<T> where T : MotivoRequestBase
{
    public MotivoValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().MaximumLength(25);
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Tipo)
            .Must(t => TipoMovimiento.Todos.Contains(t))
            .WithMessage("El tipo debe ser ENTRADA o SALIDA");
    }
}

public class CreateMotivoRequestValidator : MotivoValidator<CreateMotivoRequest>;

public class UpdateMotivoRequestValidator : MotivoValidator<UpdateMotivoRequest>;

public class LineaAjusteRequestValidator : AbstractValidator<LineaAjusteRequest>
{
    public LineaAjusteRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");

        // Siempre positiva: restar se logra con un motivo de salida, no con un
        // numero negativo. Permitirlos deja "correcciones" imposibles de leer.
        RuleFor(x => x.Cantidad)
            .GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");

        RuleFor(x => x.CostoPresentacion)
            .GreaterThanOrEqualTo(0).When(x => x.CostoPresentacion.HasValue)
            .WithMessage("El costo no puede ser negativo");
    }
}

public class CrearAjusteRequestValidator : AbstractValidator<CrearAjusteRequest>
{
    public CrearAjusteRequestValidator()
    {
        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén");
        RuleFor(x => x.MotivoId).GreaterThan(0).WithMessage("Elige el motivo");
        RuleFor(x => x.Observacion).MaximumLength(250);

        RuleFor(x => x.Flete)
            .GreaterThanOrEqualTo(0).WithMessage("El flete no puede ser negativo");

        RuleFor(x => x.Detalle)
            .NotEmpty().WithMessage("Agrega al menos un producto");

        RuleForEach(x => x.Detalle).SetValidator(new LineaAjusteRequestValidator());
    }
}

public class LineaTransferenciaRequestValidator : AbstractValidator<LineaTransferenciaRequest>
{
    public LineaTransferenciaRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
    }
}

public class CrearTransferenciaRequestValidator : AbstractValidator<CrearTransferenciaRequest>
{
    public CrearTransferenciaRequestValidator()
    {
        RuleFor(x => x.AlmacenOrigenId).GreaterThan(0).WithMessage("Elige el almacén de origen");

        // Sin esto "transferir" no mueve nada: sale y entra al mismo lugar.
        RuleFor(x => x.AlmacenDestinoId)
            .GreaterThan(0).WithMessage("Elige el almacén de destino")
            .NotEqual(x => x.AlmacenOrigenId)
            .WithMessage("El origen y el destino no pueden ser el mismo almacén");

        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaTransferenciaRequestValidator());
    }
}

public class LineaPrestamoRequestValidator : AbstractValidator<LineaPrestamoRequest>
{
    public LineaPrestamoRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");

        RuleFor(x => x.CostoPresentacion)
            .GreaterThanOrEqualTo(0).When(x => x.CostoPresentacion.HasValue)
            .WithMessage("El costo no puede ser negativo");
    }
}

public class CrearPrestamoRequestValidator : AbstractValidator<CrearPrestamoRequest>
{
    public CrearPrestamoRequestValidator()
    {
        RuleFor(x => x.Tipo)
            .Must(t => TipoPrestamo.Todos.Contains(t))
            .WithMessage("El tipo debe ser DADO o RECIBIDO");

        RuleFor(x => x.Contraparte)
            .NotEmpty().WithMessage("Indica a quién le prestas o quién te presta")
            .MaximumLength(150);

        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén");
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaPrestamoRequestValidator());
    }
}

public class LineaDevolucionPrestamoRequestValidator : AbstractValidator<LineaDevolucionPrestamoRequest>
{
    public LineaDevolucionPrestamoRequestValidator()
    {
        RuleFor(x => x.PrestamoDetalleId).GreaterThan(0).WithMessage("Elige la línea a devolver");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
    }
}

public class DevolverPrestamoRequestValidator : AbstractValidator<DevolverPrestamoRequest>
{
    public DevolverPrestamoRequestValidator()
    {
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Indica qué se devuelve");
        RuleForEach(x => x.Detalle).SetValidator(new LineaDevolucionPrestamoRequestValidator());
    }
}
