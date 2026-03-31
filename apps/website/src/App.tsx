import './App.css'
import HeroSection from './components/sections/HeroSection'
import Navigation from './components/Navigation'
import Footer from './components/Footer'

export default function App() {
  return (
    <main>
      <Navigation />

      {/* Hero Section */}
      <HeroSection />

      {/* CLI Commands */}
      <section style={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '4rem 2rem',
        background: 'var(--bg)'
      }}>
        <h1 style={{
          fontSize: '3rem',
          fontWeight: 700,
          marginBottom: '1rem',
          background: 'linear-gradient(135deg, #fff 0%, #888 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text',
          color: 'transparent'
        }}>
          TRINITY CLI
        </h1>

        <div style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '1.5rem',
          maxWidth: '600px',
          width: '100%'
        }}>
          {[
            '$ brew tap gHashTag/trinity && brew install tri',
            '$ tri agent run 420    # autonomous 8-step dev cycle',
            '$ tri cloud mail-setup zoho t27.ai'
          ].map((cmd, i) => (
            <code key={i} style={{
              display: 'block',
              padding: '1.5rem',
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid var(--border)',
              borderRadius: '8px',
              fontFamily: 'JetBrains Mono, monospace',
              fontSize: '1rem',
              color: '#fff',
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-all',
              transition: 'all 0.3s ease'
            }}>
              {cmd}
            </code>
          ))}
        </div>
      </section>

      <Footer />
    </main>
  )
}
