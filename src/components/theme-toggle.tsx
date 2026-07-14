'use client';

import { Moon, Sun } from 'lucide-react';
import { useEffect, useState } from 'react';

export function ThemeToggle() {
  const [dark, setDark] = useState(false);
  useEffect(() => {
    setDark(document.documentElement.classList.contains('dark'));
  }, []);

  const toggle = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle('dark', next);
    try {
      localStorage.setItem('theme', next ? 'dark' : 'light');
    } catch {
      /* private mode等では保存しない */
    }
  };

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={dark ? 'ライトモードに切り替え' : 'ダークモードに切り替え'}
      className="rounded-full p-2 text-brand-600 hover:bg-brand-100 dark:text-brand-200 dark:hover:bg-brand-800"
    >
      {dark ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
    </button>
  );
}
