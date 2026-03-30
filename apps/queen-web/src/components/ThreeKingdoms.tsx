import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';

export function ThreeKingdoms() {
  const [activeTab, setActiveTab] = useState<'brain' | 'body' | 'spirit'>('brain');

  return (
    <nav className="three-kingdoms-nav">
      <Link to="?kingdom=brain" className={`tab ${activeTab === 'brain' ? 'active' : ''}`}>
        🧠 Brain (Strand I)
      </Link>
      <Link to="?kingdom=body" className={`tab ${activeTab === 'body' ? 'active' : ''}`}>
        💪 Body (Strand II)
      </Link>
      <Link to="?kingdom=spirit" className={`tab ${activeTab === 'spirit' ? 'active' : ''}`}>
        🔮 Spirit (Strand III)
      </Link>
    </nav>
  );
}
