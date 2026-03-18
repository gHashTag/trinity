import React from 'react';

interface TheoremProps {
  number?: number | string;
  title?: string;
  children: React.ReactNode;
}

export function Theorem({ number, title, children }: TheoremProps): JSX.Element {
  return (
    <div className="theorem">
      <div className="theorem-title">
        Theorem{number ? ` ${number}` : ''}{title ? `: ${title}` : ''}
      </div>
      {children}
    </div>
  );
}

export function Lemma({ number, title, children }: TheoremProps): JSX.Element {
  return (
    <div className="lemma">
      <div className="lemma-title">
        Lemma{number ? ` ${number}` : ''}{title ? `: ${title}` : ''}
      </div>
      {children}
    </div>
  );
}

export function Definition({ number, title, children }: TheoremProps): JSX.Element {
  return (
    <div className="definition">
      <div className="definition-title">
        Definition{number ? ` ${number}` : ''}{title ? `: ${title}` : ''}
      </div>
      {children}
    </div>
  );
}

export function Corollary({ number, title, children }: TheoremProps): JSX.Element {
  return (
    <div className="corollary">
      <div className="corollary-title">
        Corollary{number ? ` ${number}` : ''}{title ? `: ${title}` : ''}
      </div>
      {children}
    </div>
  );
}

interface ProofProps {
  children: React.ReactNode;
}

export function Proof({ children }: ProofProps): JSX.Element {
  return (
    <div className="proof">
      <div className="proof-title">Proof</div>
      {children}
      <span className="qed"></span>
    </div>
  );
}

export function Example({ number, title, children }: TheoremProps): JSX.Element {
  return (
    <div className="example">
      <div className="example-title">
        Example{number ? ` ${number}` : ''}{title ? `: ${title}` : ''}
      </div>
      {children}
    </div>
  );
}

export function Remark({ number, title, children }: TheoremProps): JSX.Element {
  return (
    <div className="remark">
      <div className="remark-title">
        Remark{number ? ` ${number}` : ''}{title ? `: ${title}` : ''}
      </div>
      {children}
    </div>
  );
}
