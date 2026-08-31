import { cn } from './cn'

export interface LogoProps {
  size?: 'sm' | 'md'
  text?: string
  showText?: boolean
  className?: string
}

export function Logo({ size = 'md', text = 'DISTRIBUIDORA', showText = true, className }: LogoProps) {
  const px = size === 'sm' ? 16 : 20
  return (
    <span className={cn('inline-flex items-center gap-2', className)}>
      <span
        className={cn(
          'ui-brand inline-flex items-center justify-center rounded-field',
          size === 'sm' ? 'size-7' : 'size-9',
        )}
      >
        <svg width={px} height={px} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9">
          <circle cx="12" cy="6" r="3" />
          <circle cx="6" cy="17" r="3" />
          <circle cx="18" cy="17" r="3" />
          <path d="M10.5 8.6 7.5 14.4M13.5 8.6l3 5.8M9 17h6" />
        </svg>
      </span>
      {showText && (
        <span
          className={cn(
            'font-extrabold tracking-tight text-ink',
            size === 'sm' ? 'text-base' : 'text-2xl',
          )}
        >
          {text}
        </span>
      )}
    </span>
  )
}
