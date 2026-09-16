/*
 * Deja el worker de pdf.js en public/, servido tal cual desde la raíz.
 *
 * Las formas "de bundler" (new URL(...import.meta.url), ?url, ?worker) andan en
 * desarrollo y fallan compiladas, cada una a su manera: una apunta a un archivo
 * que no existe, otra lo sirve suelto como .mjs con el tipo equivocado. Un
 * archivo estático en /pdf.worker.min.mjs se comporta igual en los dos lados.
 *
 * Corre solo en postinstall para que el archivo siga a la versión instalada de
 * pdfjs-dist y no se quede viejo al actualizarla.
 */
import { copyFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..')
const origen = join(raiz, 'node_modules/pdfjs-dist/build/pdf.worker.min.mjs')
/*
 * Se copia como .js y no como .mjs, aunque el archivo SEA un modulo.
 *
 * pdf.js lo arranca con `new Worker(url, {type: 'module'})`, y para un worker
 * de modulo el navegador exige que el servidor lo mande con un tipo de
 * JavaScript. Nginx no conoce .mjs de fabrica: lo servia como
 * application/octet-stream, el navegador lo rechazaba y el visor del telefono
 * caia a "no pudimos dibujar el documento" —en local no pasaba porque el
 * servidor de desarrollo si le pone el tipo correcto—.
 *
 * Con .js se comporta igual en cualquier servidor sin tocarle la
 * configuracion. La extension no cambia el contenido: sigue siendo el mismo
 * modulo.
 */
const destino = join(raiz, 'public/pdf.worker.min.js')

try {
  mkdirSync(dirname(destino), { recursive: true })
  copyFileSync(origen, destino)
  console.log('worker de pdf.js copiado a public/pdf.worker.min.js')
} catch (e) {
  // Que no tumbe la instalación: sin worker el visor móvil cae a su respaldo.
  console.warn('no se pudo copiar el worker de pdf.js:', e.message)
}
