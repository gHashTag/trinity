import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import QuantumLab from './pages/QuantumLab.tsx'
import Playground from './pages/Playground.tsx'
import CosmicChat from './pages/CosmicChat.tsx'
import TrinityCanvas from './pages/TrinityCanvas.tsx'
import TrinityCanvasWasm from './components/TrinityCanvasWasm.tsx'
import ProductionDashboard from './components/ProductionDashboard.tsx'
import TechTreePage from './pages/TechTreePage.tsx'
import HardwareVerification from './pages/HardwareVerification.tsx'
import Course from './pages/Course.tsx'
import Licensing from './pages/Licensing.tsx'
import Proof from './pages/Proof.tsx'
import AboutAuthor from './pages/AboutAuthor.tsx'
import { I18nProvider } from './i18n/context.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <I18nProvider>
      <HashRouter>
        <Routes>
          <Route path="/" element={<App />} />
          <Route path="/dashboard" element={<ProductionDashboard />} />
          <Route path="/tree" element={<TechTreePage />} />
          <Route path="/verification" element={<HardwareVerification />} />
          <Route path="/course" element={<Course />} />
          <Route path="/ip" element={<Licensing />} />
          <Route path="/proof" element={<Proof />} />
          <Route path="/about" element={<AboutAuthor />} />
          <Route path="/canvas" element={<TrinityCanvas />} />
          <Route path="/quantum" element={<QuantumLab />} />
          <Route path="/lab" element={<QuantumLab />} />
          <Route path="/play" element={<Playground />} />
          <Route path="/chat" element={<CosmicChat />} />
          <Route path="/wasm" element={<TrinityCanvasWasm />} />
          <Route path="/viz/*" element={<Navigate to="/quantum" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </HashRouter>
    </I18nProvider>
  </StrictMode>,
)
