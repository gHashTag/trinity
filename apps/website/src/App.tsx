import { lazy, Suspense } from 'react'
import { HeroSection } from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'
import Footer from './components/Footer'

// OPTIMIZED: 8 sections (Hero + Theorems + Publications + Solution + Benchmarks + Calculator + DePIN + Team + Invest)
// TechTree moved to /tree, Sacred Intelligence widgets moved to /dashboard
// Target: research-focused landing, not overwhelming
const TheoremsSection = lazy(() => import('./components/sections/TheoremsSection'))
const PublicationsSection = lazy(() => import('./components/sections/PublicationsSection'))
const SolutionSection = lazy(() => import('./components/sections/SolutionSection'))
const BenchmarksSection = lazy(() => import('./components/sections/BenchmarksSection'))
const CalculatorSection = lazy(() => import('./components/sections/CalculatorSection'))
const DePINSection = lazy(() => import('./components/sections/DePINSection'))
const TeamSection = lazy(() => import('./components/sections/TeamSection'))
const InvestSection = lazy(() => import('./components/sections/InvestSection'))

// Sacred Intelligence & Advanced sections moved to /dashboard
// const SacredIdentityWidget = lazy(() => import('./components/sections/SacredIdentityWidget'))
// const SwarmStatusWidget = lazy(() => import('./components/sections/SwarmStatusWidget'))
// const EvolutionMonitorWidget = lazy(() => import('./components/sections/EvolutionMonitorWidget'))
// const GovernanceRulesWidget = lazy(() => import('./components/sections/GovernanceRulesWidget'))
// const EternalLoopWidget = lazy(() => import('./components/sections/EternalLoopWidget'))
// const MysticismSection = lazy(() => import('./components/sections/MysticismSection'))
// const SacredFormulaSection = lazy(() => import('./components/sections/SacredFormulaSection'))
// const SacredChemistryWidget = lazy(() => import('./components/sections/SacredChemistryWidget'))

const SectionFallback = () => (
  <div style={{ minHeight: '50vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
  </div>
)

export default function App() {
  return (
    <main>
      <QuantumBackground />
      <Navigation />
      
      {/* 1. HERO - Animated φ equation, dual CTA */}
      <HeroSection />
      
      <Suspense fallback={<SectionFallback />}>
        {/* 2. THEOREMS - 4 cards with fade-in, credibility hook */}
        <TheoremsSection />

        {/* 3. PUBLICATIONS - 8 Zenodo bundles with DOI */}
        <PublicationsSection />

        {/* 4. SOLUTION - Merged Problem + Competition */}
        <SolutionSection />
        
        {/* 5. BENCHMARKS - Animated comparison table */}
        <BenchmarksSection />

        {/* 6. CALCULATOR - ROI with GPU/mining options */}
        <CalculatorSection />

        {/* 7. DePIN - Earn $TRI by running a node */}
        <DePINSection />

        {/* 8. TEAM - Trust builder (3 members max) */}
        <TeamSection />

        {/* 9. INVEST - Final CTA */}
        <InvestSection />
      </Suspense>
      
      <Footer />
    </main>
  )
}
