import { useEffect, useRef, useState } from 'react'

/**
 * Visor de PDF para el celular.
 *
 * Ningun navegador movil dibuja un PDF dentro de un <iframe>: ni Chrome de
 * Android ni Safari de iOS. Queda el recuadro vacio con un boton "Abrir" que
 * pone el propio navegador, y ese boton intenta ir a la URL `blob:`, que el
 * movil bloquea — por eso el visor se veia en blanco en el telefono y en el
 * escritorio no.
 *
 * Aqui se dibuja cada pagina sobre un <canvas> con pdf.js, que es la misma
 * libreria que usa Firefox como visor. Se importa dinamicamente porque pesa y
 * solo hace falta cuando de verdad se abre un PDF en un telefono.
 */
export function VisorPdfMovil({ url, onError }: { url: string; onError: () => void }) {
  const contenedor = useRef<HTMLDivElement>(null)
  const [cargando, setCargando] = useState(true)

  // En un ref para que redefinir la funcion no vuelva a lanzar el dibujado.
  const onErrorRef = useRef(onError)
  onErrorRef.current = onError

  useEffect(() => {
    let cancelado = false
    let tarea: { destroy: () => Promise<void> } | null = null

    const dibujar = async () => {
      setCargando(true)
      try {
        const pdfjs = await import('pdfjs-dist')

        // El worker sale del propio paquete, resuelto por Vite. Si falla, el
        // catch avisa al llamador en vez de dejar el modal en blanco.
        pdfjs.GlobalWorkerOptions.workerSrc = new URL(
          'pdfjs-dist/build/pdf.worker.min.mjs',
          import.meta.url,
        ).toString()

        const carga = pdfjs.getDocument({ url })
        tarea = carga
        const doc = await carga.promise
        if (cancelado) return

        const caja = contenedor.current
        if (!caja) return
        caja.innerHTML = ''

        const ancho = caja.clientWidth || 320
        // En pantallas retina hay que dibujar a mas resolucion o el texto sale
        // borroso. Se topa en 2x para no agotar la memoria del telefono.
        const densidad = Math.min(window.devicePixelRatio || 1, 2)

        for (let n = 1; n <= doc.numPages; n++) {
          if (cancelado) return

          const pagina = await doc.getPage(n)
          const base = pagina.getViewport({ scale: 1 })
          const vista = pagina.getViewport({ scale: (ancho / base.width) * densidad })

          const lienzo = document.createElement('canvas')
          lienzo.width = vista.width
          lienzo.height = vista.height
          lienzo.className = 'mb-2 block h-auto w-full rounded bg-white'

          const ctx = lienzo.getContext('2d')
          if (!ctx) continue

          await pagina.render({ canvas: lienzo, canvasContext: ctx, viewport: vista }).promise
          if (cancelado) return
          caja.appendChild(lienzo)
        }
      } catch {
        if (!cancelado) onErrorRef.current()
      } finally {
        if (!cancelado) setCargando(false)
      }
    }

    void dibujar()

    return () => {
      cancelado = true
      void tarea?.destroy()
    }
  }, [url])

  return (
    <div className="h-full overflow-y-auto p-2">
      {cargando && (
        <p className="py-10 text-center text-sm text-ink-soft">Dibujando el documento...</p>
      )}
      <div ref={contenedor} />
    </div>
  )
}
