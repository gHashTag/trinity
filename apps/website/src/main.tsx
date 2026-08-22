import { StrictMode, lazy, Suspense } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import FormatSelection from './pages/FormatSelection'
import './index.css'
import App from './App.tsx'
import { I18nProvider } from './i18n/context.tsx'
import GlobalStarfield from './components/GlobalStarfield.tsx'

// Only "/" is eager — it is the route every visitor lands on. The others were
// static imports, which put all of them in the entry chunk (843 kB) and made the
// landing page wait on code nobody had asked for yet.
const QuantumLab = lazy(() => import('./pages/QuantumLab.tsx'))
const Playground = lazy(() => import('./pages/Playground.tsx'))
const CosmicChat = lazy(() => import('./pages/CosmicChat.tsx'))
const TrinityCanvas = lazy(() => import('./pages/TrinityCanvas.tsx'))
const TrinityCanvasWasm = lazy(() => import('./components/TrinityCanvasWasm.tsx'))
const ProductionDashboard = lazy(() => import('./components/ProductionDashboard.tsx'))
const TechTreePage = lazy(() => import('./pages/TechTreePage.tsx'))
const HardwareVerification = lazy(() => import('./pages/HardwareVerification.tsx'))
const Start = lazy(() => import('./pages/Start.tsx'))
const Course = lazy(() => import('./pages/Course.tsx'))
const CaseStudies = lazy(() => import('./pages/CaseStudies.tsx'))
const GFT = lazy(() => import('./pages/GFT.tsx'))
const Licensing = lazy(() => import('./pages/Licensing.tsx'))
const Proof = lazy(() => import('./pages/Proof.tsx'))
const AboutAuthor = lazy(() => import('./pages/AboutAuthor.tsx'))
const Resources = lazy(() => import('./pages/Resources.tsx'))
const Foundry = lazy(() => import('./pages/Foundry.tsx'))
const Queen = lazy(() => import('./pages/Queen.tsx'))
// Blog exports two components rather than a default, so the module has to be
// unwrapped into the shape lazy() expects.
const BlogIndex = lazy(() => import('./pages/Blog.tsx').then(m => ({ default: m.BlogIndex })))
const BlogPost = lazy(() => import('./pages/Blog.tsx').then(m => ({ default: m.BlogPost })))

const RouteFallback = () => (
  // spinSlow, not spin — index.css only defines the former.
  <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', borderRadius: '50%', animation: 'spinSlow 1s linear infinite' }} />
  </div>
)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <I18nProvider>
      <HashRouter>
        {/* Звёзды монтируются один раз над Routes: слой fixed, ключа маршрута у
            него нет, поэтому при переходе между страницами поле не пересоздаётся
            и не мигает. */}
        <GlobalStarfield />
        <Suspense fallback={<RouteFallback />}>
          <Routes>
            <Route path="/" element={<App />} />
            <Route path="/dashboard" element={<ProductionDashboard />} />
            <Route path="/tree" element={<TechTreePage />} />
            <Route path="/start" element={<Start />} />
            <Route path="/select" element={<FormatSelection />} />
            <Route path="/verification" element={<HardwareVerification />} />
            <Route path="/course" element={<Course />} />
            <Route path="/cases" element={<CaseStudies />} />
            <Route path="/gft" element={<GFT />} />
            <Route path="/ip" element={<Licensing />} />
            <Route path="/proof" element={<Proof />} />
            <Route path="/about" element={<AboutAuthor />} />
            <Route path="/blog" element={<BlogIndex />} />
            <Route path="/blog/:slug" element={<BlogPost />} />
            <Route path="/resources" element={<Resources />} />
            {/* Клуб. /club — короткий синоним для ссылок в рилсах и профиле. */}
            <Route path="/foundry" element={<Foundry />} />
            <Route path="/club" element={<Navigate to="/foundry" replace />} />
            <Route path="/queen" element={<Queen />} />
            <Route path="/canvas" element={<TrinityCanvas />} />
            <Route path="/quantum" element={<QuantumLab />} />
            <Route path="/lab" element={<QuantumLab />} />
            <Route path="/play" element={<Playground />} />
            <Route path="/chat" element={<CosmicChat />} />
            <Route path="/wasm" element={<TrinityCanvasWasm />} />
            <Route path="/viz/*" element={<Navigate to="/quantum" replace />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </HashRouter>
    </I18nProvider>
  </StrictMode>,
)
