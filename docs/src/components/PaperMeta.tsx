import React from 'react';

interface PaperMetaProps {
  authors?: string;
  date?: string;
  status?: string;
  affiliation?: string;
  doi?: string;
}

export default function PaperMeta({
  authors,
  date,
  status,
  affiliation,
  doi
}: PaperMetaProps): JSX.Element {
  return (
    <div className="paper-meta">
      {authors && <p><strong>Authors:</strong> {authors}</p>}
      {affiliation && <p><strong>Affiliation:</strong> {affiliation}</p>}
      {date && <p><strong>Date:</strong> {date}</p>}
      {status && <p><strong>Status:</strong> {status}</p>}
      {doi && <p><strong>DOI:</strong> <a href={`https://doi.org/${doi}`}>{doi}</a></p>}
    </div>
  );
}
