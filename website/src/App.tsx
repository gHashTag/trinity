import { lazy, Suspense, useState } from 'react'
import { HeroSection } from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'
import Footer from './components/Footer'
import StickyCTA from './components/StickyCTA'

// OPTIMIZED: 8 sections only (was 29)
// Target: +40% conversion through focused flow
const TheoremsSection = lazy(() => import('./components/sections/TheoremsSection'))
const SolutionSection = lazy(() => import('./components/sections/SolutionSection'))
const BenchmarksSection = lazy(() => import('./components/sections/BenchmarksSection'))
const CalculatorSection = lazy(() => import('./components/sections/CalculatorSection'))
const RoadmapSection = lazy(() => import('./components/sections/RoadmapSection'))
const TeamSection = lazy(() => import('./components/sections/TeamSection'))
const InvestSection = lazy(() => import('./components/sections/InvestSection'))

// Mysticism subtab (hidden by default)
const MysticismSection = lazy(() => import('./components/sections/MysticismSection'))

const SectionFallback = () => (
  <div style={{ minHeight: '50vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
  </div>
)

export default function App() {
  const [showMysticism, setShowMysticism] = useState(false)

  return (
    <main>
      <QuantumBackground />
      <Navigation />
      
      {/* 1. HERO - Animated φ equation, dual CTA */}
      <HeroSection />
      
      <Suspense fallback={<SectionFallback />}>
        {/* 2. THEOREMS - 4 cards with fade-in, credibility hook */}
        <TheoremsSection />
        
        {/* 3. SOLUTION - Merged Problem + Competition */}
        <SolutionSection />
        
        {/* 4. BENCHMARKS - Animated comparison table */}
        <BenchmarksSection />
        
        {/* 5. CALCULATOR - ROI with GPU/mining options */}
        <CalculatorSection />
        
        {/* 6. ROADMAP - Simplified execution plan */}
        <RoadmapSection />
        
        {/* 7. TEAM - Trust builder (3 members max) */}
        <TeamSection />
        
        {/* MYSTICISM SUBTAB - Hidden by default */}
        <div style={{ textAlign: 'center', padding: '2rem 0' }}>
          <button 
            onClick={() => setShowMysticism(!showMysticism)}
            style={{
              background: 'transparent',
              border: '1px solid var(--border)',
              color: 'var(--text-secondary)',
              padding: '0.5rem 1.5rem',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '0.9rem',
              opacity: 0.6,
              transition: 'opacity 0.3s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.opacity = '1'}
            onMouseLeave={(e) => e.currentTarget.style.opacity = '0.6'}
          >
            {showMysticism ? '▼ Hide Mathematical Foundations' : '▶ For Mathematicians: SU(3), Chern-Simons, φ'}
          </button>
        </div>
        {showMysticism && <MysticismSection />}
        
        {/* 8. INVEST - Final CTA */}
        <InvestSection />
      </Suspense>
      
      <Footer />
      <StickyCTA />
    </main>
  )
}
