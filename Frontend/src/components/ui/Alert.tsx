import type { ReactNode } from 'react'

/** `warning` es un aviso (ámbar): informa algo a tener en cuenta, no un error. */
export function Alert({
  children,
  tone = 'error',
}: {
  children: ReactNode
  tone?: 'error' | 'warning'
}) {
  return (
    <div
      role="alert"
      className={
        tone === 'warning'
          ? 'flex gap-2 rounded-field border border-amber-500 bg-amber-50 p-3 text-sm text-amber-800'
          : 'flex gap-2 rounded-field border border-red-600 bg-red-50 p-3 text-sm text-red-700'
      }
    >
      <svg
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        className="mt-0.5 shrink-0"
      >
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7.5v5.5M12 16.2v.6" />
      </svg>
      <span>{children}</span>
    </div>
  )
}
