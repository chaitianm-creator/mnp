'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

export function Badge({
  className,
  tone = 'brand',
  ...props
}: React.HTMLAttributes<HTMLSpanElement> & { tone?: 'brand' | 'lantern' | 'red' | 'gray' }) {
  const tones = {
    brand: 'bg-brand-100 text-brand-800 dark:bg-brand-800 dark:text-brand-100',
    lantern: 'bg-lantern-100 text-lantern-800 dark:bg-lantern-900/60 dark:text-lantern-200',
    red: 'bg-red-100 text-red-800 dark:bg-red-900/60 dark:text-red-200',
    gray: 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-200',
  };
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium',
        tones[tone],
        className
      )}
      {...props}
    />
  );
}

export function Progress({ value, className }: { value: number; className?: string }) {
  const pct = Math.max(0, Math.min(100, value * 100));
  return (
    <div
      role="progressbar"
      aria-valuenow={Math.round(pct)}
      aria-valuemin={0}
      aria-valuemax={100}
      className={cn('h-2.5 w-full overflow-hidden rounded-full bg-brand-100 dark:bg-brand-800', className)}
    >
      <div
        className="h-full rounded-full bg-lantern-400 transition-all duration-500"
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

export function Switch({
  checked,
  onChange,
  label,
  disabled,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cn(
        'relative h-7 w-12 shrink-0 rounded-full transition-colors disabled:opacity-50',
        checked ? 'bg-brand-600' : 'bg-brand-200 dark:bg-brand-700'
      )}
    >
      <span
        className={cn(
          'absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all',
          checked ? 'left-6' : 'left-1'
        )}
      />
    </button>
  );
}

export function Dialog({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}) {
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl dark:bg-brand-900"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="mb-4 text-lg font-bold">{title}</h2>
        {children}
      </div>
    </div>
  );
}

export function Alert({
  tone = 'info',
  children,
  className,
}: {
  tone?: 'info' | 'error' | 'success' | 'warning';
  children: React.ReactNode;
  className?: string;
}) {
  const tones = {
    info: 'bg-brand-50 text-brand-800 border-brand-200 dark:bg-brand-900 dark:text-brand-100 dark:border-brand-700',
    error: 'bg-red-50 text-red-800 border-red-200 dark:bg-red-950 dark:text-red-200 dark:border-red-800',
    success:
      'bg-emerald-50 text-emerald-800 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-200 dark:border-emerald-800',
    warning:
      'bg-lantern-50 text-lantern-800 border-lantern-200 dark:bg-lantern-900/40 dark:text-lantern-200 dark:border-lantern-800',
  };
  return (
    <div role="status" className={cn('rounded-xl border px-4 py-3 text-sm', tones[tone], className)}>
      {children}
    </div>
  );
}
