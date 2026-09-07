import { lazy, Suspense } from 'react'
import Navigation from './components/Navigation'
import Footer from './components/Footer'
import ServiceEntry from './components/ServiceEntry'
import QueenHeroBlock from './components/QueenHeroBlock'
import { TnfHero } from './components/sections/tnf'

// Главная строится вокруг одного предмета: .t27-спеки и карта, которая их
// показывает. Порядок первого экрана — что это → карта спек → на чём держится
// заявление → куда идти дальше.
//
// Прежняя главная несла 21 секцию и 31 393px (около 35 экранов): вся статья
// «Trinity S³AI: Ternary Network Floats» лежала на одной странице, и цель игры
// в ней терялась. Ни одна секция не удалена — каждая переехала на свою
// страницу и живёт там целиком:
//
//   formats, visuals, calculators → /gft
//   ladder, theorems, limits      → /proof
//   frontier, reproduce           → /verification
//   decision                      → /select
//   landscape, findings           → /cases
//   lineage, author               → /about
//   faq, publications             → /resources
//   start                         → /start
//   invest                        → /ip
const TnfClaim = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfClaim })))

const SectionFallback = () => (
  <div style={{ minHeight: '40vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
  </div>
)

export default function App() {
  return (
    <main>
      <Navigation />

      <TnfHero />
      <QueenHeroBlock />

      <Suspense fallback={<SectionFallback />}>
        <TnfClaim />
      </Suspense>

      <ServiceEntry />

      <Footer />
    </main>
  )
}
