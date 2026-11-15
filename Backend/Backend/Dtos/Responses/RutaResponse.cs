namespace Backend.Dtos.Responses;

public class RutaResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; }

    /// <summary>Cuántos clientes ya la usan. Si hay alguno, no se elimina.</summary>
    public int Clientes { get; set; }

    /// <summary>Quiénes la tienen a cargo. Puede ser más de uno (el titular y su reemplazo).</summary>
    public List<string> Vendedores { get; set; } = [];

    /// <summary>Los mercados donde están sus clientes activos, por nombre.</summary>
    public List<string> Mercados { get; set; } = [];

    /// <summary>Qué días sale y en qué camión, según los recorridos de Flota, en orden de semana.</summary>
    public List<SalidaRutaResponse> Salidas { get; set; } = [];

    /// <summary>Lo vendido este mes (hora de Perú) a sus clientes: ventas confirmadas, recojos ya descontados.</summary>
    public decimal VentasMes { get; set; }

    /// <summary>Cuántos de sus clientes compraron este mes.</summary>
    public int ClientesConCompraMes { get; set; }

    /// <summary>Lo que deben sus clientes en ventas al crédito, con la misma cuenta que Cuentas por cobrar.</summary>
    public decimal PorCobrar { get; set; }

    /// <summary>Cuántos de sus clientes deben algo.</summary>
    public int ClientesConDeuda { get; set; }
}

/// <summary>Un día en que sale la ruta y el camión que la lleva.</summary>
public class SalidaRutaResponse
{
    /// <summary>LUNES … DOMINGO.</summary>
    public string Dia { get; set; } = string.Empty;
    public string Placa { get; set; } = string.Empty;
}
