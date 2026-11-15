using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// El plano de cada piso de un almacén: dónde está dibujado cada lugar y los pasillos y escaleras que ayudan a
/// orientarse. Los lugares en sí (crearlos, nombrarlos) siguen en <see cref="IUbicacionService"/>.
/// </summary>
public interface IPlanoService
{
    /// <summary>El tamaño de la cuadrícula y los pasillos y escaleras de todos los pisos del almacén.</summary>
    Task<PlanoResponse> ObtenerAsync(int almacenId);

    /// <summary>Dibuja un lugar en el plano de su piso, lo mueve o le cambia el tamaño; todo nulo lo saca del plano.</summary>
    Task<UbicacionResponse> PosicionarLugarAsync(int ubicacionId, PosicionPlanoRequest request);

    Task<ElementoPlanoResponse> CrearElementoAsync(int almacenId, ElementoPlanoRequest request);

    /// <summary>Mueve, cambia el tamaño o renombra un pasillo o escalera. No cambia de piso ni de tipo.</summary>
    Task<ElementoPlanoResponse> ActualizarElementoAsync(int id, ElementoPlanoRequest request);

    Task EliminarElementoAsync(int id);
}
