import { lazy, Suspense } from 'react'
import { HeroSection } from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'
import Footer from './components/Footer'

// UX Redesign: Golden Formula — Hero → Trust → Features → Social Proof → Comparison → FAQ → Invest
const TrustBlock = lazy(() => import('./components/sections/TrustBlock'))
const FeaturesSection = lazy(() => import('./components/sections/FeaturesSection'))
const TestimonialsSection = lazy(() => import('./components/sections/TestimonialsSection'))
const ComparisonSection = lazy(() => import('./components/sections/ComparisonSection'))
const FaqSection = lazy(() => import('./components/sections/FaqSection'))
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

      {/* 1. HERO - Animated φ equation, CLI snippet, eyebrow banner */}
      <HeroSection />

      <Suspense fallback={<SectionFallback />}>
        {/* 2. TRUST - Metrics grid (GitHub stars, CLI commands, publications) */}
        <TrustBlock />

        {/* 3. FEATURES - 27 agents grid with problem→solution storytelling */}
        <FeaturesSection />

        {/* 4. TESTIMONIALS - Social proof */}
        <TestimonialsSection />

        {/* 5. COMPARISON - Competitor table */}
        <ComparisonSection />

        {/* 6. FAQ - Accordion */}
        <FaqSection />

        {/* 7. INVEST - Final CTA */}
        <InvestSection />
      </Suspense>

      <Footer />
    </main>
  )
}
