import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: 'class',
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // MokuTomo ブランドカラー: 落ち着いた深緑(安心感) × ランタンの暖色(親しみ)
        brand: {
          50: '#f0f7f4',
          100: '#dcebe4',
          200: '#bcd8cb',
          300: '#8fbdaa',
          400: '#5f9c85',
          500: '#41806a',
          600: '#316655',
          700: '#295246',
          800: '#234239',
          900: '#1e3730',
          950: '#0f1f1b',
        },
        lantern: {
          50: '#fff9eb',
          100: '#ffefc6',
          200: '#ffdd88',
          300: '#ffc54a',
          400: '#ffae20',
          500: '#f98b07',
          600: '#dd6502',
          700: '#b74506',
          800: '#94350c',
          900: '#7a2c0d',
        },
        surface: {
          light: '#faf9f6',
          dark: '#15201c',
        },
      },
      fontFamily: {
        sans: [
          '"Hiragino Kaku Gothic ProN"',
          '"Hiragino Sans"',
          '"BIZ UDPGothic"',
          'Meiryo',
          'system-ui',
          'sans-serif',
        ],
      },
      keyframes: {
        'fade-in-up': {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        'lantern-glow': {
          '0%, 100%': { filter: 'drop-shadow(0 0 4px rgba(255, 197, 74, 0.5))' },
          '50%': { filter: 'drop-shadow(0 0 14px rgba(255, 197, 74, 0.9))' },
        },
      },
      animation: {
        'fade-in-up': 'fade-in-up 0.4s ease-out',
        'lantern-glow': 'lantern-glow 2.4s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};

export default config;
