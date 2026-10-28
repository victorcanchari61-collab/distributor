import { Mail, MessageCircle, Phone, Store } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import type { TipoContacto, TonoGestion } from './crmApi'

/** Etiqueta, color e icono de cada forma de contacto: las ve el vendedor al registrar y en el historial. */
export const CONTACTO_UI: Record<TipoContacto, { etiqueta: string; corto: string; color: string; icono: LucideIcon }> = {
  LLAMADA: { etiqueta: 'Llamada telefónica', corto: 'Llamada', color: '#16a34a', icono: Phone },
  WHATSAPP: { etiqueta: 'WhatsApp', corto: 'WhatsApp', color: '#22c55e', icono: MessageCircle },
  VISITA: { etiqueta: 'Visita presencial', corto: 'Visita', color: '#7c3aed', icono: Store },
  CORREO: { etiqueta: 'Correo electrónico', corto: 'Correo', color: '#2563eb', icono: Mail },
}

/** Colores de cada tono de resultado: la etiqueta de la gestión y el punto del selector. */
export const TONOS: Record<TonoGestion, { color: string; fondo: string }> = {
  positivo: { color: '#16a34a', fondo: '#f0fdf4' },
  espera: { color: '#2563eb', fondo: '#eff6ff' },
  neutro: { color: '#475569', fondo: '#f1f5f9' },
  objecion: { color: '#ea580c', fondo: '#fff7ed' },
  perdido: { color: '#dc2626', fondo: '#fef2f2' },
}

/** La hora que propone la pantalla para el siguiente contacto. */
export const HORA_POR_DEFECTO = '10:00'

/** El número para wa.me: solo dígitos y con el 51 de Perú si vino de 9 cifras. */
export const whatsapp = (telefono: string) => {
  const digitos = telefono.replace(/\D/g, '')
  return digitos.length === 9 ? `51${digitos}` : digitos
}
