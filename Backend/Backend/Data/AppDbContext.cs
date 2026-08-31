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
    public DbSet<Empresa> Empresas => Set<Empresa>();
    public DbSet<Rol> Roles => Set<Rol>();
    public DbSet<RolPermiso> RolPermisos => Set<RolPermiso>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Rol>(entity =>
        {
            entity.ToTable("Roles");
            entity.HasIndex(r => r.Nombre).IsUnique();
            entity.Property(r => r.Nombre).HasMaxLength(60).IsRequired();
            entity.Property(r => r.Descripcion).HasMaxLength(250);

            // Los tres roles base conservan los ids del antiguo enum Role
            // (1 Administrador, 2 Vendedor, 3 Almacenero), asi los usuarios
            // que ya existen quedan apuntando al rol correcto sin remapear.
            entity.HasData(
                new Rol
                {
                    Id = 1,
                    Nombre = "Administrador",
                    Descripcion = "Acceso total: configura el sistema, crea usuarios y ve todos los módulos.",
                    Activo = true,
                    DelSistema = true,
                    FechaCreacion = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                },
                new Rol
                {
                    Id = 2,
                    Nombre = "Vendedor",
                    Descripcion = "Trabaja con clientes, pedidos y cobranzas de su cartera.",
                    Activo = true,
                    DelSistema = true,
                    FechaCreacion = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                },
                new Rol
                {
                    Id = 3,
                    Nombre = "Almacenero",
                    Descripcion = "Opera inventario: recepciones, movimientos y conteos de su almacén.",
                    Activo = true,
                    DelSistema = true,
                    FechaCreacion = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                });
        });

        modelBuilder.Entity<RolPermiso>(entity =>
        {
            entity.ToTable("RolPermisos");
            entity.Property(p => p.Modulo).HasMaxLength(40).IsRequired();

            // Un rol tiene como mucho una fila por modulo.
            entity.HasIndex(p => new { p.RolId, p.Modulo }).IsUnique();

            entity.HasOne(p => p.Rol)
                .WithMany(r => r.Permisos)
                .HasForeignKey(p => p.RolId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.ToTable("Usuarios");
            entity.HasIndex(u => u.Email).IsUnique();
            entity.Property(u => u.Nombre).HasMaxLength(100).IsRequired();
            entity.Property(u => u.Email).HasMaxLength(100).IsRequired();
            entity.Property(u => u.PasswordHash).HasMaxLength(256).IsRequired();

            // Restrict: no se borra un rol que tenga usuarios detras.
            entity.HasOne(u => u.Rol)
                .WithMany(r => r.Usuarios)
                .HasForeignKey(u => u.RolId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Empresa>(entity =>
        {
            entity.ToTable("Empresas");
            entity.HasIndex(e => e.Ruc).IsUnique();
            entity.Property(e => e.RazonSocial).HasMaxLength(200).IsRequired();
            entity.Property(e => e.NombreComercial).HasMaxLength(150).IsRequired();
            entity.Property(e => e.Ruc).HasMaxLength(11).IsRequired();
            entity.Property(e => e.Direccion).HasMaxLength(250);
            entity.Property(e => e.Telefono).HasMaxLength(20);
            entity.Property(e => e.Email).HasMaxLength(100);

            // Solo una empresa puede estar activa, garantizado en base de datos.
            // MySQL no tiene indices parciales, asi que se usa una columna
            // calculada que vale 1 cuando la empresa esta activa y NULL cuando
            // no: un indice unico admite tantos NULL como haga falta, pero un
            // solo 1.
            entity.Property<bool?>("ActivaUnica")
                .HasComputedColumnSql("CASE WHEN `Activa` = 1 THEN 1 END", stored: true);
            entity.HasIndex("ActivaUnica").IsUnique();
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
