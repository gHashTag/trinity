import React from 'react';

interface AbstractProps {
  children: React.ReactNode;
  keywords?: string[];
}

export default function Abstract({ children, keywords }: AbstractProps): JSX.Element {
  return (
    <div className="abstract">
      <div className="abstract-title">Abstract</div>
      {children}
      {keywords && keywords.length > 0 && (
        <div className="keywords">
          <strong>Keywords:</strong> {keywords.join(', ')}
        </div>
      )}
    </div>
  );
}
