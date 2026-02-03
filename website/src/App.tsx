import { lazy, Suspense } from 'react'
import { 
  HeroSection, 
  ProblemSection, 
  SolutionSection 
} from './components/sections'
import Navigation from './components/Navigation'
import QuantumBackground from './components/QuantumBackground'
import Footer from './components/Footer'

// Lazy load sections below fold
const TheoremsSection = lazy(() => import('./components/sections/TheoremsSection'))
const WhyNowSection = lazy(() => import('./components/sections/WhyNowSection'))
const BenchmarksSection = lazy(() => import('./components/sections/BenchmarksSection'))
const CalculatorSection = lazy(() => import('./components/sections/CalculatorSection'))
const TechnologySection = lazy(() => import('./components/sections/TechnologySection'))
const MarketSection = lazy(() => import('./components/sections/MarketSection'))
const GTMSection = lazy(() => import('./components/sections/GTMSection'))
const CompetitionSection = lazy(() => import('./components/sections/CompetitionSection'))
const HLSCompetitionSection = lazy(() => import('./components/sections/HLSCompetitionSection'))
const RoadmapSection = lazy(() => import('./components/sections/RoadmapSection'))
const TeamSection = lazy(() => import('./components/sections/TeamSection'))
const EcosystemSection = lazy(() => import('./components/sections/EcosystemSection'))
const InvestSection = lazy(() => import('./components/sections/InvestSection'))
const PhoenixNumberSection = lazy(() => import('./components/sections/PhoenixNumberSection'))

// Additional sections (lower priority)
const TractionSection = lazy(() => import('./components/sections/TractionSection'))
const MiningSolutionSection = lazy(() => import('./components/sections/MiningSolutionSection'))
const ProductSection = lazy(() => import('./components/sections/ProductSection'))
const FinancialsSection = lazy(() => import('./components/sections/FinancialsSection'))
const BusinessModelSection = lazy(() => import('./components/sections/BusinessModelSection'))
const BitNetProofSection = lazy(() => import('./components/sections/BitNetProofSection'))
const SU3MiningRealitySection = lazy(() => import('./components/SU3MiningRealitySection'))
const TechAssetsSection = lazy(() => import('./components/sections/TechAssetsSection'))
const CalculatorLogicSection = lazy(() => import('./components/sections/CalculatorLogicSection'))
const ScientificFoundationSection = lazy(() => import('./components/sections/ScientificFoundationSection'))
const MilestonesSection = lazy(() => import('./components/sections/MilestonesSection'))
const VisionSection = lazy(() => import('./components/sections/VisionSection'))

// Minimal fallback for sections
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
      
      {/* Above fold - load immediately */}
      <HeroSection />
      
      {/* OPTIMIZED ORDER: Hook (Theorems) → Problem → Solution → Proof → Action */}
      <Suspense fallback={<SectionFallback />}>
        {/* 1. THEOREMS - Immediate credibility hook (investors leave if no hook in 10s) */}
        <TheoremsSection />
        
        {/* 2. PROBLEM & SOLUTION - Classic pitch flow */}
        <ProblemSection />
        <SolutionSection />
        
        {/* 3. WHY NOW - Urgency */}
        <WhyNowSection />
        
        {/* 4. BENCHMARKS - Proof tied to theorems */}
        <BenchmarksSection />
        
        {/* 5. CALCULATOR - ROI focus for $3M seed */}
        <CalculatorSection />
        
        {/* 6. TECHNOLOGY - Deep dive for technical investors */}
        <TechnologySection />
        <BitNetProofSection />
        
        {/* 7. MARKET & GTM - Business case */}
        <MarketSection />
        <GTMSection />
        
        {/* 8. COMPETITION - Differentiation */}
        <CompetitionSection />
        <HLSCompetitionSection />
        
        {/* 9. ROADMAP - Execution plan */}
        <RoadmapSection />
        <MilestonesSection />
        
        {/* 10. TEAM - Trust */}
        <TeamSection />
        
        {/* 11. ECOSYSTEM - Network effects */}
        <EcosystemSection />
        
        {/* 12. ADDITIONAL PROOF SECTIONS */}
        <TractionSection />
        <MiningSolutionSection />
        <ProductSection />
        <FinancialsSection />
        <BusinessModelSection />
        <SU3MiningRealitySection />
        <TechAssetsSection />
        <CalculatorLogicSection />
        <ScientificFoundationSection />
        <VisionSection />
        <PhoenixNumberSection />
        
        {/* 13. INVEST - Final CTA */}
        <InvestSection />
      </Suspense>
      
      <Footer />
    </main>
  )
}
