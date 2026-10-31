# Servicio de WhatsApp (Baileys)

Manda por WhatsApp el enlace de descarga de cada comprobante electrónico. El backend (ASP.NET) nunca habla con
WhatsApp: le pasa el mensaje a este servicio por HTTP en `127.0.0.1`, y el servicio lo envía desde el celular de la
empresa (vinculado como WhatsApp Web, sin API de pago).

```
SUNAT acepta el comprobante
  → el backend arma el mensaje con la plantilla de la empresa (Configuración > Empresa > WhatsApp)
  → POST /enviar a este servicio
  → cola interna: un mensaje cada 4 segundos
```

El enlace del mensaje (`/api/publico/comprobante/{token}`) **descarga el PDF directamente** al abrirse: no hay
página ni visor, el navegador baja el archivo y termina. El PDF ya generado se guarda 15 minutos en memoria, así
que abrirlo varias veces no lo vuelve a armar.

La pausa entre mensajes es a propósito: Baileys usa la API no oficial de WhatsApp y enviar en ráfaga es lo que
dispara los bloqueos de número.

## Instalación en el VPS

```bash
cd /var/www/distributor/whatsapp-service
npm install --omit=dev
cp .env.example .env
openssl rand -hex 32        # pega el resultado en WHATSAPP_TOKEN (.env)
```

El **mismo** valor va en el backend, en `Backend/Backend/appsettings.Production.json` (solo existe en el VPS):

```json
"WhatsApp": {
  "Url": "http://127.0.0.1:3334",
  "Token": "<el mismo token>",
  "UrlPublica": "https://tu-dominio"
}
```

`UrlPublica` es la dirección con la que el cliente abre el enlace. Déjala siempre puesta en producción: si se omite,
se usa la de la petición, que detrás de Nginx puede salir como `http`.

Luego instala el daemon y reinicia el backend:

```bash
cp whatsapp-service/distributor-whatsapp.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now distributor-whatsapp
systemctl restart distributor-backend
```

`desplegar.sh` no toca este servicio: si cambia `index.js`, reinícialo a mano con
`systemctl restart distributor-whatsapp`.

## Vincular el celular

En el panel: **Configuración > Empresa > pestaña WhatsApp**. Ahí sale el QR; se escanea desde el celular de la
empresa en *WhatsApp > Dispositivos vinculados*. La sesión queda guardada en `auth_info/` y sobrevive a los
reinicios; solo hay que repetirlo si alguien cierra la sesión desde el teléfono.

## Endpoints

| Método | Ruta | Uso |
|---|---|---|
| GET | `/estado` | Estado de conexión, QR y tamaño de la cola. Sin token |
| POST | `/enviar` | `{telefono, mensaje}`. Requiere `X-Token` |
| POST | `/desvincular` | Cierra sesión y fuerza un QR nuevo. Requiere `X-Token` |

## Si deja de enviar

1. `systemctl status distributor-whatsapp` — ¿está corriendo?
2. `curl -s http://127.0.0.1:3334/estado` — ¿dice `"estado":"conectado"`?
3. `tail -f /var/log/distributor-whatsapp.log` — `[ok]` o `[error]` por mensaje.
4. Si dice desconectado y no vuelve solo, cerraron la sesión desde el teléfono: hay que escanear otra vez.
