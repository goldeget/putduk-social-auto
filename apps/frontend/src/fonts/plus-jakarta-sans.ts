import localFont from 'next/font/local';

// Self-hosted variable fonts keep the existing family and 500/600 styles while
// avoiding a Google Fonts fetch during the Next.js build.
export const plusJakartaSans = localFont({
  src: [
    {
      path: './files/PlusJakartaSans[wght].ttf',
      weight: '500 700',
      style: 'normal',
    },
    {
      path: './files/PlusJakartaSans-Italic[wght].ttf',
      weight: '500 700',
      style: 'italic',
    },
  ],
  display: 'swap',
});
