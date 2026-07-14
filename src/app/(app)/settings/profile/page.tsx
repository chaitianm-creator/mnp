'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardTitle } from '@/components/ui/card';
import { Input, Label, Select } from '@/components/ui/input';
import { Alert, Dialog } from '@/components/ui/misc';
import { STUDY_PURPOSES, TIMEZONES } from '@/lib/constants';

export default function ProfileSettingsPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [displayName, setDisplayName] = useState('');
  const [purpose, setPurpose] = useState('habit');
  const [timezone, setTimezone] = useState('Asia/Tokyo');
  const [email, setEmail] = useState('');
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState('');
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    void (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      setEmail(user.email ?? '');
      const { data } = await supabase
        .from('profiles')
        .select('display_name, study_purpose, timezone')
        .eq('id', user.id)
        .single();
      if (data) {
        setDisplayName(data.display_name);
        setPurpose(data.study_purpose ?? 'habit');
        setTimezone(data.timezone);
      }
    })();
  }, [supabase]);

  const save = async () => {
    setError('');
    setSaved(false);
    const name = displayName.trim();
    if (!name || name.length > 30) {
      setError('表示名は1〜30文字で入力してください。');
      return;
    }
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error } = await supabase
      .from('profiles')
      .update({ display_name: name, study_purpose: purpose, timezone })
      .eq('id', user!.id);
    if (error) {
      setError('保存に失敗しました。');
      return;
    }
    setSaved(true);
    router.refresh();
  };

  const deleteAccount = async () => {
    setDeleting(true);
    const res = await fetch('/api/account/delete', { method: 'POST' });
    if (res.ok) {
      await supabase.auth.signOut();
      router.push('/');
      router.refresh();
    } else {
      setError('退会処理に失敗しました。お問い合わせください。');
      setDeleting(false);
      setDeleteOpen(false);
    }
  };

  return (
    <div className="space-y-6">
      <Card className="space-y-5">
        <CardTitle>プロフィール</CardTitle>
        <div>
          <Label>メールアドレス</Label>
          <p className="text-sm text-brand-600 dark:text-brand-300">{email}</p>
        </div>
        <div>
          <Label htmlFor="displayName">表示名</Label>
          <Input
            id="displayName"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            maxLength={30}
          />
        </div>
        <div>
          <Label htmlFor="purpose">学習の目的</Label>
          <Select id="purpose" value={purpose} onChange={(e) => setPurpose(e.target.value)}>
            {STUDY_PURPOSES.map((p) => (
              <option key={p.value} value={p.value}>
                {p.label}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="timezone">タイムゾーン</Label>
          <Select id="timezone" value={timezone} onChange={(e) => setTimezone(e.target.value)}>
            {TIMEZONES.map((tz) => (
              <option key={tz} value={tz}>
                {tz}
              </option>
            ))}
          </Select>
        </div>
        {error && <Alert tone="error">{error}</Alert>}
        {saved && <Alert tone="success">保存しました。</Alert>}
        <Button onClick={save}>保存する</Button>
      </Card>

      <Card>
        <CardTitle>パスワード</CardTitle>
        <p className="mb-3 text-sm text-brand-600 dark:text-brand-300">
          パスワードの変更は、再設定メールから行えます。
        </p>
        <Button
          variant="outline"
          onClick={async () => {
            await supabase.auth.resetPasswordForEmail(email, {
              redirectTo: `${location.origin}/auth/callback?next=/auth/update-password`,
            });
            alert('再設定メールを送信しました。');
          }}
        >
          再設定メールを送る
        </Button>
      </Card>

      <Card className="border-red-200 dark:border-red-900">
        <CardTitle className="text-red-600 dark:text-red-400">退会(アカウント削除)</CardTitle>
        <p className="mb-3 text-sm text-brand-600 dark:text-brand-300">
          アカウントと学習履歴・予約などの個人データがすべて削除されます。この操作は取り消せません。
        </p>
        <Button variant="danger" onClick={() => setDeleteOpen(true)}>
          退会する
        </Button>
      </Card>

      <Dialog open={deleteOpen} onClose={() => setDeleteOpen(false)} title="本当に退会しますか?">
        <div className="space-y-4 text-brand-900 dark:text-brand-50">
          <p className="text-sm">
            すべてのデータが削除され、復元できません。続けるには「退会します」と入力してください。
          </p>
          <Input
            value={deleteConfirm}
            onChange={(e) => setDeleteConfirm(e.target.value)}
            placeholder="退会します"
            aria-label="退会確認"
          />
          <div className="flex gap-3">
            <Button variant="outline" className="flex-1" onClick={() => setDeleteOpen(false)}>
              やめる
            </Button>
            <Button
              variant="danger"
              className="flex-1"
              disabled={deleteConfirm !== '退会します' || deleting}
              onClick={deleteAccount}
            >
              {deleting ? '処理中…' : '完全に削除する'}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
