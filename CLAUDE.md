# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es esto

Sistema de gestión para una distribuidora (marca "Titanic D"): ventas/pedidos, compras, inventario, finanzas, RRHH, flota y reparto. Código y comentarios están en **español** (nombres de clases, rutas de API, mensajes); sigue ese idioma al agregar código.

Monorepo con tres proyectos que consumen el mismo API:

- `Backend/` — API ASP.NET Core (net10.0) + EF Core + MySQL.
- `Frontend/` — panel web React 19 + TypeScript + Vite + Tailwind 4 (pnpm).
- `titanic/` — app móvil Flutter (Riverpod), para el repartidor/vendedor en ruta. Ver `titanic/README.md`.
- `whatsapp-service/` — microservicio Node (Baileys) que manda por WhatsApp el enlace de descarga de cada comprobante. El backend le habla por `127.0.0.1` (sección `WhatsApp` de appsettings); `desplegar.sh` **no** lo despliega ni lo reinicia. Ver `whatsapp-service/README.md`.

No hay carpeta de tests en Backend ni Frontend; solo la app Flutter tiene tests.

## Comandos

**Backend** (desde `Backend/Backend`; MySQL local en `localhost:3306`, base `distributor`, usuario `root` sin clave — ver `appsettings.json`):

```bash
dotnet run                      # escucha en http://0.0.0.0:5220 (Swagger solo en Development)
dotnet ef database update       # aplica migraciones
dotnet ef migrations add Nombre # ver nota de migraciones abajo
```

**Frontend** (desde `Frontend`):

```bash
pnpm install        # postinstall copia el worker de pdfjs (scripts/copiar-worker-pdf.mjs)
pnpm dev            # Vite; proxea /api, /uploads y /hubs (SignalR, ws) a http://127.0.0.1:5220
pnpm build          # tsc -b && vite build  (es lo que corre el despliegue)
pnpm lint           # oxlint
pnpm preview        # sirve el build compilado con el mismo proxy
```

**App móvil** (desde `titanic`): `flutter run` (el API debe estar arriba; `--dart-define=API_URL=http://IP:5220/api` para dispositivo físico) y `flutter test` / `flutter test test/archivo_test.dart`.

## Despliegue

Cada push a `main` (excepto cambios solo en `titanic/**`) dispara `.github/workflows/desplegar.yml`, que entra por SSH al VPS y corre `desplegar.sh` **tal como está en `origin/main`**. El script hace `git pull --ff-only` y solo reconstruye lo que cambió: si tocó `Backend/` → `dotnet ef database update` (con `ASPNETCORE_ENVIRONMENT=Production`), `dotnet publish` a `/var/www/distributor/publish`, reinicia `distributor-backend` y verifica que `/api/producto` responda 401; si tocó `Frontend/` → `pnpm build`. `TODO=1` fuerza todo. Consecuencia: **las migraciones se aplican solas en producción al hacer push**, así que una migración mala llega a producción. `appsettings.Production.json` está en `.gitignore` y vive solo en el VPS.

## Arquitectura del backend

Capas por convención de carpetas en `Backend/Backend`: `Controllers` → `Service/{Interfaces,Implementacion}` → `Repository/{Interfaces,Implementacion}` → `Data/AppDbContext`. Todo se registra a mano en `Program.cs` (cada servicio/repositorio nuevo necesita su línea `AddScoped`). DTOs en `Dtos/{Requests,Responses,Validators}`; los validators son FluentValidation y se descubren por ensamblado.

Piezas transversales que hay que conocer antes de tocar cualquier endpoint:

