import { useQuery } from '@tanstack/react-query';

interface Episode {
  id: string;
  timestamp: number;
  source: string;
  action_type: string;
  outcome: string;
  success: boolean;
  duration_ms: number;
}

export function EpisodeViewer() {
  const { data: episodes, isLoading } = useQuery<Episode[]>({
    queryKey: ['episodes'],
    queryFn: async () => {
      const res = await fetch('/api/episodes');
      return res.json();
    },
    refetchInterval: 30000,
  });

  return (
    <div className="episode-viewer">
      <h2>📜 Recent Episodes</h2>
      {isLoading ? (
        <div className="loading">Loading episodes...</div>
      ) : (
        <div className="episodes-list">
          {episodes?.slice(0, 10).map((episode) => (
            <EpisodeCard key={episode.id} episode={episode} />
          ))}
        </div>
      )}
    </div>
  );
}

function EpisodeCard({ episode }: { episode: Episode }) {
  return (
    <div className={`episode-card ${episode.success ? 'success' : 'failure'}`}>
      <div className="episode-header">
        <span className="episode-id">{episode.id.slice(0, 8)}</span>
        <span className="episode-timestamp">
          {new Date(episode.timestamp).toLocaleString()}
        </span>
      </div>
      <div className="episode-body">
        <span className="episode-action">{episode.action_type}</span>
        <span className="episode-outcome">{episode.outcome}</span>
      </div>
      <div className="episode-footer">
        <span>Duration: {episode.duration_ms}ms</span>
        <span className={episode.success ? 'success-badge' : 'failure-badge'}>
          {episode.success ? '✓ Success' : '✗ Failed'}
        </span>
      </div>
    </div>
  );
}
