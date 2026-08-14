import { useLocation } from 'react-router-dom'
import PhiStarfield from './PhiStarfield'

// Звёздное поле было только на главной, хотя оно не украшение: положения звёзд
// берутся из спирали Фогеля с углом 137.5077° = круг, делённый на φ², — то же
// самое число, которым правило полей делит разрядность формата. Одна страница
// с ним и восемнадцать без него читались как разные сайты.
//
// Исключения ниже — маршруты, у которых есть своё полноэкранное полотно
// (canvas / WebGL / wasm-сцены). Там второй фоновый canvas не виден вообще,
// зато честно тратит кадры, поэтому его туда не ставим.
const OWN_CANVAS = new Set([
  '/canvas',
  '/quantum',
  '/lab',
  '/play',
  '/chat',
  '/wasm',
  '/dashboard',
  '/tree',
])

export default function GlobalStarfield() {
  const { pathname } = useLocation()
  if (OWN_CANVAS.has(pathname)) return null
  return <PhiStarfield />
}
