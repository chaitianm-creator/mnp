import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { AppNav } from '@/components/app-nav';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name, status, onboarding_completed_at')
    .eq('id', user.id)
    .single();

  if (profile?.status === 'suspended') {
    await supabase.auth.signOut();
    redirect('/auth/login');
  }
  if (!profile?.onboarding_completed_at) {
    redirect('/onboarding');
  }

  return (
    <div className="min-h-dvh md:pl-60">
      <main className="mx-auto max-w-4xl px-4 pb-24 pt-6 md:pb-10">{children}</main>
      <AppNav displayName={profile?.display_name ?? ''} />
    </div>
  );
}
