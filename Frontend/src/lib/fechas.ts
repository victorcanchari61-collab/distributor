/**
 * La fecha de HOY tal como la ve quien está frente a la pantalla.
 *
 * `toISOString()` pasa el momento a UTC antes de recortarlo, así que en Perú
 * —cinco horas detrás— a partir de las 7 de la tarde devolvía el día
 * siguiente: a las 22:00 del 12 de setiembre decía "2026-09-13", y las visitas
 * del día salían con la agenda de mañana. Aquí se toma el día del reloj local,
 * que es el que cuenta para el negocio.
 */
export function hoyLocal(): string {
  return fechaLocal(new Date())
}

/** Una fecha cualquiera como YYYY-MM-DD, en el día local y no en el de UTC. */
export function fechaLocal(fecha: Date): string {
  const mes = String(fecha.getMonth() + 1).padStart(2, '0')
  const dia = String(fecha.getDate()).padStart(2, '0')
  return `${fecha.getFullYear()}-${mes}-${dia}`
}

/** Hoy más (o menos) N días, en local. */
export function desplazarDias(dias: number): string {
  const d = new Date()
  d.setDate(d.getDate() + dias)
  return fechaLocal(d)
}
