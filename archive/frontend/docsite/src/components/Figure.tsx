import React from 'react';

interface FigureProps {
  number: number | string;
  caption: string;
  children: React.ReactNode;
}

export default function Figure({ number, caption, children }: FigureProps): JSX.Element {
  return (
    <figure className="academic-figure">
      {children}
      <figcaption>
        <strong>Figure {number}:</strong> {caption}
      </figcaption>
    </figure>
  );
}
