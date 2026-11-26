using Backend.Models;

namespace Backend.Repository.Interfaces;

/// <summary>Las cuentas del portal de clientes y las cotizaciones que mandan.</summary>
public interface ICotizacionRepository
{
    // ------------------------------------------------------------ Accesos

    /// <summary>La cuenta de un cliente (con el cliente), para modificarla. Null si nunca se lo invitó.</summary>
    Task<AccesoCliente?> GetAccesoDeClienteAsync(int clienteId);

    /// <summary>La cuenta por su id (con el cliente y su vendedor), para modificarla.</summary>
    Task<AccesoCliente?> GetAccesoAsync(int id);

    /// <summary>La cuenta dueña de un enlace de un solo uso (por su hash), para modificarla.</summary>
    Task<AccesoCliente?> GetAccesoPorTokenAsync(string tokenHash);

    /// <summary>
    /// La cuenta ya activada con ese usuario, o la del cliente con ese DNI/RUC (principal o segundo documento).
    /// </summary>
    Task<AccesoCliente?> GetAccesoPorIdentificadorAsync(string identificador);

    Task<bool> UsuarioTomadoAsync(string usuario, int excluirAccesoId);

    Task AddAccesoAsync(AccesoCliente acceso);

    /// <summary>
    /// Quienes atienden una ruta (usuarios activos que la tienen a cargo): son los vendedores de sus clientes. El
    /// cliente ya no guarda vendedor propio; lo da su ruta.
    /// </summary>
    Task<List<Usuario>> VendedoresDeRutaAsync(int rutaId);

    // ---------------------------------------------------------- Favoritos

    Task<List<int>> FavoritosAsync(int clienteId);

    /// <summary>Marca o desmarca; repetir la misma marca no hace nada.</summary>
    Task MarcarFavoritoAsync(int clienteId, int productoId, bool favorito);

    // ------------------------------------------------------- Cotizaciones

    Task<string> SiguienteNumeroAsync();

    Task AddAsync(Cotizacion cotizacion);

    /// <summary>Con cliente, vendedor y líneas; rastreada, para cambiarle el estado.</summary>
    Task<Cotizacion?> GetAsync(int id);

    /// <summary>
    /// Las del panel, de la más nueva a la más vieja, recortadas por alcance (el de Pedidos): quien no ve todo ve las
    /// de los clientes de sus rutas y las que le llegaron a él.
    /// </summary>
    Task<List<Cotizacion>> GetListaAsync(string? estado, int? clienteId, AlcanceFiltro? alcance);

    /// <summary>Las de un cliente, para su portal.</summary>
    Task<List<Cotizacion>> GetDeClienteAsync(int clienteId);

    Task<int> ContarEnEsperaAsync(int clienteId);

    /// <summary>El pedido que salió de cada cotización atendida: id de cotización → (id, número) del pedido.</summary>
    Task<Dictionary<int, (int Id, string Numero)>> PedidosDeAsync(IReadOnlyCollection<int> cotizacionIds);

    Task SaveAsync();
}
