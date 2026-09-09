"use client";
import { lazy, Suspense } from 'react'
import { usePageMeta } from '../hooks/usePageMeta'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import ServiceEntry from '../components/ServiceEntry'
import { TnfHero } from '../components/sections/tnf'

// The number, and what follows from it.
//
// This was the first screen of the homepage: r² = r + 1, the format claim, and
// the evidence under it. The homepage is the game now — the map, the corpus and
// the six modules — and the reason the game exists reads here, where someone
// who wants the arithmetic can find all of it in one place rather than scrolling
// past it to reach the board.
const TnfClaim = lazy(() => import('../components/sections/tnf').then((m) => ({ default: m.TnfClaim })))

const Fallback = () => (
  <div style={{ minHeight: '40vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div
      style={{
        width: '40px',
        height: '40px',
        border: '3px solid var(--border)',
        borderTopColor: 'var(--accent)',
        borderRadius: '50%',
        animation: 'spin 1s linear infinite',
      }}
    />
  </div>
)

export default function Trinity() {
  usePageMeta(
    'TRINITY — the number',
    'r² = r + 1: the ternary network float, the claim it makes about formats, and the measured evidence under it.',
  )
  return (
    <main>
      <Navigation />
      <TnfHero />
      <Suspense fallback={<Fallback />}>
        <TnfClaim />
      </Suspense>
      <ServiceEntry />
      <Footer />
    </main>
  )
}
