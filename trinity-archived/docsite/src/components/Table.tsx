import React from 'react';

interface TableProps {
  number: number | string;
  caption: string;
  children: React.ReactNode;
}

export default function Table({ number, caption, children }: TableProps): JSX.Element {
  return (
    <div className="academic-table">
      <div className="table-caption">
        <strong>Table {number}:</strong> {caption}
      </div>
      {children}
    </div>
  );
}
