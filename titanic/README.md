# Titanic D · App móvil

App Flutter de la suite operativa. Consume el mismo API que el panel web
(`Backend/`), con el mismo diseño y los mismos colores.

## Arquitectura

Organizada por **funcionalidad**, no por tipo de archivo: todo lo de una
funcionalidad vive junto, así se agrega un módulo sin tocar el resto.

```
lib/
  main.dart                     arranque de la app
  core/                         lo que usa todo el sistema
    config/entorno.dart         URL del API por entorno
    tema/                       colores, medidas y ThemeData
    red/                        cliente HTTP y errores del API
    almacenamiento/             sesión en el almacén seguro del dispositivo
    router/                     rutas y protección de sesión
  compartido/widgets/           componentes reutilizables (botón, campo, alerta, logo)
  features/
    auth/
      datos/                    modelos y llamadas al API
      estado/                   controlador Riverpod de la sesión
      vistas/                   pantallas
    inicio/vistas/              pantalla tras iniciar sesión
```

**Reglas que sostienen esto:**

- Una pantalla nunca llama a `http` directamente: pasa por `ClienteApi`.
- Un color o una medida no se escribe a mano: sale de `core/tema`.
- La protección de rutas vive en un solo `redirect`, no en cada pantalla.

## Cómo correrla

El API debe estar arriba (`cd Backend/Backend && dotnet run`).

```bash
flutter run
```

La URL del API se resuelve sola: `10.0.2.2` en el emulador de Android (así ve
el emulador la máquina anfitriona) y `localhost` en iOS y escritorio.

Para un dispositivo físico en la misma red, apunta a la IP de tu PC:

```bash
flutter run --dart-define=API_URL=http://192.168.1.20:5220/api
```

## Pruebas

```bash
flutter test
```

## Pendiente

- Módulos de la app sobre la pantalla de inicio: visitas, pedidos y cobranzas.
- Modo sin conexión: el repartidor pierde señal en ruta y necesita seguir
  registrando. Implica cola local de operaciones y sincronización posterior.
