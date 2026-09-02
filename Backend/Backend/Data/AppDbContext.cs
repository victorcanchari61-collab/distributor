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
    public DbSet<Categoria> Categorias => Set<Categoria>();
    public DbSet<Marca> Marcas => Set<Marca>();
    public DbSet<UnidadMedida> UnidadesMedida => Set<UnidadMedida>();
    public DbSet<Producto> Productos => Set<Producto>();
    public DbSet<ProductoPresentacion> Presentaciones => Set<ProductoPresentacion>();
    public DbSet<ListaPrecio> ListasPrecio => Set<ListaPrecio>();
    public DbSet<PrecioProducto> Precios => Set<PrecioProducto>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        ConfigurarCatalogo(modelBuilder);

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
            entity.Property(u => u.Dni).HasMaxLength(8);

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
            entity.Property(e => e.Departamento).HasMaxLength(60);
            entity.Property(e => e.Provincia).HasMaxLength(60);
            entity.Property(e => e.Distrito).HasMaxLength(60);
            entity.Property(e => e.Telefono).HasMaxLength(20);
            entity.Property(e => e.Email).HasMaxLength(100);
            entity.Property(e => e.SitioWeb).HasMaxLength(150);
            entity.Property(e => e.RepresentanteLegal).HasMaxLength(150);
            entity.Property(e => e.Habilitada).HasDefaultValue(true);

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
            entity.HasIndex(c => c.Documento).IsUnique();
            entity.Property(c => c.Documento).HasMaxLength(15).IsRequired();
            entity.Property(c => c.TipoDoc).HasMaxLength(10).IsRequired();
            entity.Property(c => c.Nombre).HasMaxLength(150).IsRequired();
            entity.Property(c => c.Direccion).HasMaxLength(250);
            entity.Property(c => c.Distrito).HasMaxLength(80);
            entity.Property(c => c.Telefono).HasMaxLength(40);
            entity.Property(c => c.Email).HasMaxLength(100);
            entity.Property(c => c.DiaVisita).HasMaxLength(20);
            entity.Property(c => c.Ruta).HasMaxLength(20);
            entity.Property(c => c.Mercado).HasMaxLength(80);
        });

        modelBuilder.Entity<Proveedor>(entity =>
        {
            entity.ToTable("Proveedores");
            entity.HasIndex(p => p.Documento).IsUnique();
            entity.Property(p => p.Documento).HasMaxLength(15).IsRequired();
            entity.Property(p => p.TipoDoc).HasMaxLength(10).IsRequired();
            entity.Property(p => p.Nombre).HasMaxLength(200).IsRequired();
            entity.Property(p => p.NombreComercial).HasMaxLength(150);
            entity.Property(p => p.Direccion).HasMaxLength(250);
            entity.Property(p => p.Departamento).HasMaxLength(80);
            entity.Property(p => p.Distrito).HasMaxLength(80);
            entity.Property(p => p.Telefono).HasMaxLength(40);
            entity.Property(p => p.Telefono2).HasMaxLength(40);
            entity.Property(p => p.Email).HasMaxLength(100);
            entity.Property(p => p.Rubro).HasMaxLength(120);
        });
    }

    /// <summary>
    /// Productos y lo que cuelga de ellos.
    ///
    /// Los decimales van con 18,4: cuatro decimales alcanzan para vender 2.5
    /// kilos y para que el precio por unidad base del saco (195 / 50 = 3.9)
    /// no se redondee de mas.
    /// </summary>
    private static void ConfigurarCatalogo(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Categoria>(entity =>
        {
            entity.ToTable("Categorias");
            entity.HasIndex(c => c.Nombre).IsUnique();
            entity.Property(c => c.Nombre).HasMaxLength(80).IsRequired();
            entity.Property(c => c.Descripcion).HasMaxLength(250);
        });

        modelBuilder.Entity<Marca>(entity =>
        {
            entity.ToTable("Marcas");
            entity.HasIndex(m => m.Nombre).IsUnique();
            entity.Property(m => m.Nombre).HasMaxLength(80).IsRequired();
        });

        modelBuilder.Entity<UnidadMedida>(entity =>
        {
            entity.ToTable("UnidadesMedida");
            entity.HasIndex(u => u.Codigo).IsUnique();
            entity.Property(u => u.Codigo).HasMaxLength(10).IsRequired();
            entity.Property(u => u.Nombre).HasMaxLength(60).IsRequired();
            entity.Property(u => u.Tipo).HasMaxLength(10).IsRequired();

            // Unidades base del negocio. Vienen sembradas porque sin ellas no
            // se puede dar de alta ningun producto.
            var creacion = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            entity.HasData(
                Sembrar(1, "UND", "Unidad", TipoUnidad.Conteo, false, creacion),
                Sembrar(2, "KG", "Kilogramo", TipoUnidad.Peso, true, creacion),
                Sembrar(3, "G", "Gramo", TipoUnidad.Peso, true, creacion),
                Sembrar(4, "LT", "Litro", TipoUnidad.Volumen, true, creacion),
                Sembrar(5, "ML", "Mililitro", TipoUnidad.Volumen, false, creacion),
                Sembrar(6, "SAC", "Saco", TipoUnidad.Conteo, false, creacion),
                Sembrar(7, "CJA", "Caja", TipoUnidad.Conteo, false, creacion),
                Sembrar(8, "BOL", "Bolsa", TipoUnidad.Conteo, false, creacion),
                Sembrar(9, "PAQ", "Paquete", TipoUnidad.Conteo, false, creacion),
                Sembrar(10, "DOC", "Docena", TipoUnidad.Conteo, false, creacion));
        });

        modelBuilder.Entity<Producto>(entity =>
        {
            entity.ToTable("Productos");
            entity.HasIndex(p => p.Codigo).IsUnique();
            entity.Property(p => p.Codigo).HasMaxLength(30).IsRequired();
            entity.Property(p => p.Nombre).HasMaxLength(150).IsRequired();
            entity.Property(p => p.Descripcion).HasMaxLength(500);
            entity.Property(p => p.Contenido).HasPrecision(18, 4);
            entity.Property(p => p.StockMinimo).HasPrecision(18, 4);
            entity.Property(p => p.CostoReferencia).HasPrecision(18, 4);

            // Restrict: borrar una categoria o una unidad no puede llevarse
            // productos por delante. El servicio ya avisa antes.
            entity.HasOne(p => p.Categoria)
                .WithMany()
                .HasForeignKey(p => p.CategoriaId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.Marca)
                .WithMany()
                .HasForeignKey(p => p.MarcaId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.UnidadBase)
                .WithMany()
                .HasForeignKey(p => p.UnidadBaseId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.ContenidoUnidad)
                .WithMany()
                .HasForeignKey(p => p.ContenidoUnidadId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ProductoPresentacion>(entity =>
        {
            entity.ToTable("ProductoPresentaciones");
            entity.Property(p => p.Nombre).HasMaxLength(80).IsRequired();
            entity.Property(p => p.Factor).HasPrecision(18, 4);
            entity.Property(p => p.CodigoBarras).HasMaxLength(40);

            // Un producto no repite factor: dos presentaciones de 50 kg serian
            // la misma cosa escrita dos veces.
            entity.HasIndex(p => new { p.ProductoId, p.Factor }).IsUnique();

            // Cascade: las presentaciones no tienen vida propia fuera de su
            // producto.
            entity.HasOne(p => p.Producto)
                .WithMany(pr => pr.Presentaciones)
                .HasForeignKey(p => p.ProductoId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(p => p.Unidad)
                .WithMany()
                .HasForeignKey(p => p.UnidadId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ListaPrecio>(entity =>
        {
            entity.ToTable("ListasPrecio");
            entity.HasIndex(l => l.Nombre).IsUnique();
            entity.Property(l => l.Nombre).HasMaxLength(80).IsRequired();
            entity.Property(l => l.Descripcion).HasMaxLength(250);
        });

        modelBuilder.Entity<PrecioProducto>(entity =>
        {
            entity.ToTable("Precios");
            entity.Property(p => p.Precio).HasPrecision(18, 4);
            entity.Property(p => p.CantidadMinima).HasPrecision(18, 4);

            // Una presentacion tiene un solo precio por escalon dentro de una
            // lista.
            entity.HasIndex(p => new { p.ListaPrecioId, p.PresentacionId, p.CantidadMinima })
                .IsUnique();

            entity.HasOne(p => p.ListaPrecio)
                .WithMany(l => l.Precios)
                .HasForeignKey(p => p.ListaPrecioId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(p => p.Presentacion)
                .WithMany()
                .HasForeignKey(p => p.PresentacionId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }

    private static UnidadMedida Sembrar(
        int id, string codigo, string nombre, string tipo, bool fraccionable, DateTime creacion) =>
        new()
        {
            Id = id,
            Codigo = codigo,
            Nombre = nombre,
            Tipo = tipo,
            Fraccionable = fraccionable,
            Activo = true,
            DelSistema = true,
            FechaCreacion = creacion
        };
}
