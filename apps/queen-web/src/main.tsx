import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { ThreeKingdoms } from './components/ThreeKingdoms';
import { StatusDashboard } from './components/StatusDashboard';
import { EpisodeViewer } from './components/EpisodeViewer';
import { ImprovementPanel } from './components/ImprovementPanel';

import './styles/index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      staleTime: 5000,
      retry: 1,
    },
  },
});

function App() {
  return (
    <div className="app">
      <header className="app-header">
        <h1>👑 Queen Trinity</h1>
        <p className="subtitle">Self-Improving Container • φ² + 1/φ² = 3</p>
      </header>

      <ThreeKingdoms />

      <main className="app-main">
        <div className="dashboard-grid">
          <StatusDashboard />
          <ImprovementPanel />
        </div>

        <EpisodeViewer />
      </main>
    </div>
  );
}

const root = createRoot(document.getElementById('root')!);
root.render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>
);
