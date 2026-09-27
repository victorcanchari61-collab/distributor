using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CuentaFinancieraRequestValidator : AbstractValidator<CuentaFinancieraRequest>
{
    public CuentaFinancieraRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Ponle un nombre a la cuenta").MaximumLength(100);

        RuleFor(x => x.Naturaleza)
            .Must(n => NaturalezaCuenta.Todas.Contains(n))
            .WithMessage("La naturaleza debe ser CAJA, BANCO o PASARELA");

        RuleFor(x => x.UsuarioResponsableId)
            .NotNull().WithMessage("Elige a quién se le asigna esta caja")
            .When(x => x.Naturaleza == NaturalezaCuenta.Caja);

        RuleFor(x => x.BancoId)
            .NotNull().WithMessage("Elige a qué banco pertenece")
            .When(x => x.Naturaleza == NaturalezaCuenta.Banco);

        RuleFor(x => x.NumeroCuenta)
            .NotEmpty().WithMessage("Indica el número de cuenta")
            .When(x => x.Naturaleza is NaturalezaCuenta.Banco or NaturalezaCuenta.Pasarela);

        RuleFor(x => x.MontoInicial).GreaterThanOrEqualTo(0).WithMessage("El monto inicial no puede ser negativo");

        RuleFor(x => x.NumeroCuenta).MaximumLength(30);
        RuleFor(x => x.Cci).MaximumLength(30);
        RuleFor(x => x.Titular).MaximumLength(120);
    }
}

public class CrearBovedaRequestValidator : AbstractValidator<CrearBovedaRequest>
{
    public CrearBovedaRequestValidator()
    {
        RuleFor(x => x.MontoInicial).GreaterThanOrEqualTo(0).WithMessage("El monto inicial no puede ser negativo");
    }
}

public class TransferenciaCuentasRequestValidator : AbstractValidator<TransferenciaCuentasRequest>
{
    public TransferenciaCuentasRequestValidator()
    {
        RuleFor(x => x.CuentaOrigenId).GreaterThan(0).WithMessage("Elige de dónde sale la plata");
        RuleFor(x => x.CuentaDestinoId).GreaterThan(0).WithMessage("Elige a dónde va la plata");
        RuleFor(x => x.CuentaDestinoId)
            .NotEqual(x => x.CuentaOrigenId).WithMessage("El origen y el destino no pueden ser la misma cuenta");
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto tiene que ser mayor a cero")
            .PrecisionScale(18, 2, true).WithMessage("El monto va con dos decimales como mucho");
        RuleFor(x => x.Observacion).MaximumLength(250);
    }
}
