import * as React from 'react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger' | 'lantern';
  size?: 'sm' | 'md' | 'lg' | 'xl';
}

const variants: Record<NonNullable<ButtonProps['variant']>, string> = {
  primary:
    'bg-brand-600 text-white hover:bg-brand-700 disabled:bg-brand-300 dark:bg-brand-500 dark:hover:bg-brand-400',
  lantern:
    'bg-lantern-400 text-brand-950 font-bold shadow-lg shadow-lantern-400/30 hover:bg-lantern-300 disabled:bg-lantern-200',
  secondary:
    'bg-brand-100 text-brand-800 hover:bg-brand-200 dark:bg-brand-800 dark:text-brand-100 dark:hover:bg-brand-700',
  outline:
    'border border-brand-300 text-brand-700 hover:bg-brand-50 dark:border-brand-600 dark:text-brand-200 dark:hover:bg-brand-900',
  ghost: 'text-brand-700 hover:bg-brand-100 dark:text-brand-200 dark:hover:bg-brand-800',
  danger: 'bg-red-600 text-white hover:bg-red-700 disabled:bg-red-300',
};

const sizes: Record<NonNullable<ButtonProps['size']>, string> = {
  sm: 'h-8 px-3 text-sm rounded-lg',
  md: 'h-10 px-4 text-sm rounded-xl',
  lg: 'h-12 px-6 text-base rounded-xl',
  xl: 'h-14 px-8 text-lg rounded-2xl',
};

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'md', type = 'button', ...props }, ref) => (
    <button
      ref={ref}
      type={type}
      className={cn(
        'inline-flex items-center justify-center gap-2 font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-70',
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    />
  )
);
Button.displayName = 'Button';
