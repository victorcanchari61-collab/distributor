namespace Backend.Service.Interfaces;

/// <summary>Quién está pidiendo, tomado del token de la petición en curso.</summary>
public interface IUsuarioActual
{
    /// <summary>Su id, o null si la petición no viene autenticada.</summary>
    int? Id { get; }
}
