import { lazy, Suspense } from 'react'
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
const DePINSection = lazy(() => import('./components/sections/DePINSection'))
const TechTree = lazy(() => import('./components/TechTree/TechTree'))
const TeamSection = lazy(() => import('./components/sections/TeamSection'))
const InvestSection = lazy(() => import('./components/sections/InvestSection'))

// Cycle 98: Sacred Intelligence Widgets
const SacredIdentityWidget = lazy(() => import('./components/sections/SacredIdentityWidget'))
const SwarmStatusWidget = lazy(() => import('./components/sections/SwarmStatusWidget'))
const EvolutionMonitorWidget = lazy(() => import('./components/sections/EvolutionMonitorWidget'))
const GovernanceRulesWidget = lazy(() => import('./components/sections/GovernanceRulesWidget'))
const EternalLoopWidget = lazy(() => import('./components/sections/EternalLoopWidget'))

// Mysticism subtab (hidden by default)
const MysticismSection = lazy(() => import('./components/sections/MysticismSection'))
// Sacred Formula Engine — V = n * 3^k * pi^m * phi^p * e^q
const SacredFormulaSection = lazy(() => import('./components/sections/SacredFormulaSection'))

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
        
        {/* 3. SOLUTION - Merged Problem + Competition */}
        <SolutionSection />
        
        {/* 4. BENCHMARKS - Animated comparison table */}
        <BenchmarksSection />
        
        {/* 5. CALCULATOR - ROI with GPU/mining options */}
        <CalculatorSection />

        {/* 6. DePIN - Earn $TRI by running a node */}
        <DePINSection />

        {/* 7. TECH TREE - Research laboratory */}
        <TechTree />

        {/* 8. SACRED INTELLIGENCE - Cycle 98 Self-Awareness Dashboard */}
        <SacredIdentityWidget />
        <SwarmStatusWidget />
        <EvolutionMonitorWidget />
        <GovernanceRulesWidget />
        <EternalLoopWidget />

        {/* 9. TEAM - Trust builder (3 members max) */}
        <TeamSection />

        {/* 10. SCIENCE - Mathematical foundations */}
        <MysticismSection />

        {/* 11. SACRED FORMULA - Integer relation engine */}
        <SacredFormulaSection />

        {/* 12. INVEST - Final CTA */}
        <InvestSection />
      </Suspense>
      
      <Footer />
      <StickyCTA />
    </main>
  )
}
