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
const TechTree = lazy(() => import('./components/TechTree/TechTree'))
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
        
        {/* 6. TECH TREE - Research laboratory */}
        <TechTree />
        
        {/* 7. TEAM - Trust builder (3 members max) */}
        <TeamSection />
        
        {/* 8. SCIENCE - Mathematical foundations */}
        <MysticismSection />
        
        {/* 8. INVEST - Final CTA */}
        <InvestSection />
      </Suspense>
      
      <Footer />
      <StickyCTA />
    </main>
  )
}
