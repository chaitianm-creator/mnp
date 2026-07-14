import * as React from 'react';
import { cn } from '@/lib/utils';

export function Card({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        'rounded-2xl border border-brand-100 bg-white p-5 shadow-sm dark:border-brand-800 dark:bg-brand-900/60',
        className
      )}
      {...props}
    />
  );
}

export function CardTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h2
      className={cn('mb-3 text-sm font-bold text-brand-700 dark:text-brand-200', className)}
      {...props}
    />
  );
}
