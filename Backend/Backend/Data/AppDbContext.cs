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
    public DbSet<Almacen> Almacenes => Set<Almacen>();
    public DbSet<MotivoMovimiento> MotivosMovimiento => Set<MotivoMovimiento>();
    public DbSet<DocumentoInventario> DocumentosInventario => Set<DocumentoInventario>();
    public DbSet<MovimientoInventario> Movimientos => Set<MovimientoInventario>();
    public DbSet<CapaCosto> CapasCosto => Set<CapaCosto>();
    public DbSet<ConsumoCapa> Consumos => Set<ConsumoCapa>();
    public DbSet<Prestamo> Prestamos => Set<Prestamo>();
    public DbSet<PrestamoDetalle> PrestamoDetalles => Set<PrestamoDetalle>();
    public DbSet<OrdenCompra> OrdenesCompra => Set<OrdenCompra>();
    public DbSet<OrdenCompraDetalle> OrdenCompraDetalles => Set<OrdenCompraDetalle>();
    public DbSet<Compra> Compras => Set<Compra>();
    public DbSet<CompraDetalle> CompraDetalles => Set<CompraDetalle>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        ConfigurarCatalogo(modelBuilder);
        ConfigurarInventario(modelBuilder);
        ConfigurarCompras(modelBuilder);

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

    /// <summary>
    /// Inventario: almacenes, motivos, documentos, movimientos y capas.
    ///
    /// Los motivos del sistema van sembrados con ids fijos: los usa cada
    /// documento que mueve stock, asi que no se crean ni se borran desde la
    /// pantalla.
    /// </summary>
    private static void ConfigurarInventario(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Almacen>(entity =>
        {
            entity.ToTable("Almacenes");
            entity.HasIndex(a => a.Codigo).IsUnique();
            entity.Property(a => a.Codigo).HasMaxLength(15).IsRequired();
            entity.Property(a => a.Nombre).HasMaxLength(80).IsRequired();
            entity.Property(a => a.Direccion).HasMaxLength(250);

            entity.HasData(new Almacen
            {
                Id = 1,
                Codigo = "PRIN",
                Nombre = "Almacén principal",
                EsPrincipal = true,
                Activo = true,
                FechaCreacion = Semilla
            });
        });

        modelBuilder.Entity<MotivoMovimiento>(entity =>
        {
            entity.ToTable("MotivosMovimiento");
            entity.HasIndex(m => m.Codigo).IsUnique();
            entity.Property(m => m.Codigo).HasMaxLength(25).IsRequired();
            entity.Property(m => m.Nombre).HasMaxLength(80).IsRequired();
            entity.Property(m => m.Tipo).HasMaxLength(10).IsRequired();

            entity.HasData(
                // Manuales: los unicos elegibles en un ajuste.
                Motivo(Motivos.CargaInicial, "CARGA_INICIAL", "Carga inicial", TipoMovimiento.Entrada, sistema: false),
                Motivo(Motivos.SobranteConteo, "SOBRANTE", "Sobrante de conteo", TipoMovimiento.Entrada, sistema: false),
                Motivo(Motivos.FaltanteConteo, "FALTANTE", "Faltante de conteo", TipoMovimiento.Salida, sistema: false),
                Motivo(Motivos.Merma, "MERMA", "Merma", TipoMovimiento.Salida, sistema: false),
                Motivo(Motivos.Rotura, "ROTURA", "Rotura", TipoMovimiento.Salida, sistema: false),
                Motivo(Motivos.Vencimiento, "VENCIMIENTO", "Vencimiento", TipoMovimiento.Salida, sistema: false),

                // Prestamos: los genera la pantalla de Prestamos, no un ajuste
                // a mano, porque llevan contraparte y estado de devolucion.
                Motivo(Motivos.PrestamoDado, "PRESTAMO_DADO", "Préstamo dado", TipoMovimiento.Salida, sistema: true),
                Motivo(Motivos.DevolucionPrestamoDado, "DEV_PRESTAMO_DADO", "Devolución de préstamo dado", TipoMovimiento.Entrada, sistema: true),
                Motivo(Motivos.PrestamoRecibido, "PRESTAMO_RECIBIDO", "Préstamo recibido", TipoMovimiento.Entrada, sistema: true),
                Motivo(Motivos.DevolucionPrestamoRecibido, "DEV_PRESTAMO_RECIBIDO", "Devolución de préstamo recibido", TipoMovimiento.Salida, sistema: true),

                // Del sistema: los crea un documento, no se eligen a mano.
                Motivo(Motivos.Compra, "COMPRA", "Recepción de compra", TipoMovimiento.Entrada, sistema: true),
                Motivo(Motivos.CompraAnulada, "COMPRA_ANULADA", "Compra anulada", TipoMovimiento.Salida, sistema: true),
                Motivo(Motivos.Venta, "VENTA", "Venta", TipoMovimiento.Salida, sistema: true),
                Motivo(Motivos.VentaAnulada, "VENTA_ANULADA", "Venta anulada", TipoMovimiento.Entrada, sistema: true),
                Motivo(Motivos.DevolucionProveedor, "DEV_PROVEEDOR", "Devolución a proveedor", TipoMovimiento.Salida, sistema: true),
                Motivo(Motivos.TransferenciaSalida, "TRANSF_SALIDA", "Transferencia — salida", TipoMovimiento.Salida, sistema: true),
                Motivo(Motivos.TransferenciaIngreso, "TRANSF_INGRESO", "Transferencia — ingreso", TipoMovimiento.Entrada, sistema: true));
        });

        modelBuilder.Entity<DocumentoInventario>(entity =>
        {
            entity.ToTable("DocumentosInventario");
            entity.HasIndex(d => d.Numero).IsUnique();
            entity.Property(d => d.Numero).HasMaxLength(20).IsRequired();
            entity.Property(d => d.Tipo).HasMaxLength(25).IsRequired();
            entity.Property(d => d.Estado).HasMaxLength(15).IsRequired();
            entity.Property(d => d.Observacion).HasMaxLength(250);

            entity.HasOne(d => d.Almacen).WithMany()
                .HasForeignKey(d => d.AlmacenId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.AlmacenDestino).WithMany()
                .HasForeignKey(d => d.AlmacenDestinoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Motivo).WithMany()
                .HasForeignKey(d => d.MotivoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Usuario).WithMany()
                .HasForeignKey(d => d.UsuarioId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(d => d.DocumentoAnulado).WithMany()
                .HasForeignKey(d => d.DocumentoAnuladoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Compra).WithMany()
                .HasForeignKey(d => d.CompraId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<MovimientoInventario>(entity =>
        {
            entity.ToTable("MovimientosInventario");
            entity.Property(m => m.Tipo).HasMaxLength(10).IsRequired();
            entity.Property(m => m.CantidadPresentacion).HasPrecision(18, 4);
            entity.Property(m => m.Cantidad).HasPrecision(18, 4);
            entity.Property(m => m.CostoUnitario).HasPrecision(18, 4);
            entity.Property(m => m.CostoTotal).HasPrecision(18, 4);

            // El kardex siempre pregunta lo mismo: que paso con este producto
            // en este almacen, ordenado por fecha.
            entity.HasIndex(m => new { m.ProductoId, m.AlmacenId, m.Fecha });

            entity.HasOne(m => m.Documento).WithMany(d => d.Movimientos)
                .HasForeignKey(m => m.DocumentoId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(m => m.Producto).WithMany()
                .HasForeignKey(m => m.ProductoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(m => m.Almacen).WithMany()
                .HasForeignKey(m => m.AlmacenId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(m => m.Motivo).WithMany()
                .HasForeignKey(m => m.MotivoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(m => m.Presentacion).WithMany()
                .HasForeignKey(m => m.PresentacionId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(m => m.CompraDetalle).WithMany()
                .HasForeignKey(m => m.CompraDetalleId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CapaCosto>(entity =>
        {
            entity.ToTable("CapasCosto");
            entity.Property(c => c.CantidadInicial).HasPrecision(18, 4);
            entity.Property(c => c.CantidadDisponible).HasPrecision(18, 4);
            entity.Property(c => c.CostoUnitario).HasPrecision(18, 4);
            entity.Property(c => c.Origen).HasMaxLength(20).IsRequired();

            // Las salidas buscan capas con mercaderia de un producto en un
            // almacen, por fecha.
            entity.HasIndex(c => new { c.ProductoId, c.AlmacenId, c.Fecha });

            entity.HasOne(c => c.Producto).WithMany()
                .HasForeignKey(c => c.ProductoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(c => c.Almacen).WithMany()
                .HasForeignKey(c => c.AlmacenId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(c => c.Movimiento).WithMany()
                .HasForeignKey(c => c.MovimientoId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ConsumoCapa>(entity =>
        {
            entity.ToTable("ConsumosCapa");
            entity.Property(c => c.Cantidad).HasPrecision(18, 4);
            entity.Property(c => c.CostoUnitario).HasPrecision(18, 4);

            entity.HasOne(c => c.Movimiento).WithMany(m => m.Consumos)
                .HasForeignKey(c => c.MovimientoId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(c => c.Capa).WithMany()
                .HasForeignKey(c => c.CapaId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Prestamo>(entity =>
        {
            entity.ToTable("Prestamos");
            entity.HasIndex(p => p.Numero).IsUnique();
            entity.Property(p => p.Numero).HasMaxLength(20).IsRequired();
            entity.Property(p => p.Tipo).HasMaxLength(10).IsRequired();
            entity.Property(p => p.Contraparte).HasMaxLength(150).IsRequired();
            entity.Property(p => p.Estado).HasMaxLength(15).IsRequired();
            entity.Property(p => p.Observacion).HasMaxLength(250);

            entity.HasOne(p => p.Almacen).WithMany()
                .HasForeignKey(p => p.AlmacenId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(p => p.Usuario).WithMany()
                .HasForeignKey(p => p.UsuarioId).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<PrestamoDetalle>(entity =>
        {
            entity.ToTable("PrestamoDetalle");
            entity.Property(d => d.CantidadPresentacion).HasPrecision(18, 4);
            entity.Property(d => d.Cantidad).HasPrecision(18, 4);
            entity.Property(d => d.CantidadDevuelta).HasPrecision(18, 4);

            entity.HasOne(d => d.Prestamo).WithMany(p => p.Detalle)
                .HasForeignKey(d => d.PrestamoId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(d => d.Producto).WithMany()
                .HasForeignKey(d => d.ProductoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Presentacion).WithMany()
                .HasForeignKey(d => d.PresentacionId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Movimiento).WithMany()
                .HasForeignKey(d => d.MovimientoId).OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static void ConfigurarCompras(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<OrdenCompra>(entity =>
        {
            entity.ToTable("OrdenesCompra");
            entity.HasIndex(o => o.Numero).IsUnique();
            entity.Property(o => o.Numero).HasMaxLength(20).IsRequired();
            entity.Property(o => o.Estado).HasMaxLength(15).IsRequired();
            entity.Property(o => o.Observacion).HasMaxLength(250);

            entity.HasOne(o => o.Proveedor).WithMany()
                .HasForeignKey(o => o.ProveedorId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(o => o.Usuario).WithMany()
                .HasForeignKey(o => o.UsuarioId).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<OrdenCompraDetalle>(entity =>
        {
            entity.ToTable("OrdenCompraDetalle");
            entity.Property(d => d.CantidadPresentacion).HasPrecision(18, 4);
            entity.Property(d => d.Cantidad).HasPrecision(18, 4);
            entity.Property(d => d.CostoUnitario).HasPrecision(18, 4);

            entity.HasOne(d => d.OrdenCompra).WithMany(o => o.Detalle)
                .HasForeignKey(d => d.OrdenCompraId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(d => d.Producto).WithMany()
                .HasForeignKey(d => d.ProductoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Presentacion).WithMany()
                .HasForeignKey(d => d.PresentacionId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Compra>(entity =>
        {
            entity.ToTable("Compras");
            entity.HasIndex(c => c.Numero).IsUnique();
            entity.Property(c => c.Numero).HasMaxLength(20).IsRequired();
            entity.Property(c => c.Estado).HasMaxLength(20).IsRequired();
            entity.Property(c => c.Observacion).HasMaxLength(250);

            entity.HasOne(c => c.Proveedor).WithMany()
                .HasForeignKey(c => c.ProveedorId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(c => c.OrdenCompra).WithMany()
                .HasForeignKey(c => c.OrdenCompraId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(c => c.Usuario).WithMany()
                .HasForeignKey(c => c.UsuarioId).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<CompraDetalle>(entity =>
        {
            entity.ToTable("CompraDetalle");
            entity.Property(d => d.CantidadPresentacion).HasPrecision(18, 4);
            entity.Property(d => d.Cantidad).HasPrecision(18, 4);
            entity.Property(d => d.CostoUnitario).HasPrecision(18, 4);
            entity.Property(d => d.CantidadRecibida).HasPrecision(18, 4);

            entity.HasOne(d => d.Compra).WithMany(c => c.Detalle)
                .HasForeignKey(d => d.CompraId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(d => d.Producto).WithMany()
                .HasForeignKey(d => d.ProductoId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.Presentacion).WithMany()
                .HasForeignKey(d => d.PresentacionId).OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static readonly DateTime Semilla = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private static MotivoMovimiento Motivo(
        int id, string codigo, string nombre, string tipo, bool sistema) =>
        new()
        {
            Id = id,
            Codigo = codigo,
            Nombre = nombre,
            Tipo = tipo,
            DelSistema = sistema,
            // Lo que entra declara costo; lo que sale lo hereda del stock.
            PideCosto = tipo == TipoMovimiento.Entrada,
            Activo = true,
            FechaCreacion = Semilla
        };
}
