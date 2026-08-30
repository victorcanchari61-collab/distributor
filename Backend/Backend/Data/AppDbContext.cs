using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<Cliente> Clientes => Set<Cliente>();
    public DbSet<Proveedor> Proveedores => Set<Proveedor>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.ToTable("Usuarios");
            entity.HasIndex(u => u.Email).IsUnique();
            entity.Property(u => u.Nombre).HasMaxLength(100).IsRequired();
            entity.Property(u => u.Email).HasMaxLength(100).IsRequired();
            entity.Property(u => u.PasswordHash).HasMaxLength(256).IsRequired();
            entity.Property(u => u.Role).HasConversion<int>().IsRequired();
        });

        modelBuilder.Entity<Cliente>(entity =>
        {
            entity.ToTable("Clientes");
            entity.HasIndex(c => c.Ruc).IsUnique();
            entity.Property(c => c.Nombre).HasMaxLength(150).IsRequired();
            entity.Property(c => c.Ruc).HasMaxLength(11).IsRequired();
            entity.Property(c => c.Direccion).HasMaxLength(250);
            entity.Property(c => c.Telefono).HasMaxLength(20);
            entity.Property(c => c.Email).HasMaxLength(100);
        });

        modelBuilder.Entity<Proveedor>(entity =>
        {
            entity.ToTable("Proveedores");
            entity.HasIndex(p => p.Ruc).IsUnique();
            entity.Property(p => p.Nombre).HasMaxLength(150).IsRequired();
            entity.Property(p => p.Ruc).HasMaxLength(11).IsRequired();
            entity.Property(p => p.Direccion).HasMaxLength(250);
            entity.Property(p => p.Telefono).HasMaxLength(20);
            entity.Property(p => p.Email).HasMaxLength(100);
        });
    }
}
