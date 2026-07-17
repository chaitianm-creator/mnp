'use client';

import { useEffect, useState } from 'react';

// スマホ判定(768px未満)。PC版レイアウトはそのまま、スマホでは専用アプリUIへ切り替える
const QUERY = '(max-width: 767px)';

export function useIsMobile() {
  const [isMobile, setIsMobile] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia(QUERY);
    const update = () => setIsMobile(mq.matches);
    update();
    mq.addEventListener('change', update);
    return () => mq.removeEventListener('change', update);
  }, []);
  return isMobile;
}
