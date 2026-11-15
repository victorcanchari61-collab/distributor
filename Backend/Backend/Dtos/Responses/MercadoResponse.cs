namespace Backend.Dtos.Responses;

public class MercadoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Distrito { get; set; }
    public bool Activo { get; set; }

    /// <summary>Cuántos clientes ya lo usan. Si hay alguno, no se elimina.</summary>
    public int Clientes { get; set; }

    /// <summary>Las rutas que llegan a él: las de sus clientes activos, por nombre.</summary>
    public List<string> Rutas { get; set; } = [];

    /// <summary>Lo vendido este mes (hora de Perú) a sus clientes: ventas confirmadas, recojos ya descontados.</summary>
    public decimal VentasMes { get; set; }

    /// <summary>Lo que deben sus clientes en ventas al crédito, con la misma cuenta que Cuentas por cobrar.</summary>
    public decimal PorCobrar { get; set; }
}