- **Permisos por submódulo+acción, no por rol.** Los controladores usan `[Permiso("fact.notaventa", Accion.Anular)]` (`Filters/PermisoAttribute.cs`; `PermisoAlgunoAttribute` para "cualquiera de"). La fuente de verdad del catálogo de submódulos y qué acciones admite cada uno es `Models/Permisos.cs`; la pantalla de Accesos del front dibuja su matriz desde ese catálogo, y los roles se guardan en tabla (`Rol`, `RolPermiso`). Existen además permisos de **un solo uso**: se autorizan al inicio y solo se consumen si la acción termina con éxito. El 403 devuelve `submodulo` y `accion` para que el front abra el modal de solicitud de permiso. Las decisiones se cachean en `IMemoryCache` (`PermisoService`).
- **Errores**: se lanzan excepciones de `Exceptions/` (`NotFoundException`, `BadRequestException`, `ConflictException`, …) y `ExceptionMiddleware` las convierte en respuestas JSON `{ statusCode, message }`. No devuelvas errores a mano desde los servicios.
- **Auditoría automática**: `AppDbContext.SaveChangesAsync` está sobrescrito y escribe en la tabla `Auditoria` todo cambio (Added/Modified/Deleted) en dos pasos (primero guarda, luego registra con los Ids ya asignados), leyendo el usuario de `IHttpContextAccessor`. No hace falta auditar en los servicios.
- **Tiempo real**: tras guardar con éxito, los servicios llaman `INotificador.AvisarAsync(modulo, accion, datos)` (implementado por `NotificadorHub` sobre SignalR, hub en `/hubs/cambios`). Es "fire and forget": nunca debe tumbar la operación. El front se suscribe por nombre de módulo (`Frontend/src/lib/realtime.ts`). El JWT llega por query string `access_token` solo para rutas `/hubs`.
- **Auth**: JWT Bearer (`Jwt:*` en appsettings). `IUsuarioActual` expone el usuario de la petición.
- **PDFs**: QuestPDF (licencia Community, declarada en `Program.cs`) en `Service/Pdf/` — documentos A4 y tickets; el logo y la fuente DejaVu van como `EmbeddedResource` en el `.csproj`.
- **Consulta RUC/DNI** vía apisperu.com se hace desde el backend (`ConsultaService`) para no exponer el token al navegador.
- **Archivos subidos** (fotos de flota/conductores) se sirven como estáticos desde `wwwroot` *antes* de la autenticación (se piden desde `<img>`).
- CORS permite solo los orígenes de dev listados en `Program.cs` (5173, 5174, 5180, `distributor.test`); en producción el front y el API comparten origen vía Nginx.

### Migraciones EF — dos carpetas

Las migraciones están repartidas en **dos carpetas**: las antiguas (hasta `20260916…`) y el `AppDbContextModelSnapshot.cs` viven en `Data/Migrations` (namespace `Backend.Data.Migrations`); las más recientes (desde `20260918…`) están en `Migrations/` (namespace `Backend.Migrations`). EF las descubre todas por ensamblado, pero hay un solo snapshot. Al crear una nueva, fija el directorio con `-o Migrations` para seguir con la convención reciente. Hay migraciones de solo datos (p. ej. `VendedorVeSusCierres`, que ajusta permisos de rol); el catálogo de permisos en código y los datos sembrados en BD deben mantenerse coherentes. `Backend/sql/` tiene scripts manuales de limpieza/siembra (no son migraciones).

## Arquitectura del frontend

`Frontend/src`: `features/<modulo>` (auth, compras, config, dashboard, dms, facturacion, finanzas, inicio, inventario, maestros, perfil, rrhh, tms), `components/{layout,ui,charts}`, `lib/` (cliente API, permisos, realtime, auth storage, excel/pdf helpers).

- El menú se define en `components/layout/navigation.ts` (grupos y vistas con ids tipo `fact.notaventa`). **Esos ids son los mismos submódulos del catálogo de permisos del backend.** `App.tsx` mapea id de vista → componente en `VIEWS`; lo que no está ahí cae en `PendingPage`. Una vista con `hidden: true` no aparece en el menú.
- `lib/permisos.tsx` (`PermisosProvider`/`usePermisos`) carga los permisos del usuario como claves `"submodulo:accion"`; `ACCION` espeja `Models/Permisos.cs` — si agregas una acción en el backend, agrégala en ambos.
- Las URLs del API son **relativas** (`/api`, `/hubs`, `/uploads`): las resuelve el proxy de Vite en dev y Nginx en producción. No hardcodees host.

## Sincronía entre proyectos

- `titanic/test/menu_espejo_test.dart` **lee `Frontend/src/components/layout/navigation.ts` con regex** y compara contra `titanic/lib/core/navegacion/menu.dart`. Si cambias el formato de `navigation.ts` (indentación de `id:` de grupos, forma de los objetos de vista) o agregas/quitas módulos, la app Flutter debe seguirte o el test falla.
- Un cambio de contrato en un endpoint afecta a web y móvil: ambos consumen el mismo API.
