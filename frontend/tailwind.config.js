/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        night: '#06132a',
        escrin: '#eeaa00',
        sapphire: '#0ec4fa',
      }
    },
  },
  plugins: [],
}
