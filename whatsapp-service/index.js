import 'dotenv/config';
import fs from 'node:fs/promises';
import express from 'express';
import pino from 'pino';
import qrcode from 'qrcode-terminal';
import { Boom } from '@hapi/boom';
import makeWASocket, {
    DisconnectReason,
    useMultiFileAuthState,
} from '@whiskeysockets/baileys';

// Solo escucha en localhost: el backend de Titanic D es el único que le habla.
const PORT = process.env.WHATSAPP_PORT || 3334;
const TOKEN = process.env.WHATSAPP_TOKEN || '';

// Pausa entre mensajes. Baileys es no oficial: enviar en ráfaga es lo que
// dispara los baneos, así que la cola interna respeta este intervalo.
const DELAY_MS = Number(process.env.WHATSAPP_DELAY_MS || 4000);

const logger = pino({ level: 'warn' });

let sock = null;
let estado = 'desconectado';
let ultimoQr = null;

/** Cola serial: un mensaje a la vez, con delay entre cada uno. */
const cola = [];
let procesando = false;

const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Normaliza un teléfono peruano al JID que espera WhatsApp.
 * Acepta "987654321", "51987654321", "+51 987-654-321".
 * Devuelve null si no es un número plausible.
 */
function aJid(telefono) {
    let n = String(telefono ?? '').replace(/\D/g, '');

    if (!n) return null;

    // 9 dígitos y empieza en 9 => celular peruano sin código de país
    if (n.length === 9 && n.startsWith('9')) {
        n = '51' + n;
    }

    // Debe quedar con código de país. Rechaza fijos y basura.
    if (n.length < 11 || n.length > 15) return null;

    return `${n}@s.whatsapp.net`;
}

async function procesarCola() {
    if (procesando) return;
    procesando = true;

    while (cola.length > 0) {
        const item = cola.shift();

        try {
            if (!sock || estado !== 'conectado') {
                throw new Error('WhatsApp no está conectado');
            }

            // Verifica que el número exista en WhatsApp antes de enviar.
            const [info] = await sock.onWhatsApp(item.jid);
            if (!info?.exists) {
                throw new Error('El número no tiene WhatsApp');
            }

            await sock.sendMessage(item.jid, { text: item.mensaje });
            console.log(`[ok] ${item.jid}`);
        } catch (err) {
            console.error(`[error] ${item.jid}: ${err.message}`);
        }

        await dormir(DELAY_MS);
    }

    procesando = false;
}

async function conectar() {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info');

    sock = makeWASocket({
        auth: state,
        logger,
        // Enviar presencia "en línea" en cada mensaje se ve más automatizado.
        markOnlineOnConnect: false,
    });

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
            ultimoQr = qr;
            estado = 'esperando-qr';
            console.log('\nEscanea este QR con el WhatsApp de la empresa:\n');
            qrcode.generate(qr, { small: true });
        }

        if (connection === 'open') {
            estado = 'conectado';
            ultimoQr = null;
            console.log('WhatsApp conectado.');
            procesarCola();
        }

        if (connection === 'close') {
            const code = new Boom(lastDisconnect?.error)?.output?.statusCode;
            const cerroSesion = code === DisconnectReason.loggedOut;

            estado = 'desconectado';

            if (cerroSesion) {
                console.error(
                    'Sesión cerrada desde el teléfono. Borra whatsapp-service/auth_info y vuelve a escanear.',
                );
                return;
            }

            console.log('Conexión perdida, reconectando...');
            conectar();
        }
    });
}

const app = express();
app.use(express.json());

// Autenticación por token compartido con Laravel.
app.use((req, res, next) => {
    if (req.path === '/estado') return next();

    if (!TOKEN || req.get('X-Token') !== TOKEN) {
        return res.status(401).json({ error: 'No autorizado' });
    }

    next();
});

app.get('/estado', (req, res) => {
    res.json({ estado, en_cola: cola.length, qr: ultimoQr });
});

/**
 * Cierra la sesión y borra las credenciales para forzar un QR nuevo.
 * Es lo que permite revincular desde el panel sin entrar al servidor.
 */
app.post('/desvincular', async (req, res) => {
    try {
        if (sock) {
            try {
                await sock.logout();
            } catch {
                // Si ya estaba caída, seguimos: lo que importa es borrar las credenciales.
            }
        }

        await fs.rm('auth_info', { recursive: true, force: true });

        sock = null;
        estado = 'desconectado';
        ultimoQr = null;
        cola.length = 0;

        conectar();

        return res.json({ desvinculado: true });
    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});

app.post('/enviar', (req, res) => {
    const { telefono, mensaje } = req.body ?? {};

    if (!telefono || !mensaje) {
        return res.status(422).json({ error: 'telefono y mensaje son obligatorios' });
    }

    const jid = aJid(telefono);

    if (!jid) {
        return res.status(422).json({ error: `Teléfono inválido: ${telefono}` });
    }

    cola.push({ jid, mensaje });
    procesarCola();

    return res.status(202).json({ encolado: true, en_cola: cola.length });
});

app.listen(PORT, '127.0.0.1', () => {
    console.log(`Servicio WhatsApp escuchando en http://127.0.0.1:${PORT}`);
    conectar();
});
