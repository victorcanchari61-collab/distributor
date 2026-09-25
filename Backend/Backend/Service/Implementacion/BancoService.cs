using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

public class BancoService : IBancoService
{
    private readonly AppDbContext _context;
    private readonly IValidator<BancoRequest> _validator;
    private readonly INotificador _notificador;

    public BancoService(AppDbContext context, IValidator<BancoRequest> validator, INotificador notificador)
    {
        _context = context;
        _validator = validator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<BancoResponse>> GetAllAsync()
    {
        var bancos = await _context.Bancos
            .AsNoTracking()
            .OrderByDescending(b => b.Activo)
            .ThenBy(b => b.Nombre)
            .ToListAsync();

        var cuentasPorBanco = await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.BancoId != null)
            .GroupBy(c => c.BancoId!.Value)
            .Select(g => new { BancoId = g.Key, Cantidad = g.Count() })
            .ToListAsync();

        return bancos.Select(b => Map(b, cuentasPorBanco.FirstOrDefault(c => c.BancoId == b.Id)?.Cantidad ?? 0));
    }

    public async Task<BancoResponse> CreateAsync(BancoRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        if (await _context.Bancos.AnyAsync(b => b.Nombre == request.Nombre.Trim()))
        {
            throw new ConflictException("Ya existe un banco con ese nombre");
        }

        var banco = new Banco { Nombre = request.Nombre.Trim(), Activo = request.Activo };
        _context.Bancos.Add(banco);
        await _context.SaveChangesAsync();

        var response = Map(banco, 0);
        await _notificador.AvisarAsync("bancos", "creado", response);
        return response;
    }

    public async Task<BancoResponse> UpdateAsync(int id, BancoRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        var banco = await _context.Bancos.FirstOrDefaultAsync(b => b.Id == id)
            ?? throw new NotFoundException($"No existe el banco {id}");

        if (await _context.Bancos.AnyAsync(b => b.Nombre == request.Nombre.Trim() && b.Id != id))
        {
            throw new ConflictException("Ya existe un banco con ese nombre");
        }

        banco.Nombre = request.Nombre.Trim();
        banco.Activo = request.Activo;
        await _context.SaveChangesAsync();

        var cantidad = await _context.CuentasFinancieras.CountAsync(c => c.BancoId == id);
        var response = Map(banco, cantidad);
        await _notificador.AvisarAsync("bancos", "actualizado", response);
        return response;
    }

    private static BancoResponse Map(Banco b, int cantidadCuentas) => new()
    {
        Id = b.Id,
        Nombre = b.Nombre,
        Activo = b.Activo,
        FechaCreacion = b.FechaCreacion,
        CantidadCuentas = cantidadCuentas,
    };
}
