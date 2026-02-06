import React from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <h1 className="hero__title">{siteConfig.title}</h1>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/">
            Get Started
          </Link>
        </div>
      </div>
    </header>
  );
}

function Feature({title, description}: {title: string; description: string}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center padding-horiz--md">
        <h3>{title}</h3>
        <p>{description}</p>
      </div>
    </div>
  );
}

const FeatureList = [
  {
    title: 'Ternary Computing',
    description: 'Base-3 arithmetic with optimal information density. 1.58 bits per trit vs 1 bit per binary digit.',
  },
  {
    title: 'BitNet Integration',
    description: 'Native support for Microsoft BitNet b1.58 ternary neural networks with FFI integration.',
  },
  {
    title: 'Vector Symbolic Architecture',
    description: 'High-dimensional computing for semantic reasoning, memory, and symbolic AI.',
  },
];

export default function Home(): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="Ternary Computing Framework with VSA, BitNet & VIBEE">
      <HomepageHeader />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              {FeatureList.map((props, idx) => (
                <Feature key={idx} {...props} />
              ))}
            </div>
          </div>
        </section>
        <section className={styles.formula}>
          <div className="container">
            <div className="text--center">
              <h2>The Trinity Identity</h2>
              <p className={styles.mathFormula}>
                φ² + 1/φ² = 3
              </p>
              <p>The golden ratio squared plus its inverse squared equals the optimal computing base.</p>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
