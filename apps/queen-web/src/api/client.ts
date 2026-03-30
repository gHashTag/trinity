const API_BASE = window.location.hostname === 'localhost'
  ? 'http://localhost:8080'
  : '';

export async function fetchHealth() {
  const res = await fetch(`${API_BASE}/health`);
  if (!res.ok) throw new Error('Health check failed');
  return res.json();
}

export async function fetchStatus() {
  const res = await fetch(`${API_BASE}/api/status`);
  if (!res.ok) throw new Error('Status fetch failed');
  return res.json();
}

export async function fetchEpisodes() {
  const res = await fetch(`${API_BASE}/api/episodes`);
  if (!res.ok) throw new Error('Episodes fetch failed');
  return res.json();
}

export async function triggerImprove(force = false) {
  const res = await fetch(`${API_BASE}/api/improve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ force }),
  });
  if (!res.ok) throw new Error('Improve trigger failed');
  return res.json();
}

export async function fetchPipelineStatus() {
  const res = await fetch(`${API_BASE}/api/pipeline`);
  if (!res.ok) throw new Error('Pipeline status fetch failed');
  return res.json();
}
