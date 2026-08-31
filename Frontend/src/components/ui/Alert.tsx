import type { ReactNode } from 'react'

export function Alert({ children }: { children: ReactNode }) {
  return (
    <div
      role="alert"
      className="flex gap-2 rounded-field border border-red-600 bg-red-50 p-3 text-sm text-red-700"
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
