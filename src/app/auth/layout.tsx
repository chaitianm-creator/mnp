import Link from 'next/link';
import { Logo } from '@/components/tomoshibi';

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center px-4 py-10">
      <Link href="/" className="mb-8" aria-label="トップページへ">
        <Logo />
      </Link>
      <div className="w-full max-w-md rounded-2xl border border-brand-100 bg-white p-6 shadow-sm dark:border-brand-800 dark:bg-brand-900/60 sm:p-8">
        {children}
      </div>
    </div>
  );
}
