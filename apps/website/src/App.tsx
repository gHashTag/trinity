import { lazy, Suspense } from 'react'
import Navigation from './components/Navigation'
import PhiStarfield from './components/PhiStarfield'
import Footer from './components/Footer'
import { TnfHero } from './components/sections/tnf'

// Главная страница построена под статьёй «Trinity S³AI: Ternary Network Floats»
// (52 теоремы, 16 ретракций). Порядок разделов повторяет порядок аргумента:
// что заявлено → чем именно заявлено → что измерено → что стоит бюджет →
// на каких теоремах держится → где границы и что отозвано → кто ещё на этой
// земле → откуда линия → как воспроизвести.
//
// Секции прежней главной (DePIN, ROI-калькулятор, Solution с прогнозными
// множителями, Invest) с главной сняты: они несли прогнозы и категорические
// формулировки рядом с измеренными числами, и научный читатель не мог отделить
// одно от другого. Компоненты остались в репозитории и доступны на своих
// страницах — снята только их роль первого экрана.
const TnfClaim = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfClaim })))
const TnfFormats = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfFormats })))
const TnfFrontier = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfFrontier })))
const TnfLadder = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfLadder })))
const TnfTheorems = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfTheorems })))
const TnfLimits = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfLimits })))
const TnfLandscape = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfLandscape })))
const TnfCalculators = lazy(() => import('./components/sections/tnf/Calculators'))
const TnfVisuals = lazy(() => import('./components/sections/tnf/PhiViz'))
const TnfFindings = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfFindings })))
const TnfLineage = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfLineage })))
const TnfAuthor = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfAuthor })))
const TnfReproduce = lazy(() => import('./components/sections/tnf').then((m) => ({ default: m.TnfReproduce })))
const PublicationsSection = lazy(() => import('./components/sections/PublicationsSection'))

const SectionFallback = () => (
  <div style={{ minHeight: '40vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
  </div>
)

export default function App() {
  return (
    <main>
      <PhiStarfield />
      <Navigation />

      <TnfHero />

      <Suspense fallback={<SectionFallback />}>
        <TnfClaim />
        <TnfFormats />
        <TnfFrontier />
        <TnfVisuals />
        <TnfLadder />
        <TnfTheorems />
        <TnfCalculators />
        <TnfLimits />
        <TnfLandscape />
        <TnfFindings />
        <TnfLineage />
        <PublicationsSection />
        <TnfAuthor />
        <TnfReproduce />
      </Suspense>

      <Footer />
    </main>
  )
}
