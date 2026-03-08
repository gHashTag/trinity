"use client";
import React, { useState, useCallback, lazy, Suspense } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import {
  parseFormula, molarMass, toBalancedTernary, ternarySignature,
  estimateBonds, isFibonacci, isLucas, goldenAngle, copticGlyph,
  formatSacredFormula,
  type MoleculeResult, type ElementResult,
  analyzeMolecule, analyzeElement,
} from '../../utils/chemistry';
import { getElement } from '../../data/elements';
import {
  fetchChemSacred, fetchChemElement, fetchChemBalance, fetchChemPredict,
  type ChemSacredResponse, type ChemElementResponse, type ChemBalanceResponse,
  type ChemPredictResponse, type ExtendedElement,
} from '../../services/chatApi';
import {
  analyzeDna, analyzeRna, analyzeProtein,
  type DnaAnalysis, type RnaAnalysis, type ProteinAnalysis,
} from '../../utils/biology';
import {
  analyzeHubble, analyzeDarkEnergy, predictConstants, generateExpansionTimeline,
  type HubbleResult, type DarkEnergyAnalysis, type ConstantPrediction,
} from '../../utils/cosmos';
import {
  fetchNeuroWaves, fetchNeuroConsciousness, fetchNeuroRegions,
  fetchNeuroNetwork, fetchNeuroSynapse,
  type NeuroBrainWavesResponse, type NeuroConsciousnessResponse,
  type NeuroRegionsResponse, type NeuroNetworkResponse,
  type NeuroSynapseResponse,
} from '../../services/chatApi';

const MoleculeViewer3D = lazy(() => import('../molecule3d/MoleculeViewer3D'));
const TemporalMoleculeViewer = lazy(() => import('../molecule3d/TemporalMoleculeViewer'));
const DnaHelix3D = lazy(() => import('../biology3d/DnaHelix3D'));
const UniverseExpansion3D = lazy(() => import('../cosmos3d/UniverseExpansion3D'));
const BrainConnectivity3D = lazy(() => import('../neuro3d/BrainConnectivity3D'));

// ============================================================================
// Style constants
// ============================================================================

const GOLDEN = '#ffd700';
const CYAN = '#00ccff';
const PURPLE = '#aa66ff';
const GREEN = '#00e599';

const GLASS_STYLE: React.CSSProperties = {
  background: 'rgba(255, 255, 255, 0.05)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  border: '1px solid rgba(255, 215, 0, 0.2)',
  borderRadius: '8px',
};

const MONO = 'JetBrains Mono, monospace';
const SANS = 'Outfit, sans-serif';

// ============================================================================
// SourceBadge — indicates live backend vs local computation
// ============================================================================

function SourceBadge({ source }: { source: 'live' | 'local' }) {
  const isLive = source === 'live';
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: '0.35rem',
      padding: '0.2rem 0.6rem', borderRadius: '999px',
      background: isLive ? 'rgba(0, 229, 153, 0.1)' : 'rgba(255, 215, 0, 0.1)',
      border: `1px solid ${isLive ? 'rgba(0, 229, 153, 0.3)' : 'rgba(255, 215, 0, 0.3)'}`,
      fontSize: '0.65rem', fontFamily: MONO, fontWeight: 600,
      color: isLive ? GREEN : GOLDEN,
    }}>
      <div style={{
        width: '6px', height: '6px', borderRadius: '50%',
        background: isLive ? GREEN : GOLDEN,
        boxShadow: isLive ? `0 0 6px ${GREEN}` : `0 0 6px ${GOLDEN}`,
      }} />
      {isLive ? 'Live' : 'Local'}
    </div>
  );
}

// ============================================================================
// Sub-components
// ============================================================================

function TritDisplay({ trits }: { trits: number[] }) {
  return (
    <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
      {trits.map((t, i) => (
        <div
          key={i}
          style={{
            width: '28px',
            height: '28px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '4px',
            fontSize: '0.75rem',
            fontWeight: 700,
            fontFamily: MONO,
            background: t === 1 ? 'rgba(255, 215, 0, 0.2)' : t === -1 ? 'rgba(0, 204, 255, 0.2)' : 'rgba(255, 255, 255, 0.05)',
            color: t === 1 ? GOLDEN : t === -1 ? CYAN : 'rgba(255,255,255,0.4)',
            border: `1px solid ${t === 1 ? 'rgba(255,215,0,0.4)' : t === -1 ? 'rgba(0,204,255,0.4)' : 'rgba(255,255,255,0.1)'}`,
          }}
        >
          {t === 1 ? '+1' : t === -1 ? '\u22121' : '0'}
        </div>
      ))}
    </div>
  );
}

function TernarySignatureDisplay({ sig }: { sig: { atoms: number; electrons: number; bonds: number; sum: number; label: string } }) {
  const tritSymbol = (v: number) => v === 0 ? '\u25CF' : v === 1 ? '\u25B2' : '\u25BC';
  const tritColor = (v: number) => v === 0 ? 'rgba(255,255,255,0.4)' : v === 1 ? GOLDEN : CYAN;
  const rows = [
    { name: 'Atoms', val: sig.atoms },
    { name: 'Electrons', val: sig.electrons },
    { name: 'Bonds', val: sig.bonds },
  ];
  return (
    <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginTop: '0.75rem' }}>
      <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        Ternary Signature
      </div>
      {rows.map(r => (
        <div key={r.name} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem' }}>
          <span style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.6)', fontFamily: SANS, width: '70px' }}>{r.name}</span>
          <span style={{ fontSize: '0.85rem', fontFamily: MONO, color: 'rgba(255,255,255,0.8)', width: '60px' }}>mod 3 = {r.val}</span>
          <span style={{ fontSize: '1rem', color: tritColor(r.val) }}>{tritSymbol(r.val)}</span>
        </div>
      ))}
      <div style={{ marginTop: '0.5rem', padding: '0.4rem 0.6rem', background: 'rgba(255,215,0,0.1)', borderRadius: '4px', display: 'inline-block' }}>
        <span style={{ fontSize: '0.75rem', fontFamily: MONO, color: GOLDEN, fontWeight: 600 }}>
          Sum: {sig.sum} {'\u2192'} {sig.label}
        </span>
      </div>
    </div>
  );
}

function CopticDisplay({ coptic }: { coptic: { glyph: string; value: number; kingdom: string } }) {
  const kingdomColor = coptic.kingdom === 'Matter' ? GOLDEN : coptic.kingdom === 'Energy' ? CYAN : PURPLE;
  return (
    <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginTop: '0.75rem', textAlign: 'center' }}>
      <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        Coptic Glyph
      </div>
      <div style={{ fontSize: '2.5rem', color: GOLDEN, lineHeight: 1.2 }}>{coptic.glyph}</div>
      <div style={{ fontSize: '0.8rem', fontFamily: MONO, color: 'rgba(255,255,255,0.7)', marginTop: '0.25rem' }}>
        Value: {coptic.value}
      </div>
      <div style={{ fontSize: '0.75rem', fontFamily: SANS, color: kingdomColor, marginTop: '0.25rem', fontWeight: 600 }}>
        Kingdom of {coptic.kingdom}
      </div>
    </div>
  );
}

function SacredFitRow({ label, value, fit, color }: { label: string; value: number; fit: { n: number; k: number; m: number; p: number; q: number; computed: number; error_pct: number }; color: string }) {
  return (
    <div style={{ marginBottom: '0.5rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.6)', fontFamily: SANS }}>{label}</span>
        <span style={{ fontSize: '0.8rem', fontFamily: MONO, color }}>{value.toFixed(4)}</span>
      </div>
      <div style={{ fontSize: '0.75rem', fontFamily: MONO, color: 'rgba(255,255,255,0.8)', marginTop: '0.15rem' }}>
        {formatSacredFormula(fit)} = {fit.computed.toFixed(4)}{' '}
        <span style={{ color: fit.error_pct < 0.5 ? GREEN : GOLDEN, fontSize: '0.7rem' }}>
          ({fit.error_pct.toFixed(3)}%)
        </span>
      </div>
    </div>
  );
}

function GoldenAngleSVG({ angle, sector }: { angle: number; sector: number }) {
  const r = 45;
  const cx = 55;
  const cy = 55;
  const rad = (angle * Math.PI) / 180;
  const ex = cx + r * Math.cos(rad - Math.PI / 2);
  const ey = cy + r * Math.sin(rad - Math.PI / 2);
  const largeArc = angle > 180 ? 1 : 0;

  return (
    <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginTop: '0.75rem', textAlign: 'center' }}>
      <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        Golden Angle Position
      </div>
      <svg width="110" height="110" viewBox="0 0 110 110">
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="1" />
        {[0, 45, 90, 135, 180, 225, 270, 315].map(deg => {
          const rr = (deg * Math.PI) / 180;
          return (
            <line key={deg}
              x1={cx} y1={cy}
              x2={cx + r * Math.cos(rr - Math.PI / 2)}
              y2={cy + r * Math.sin(rr - Math.PI / 2)}
              stroke="rgba(255,255,255,0.05)" strokeWidth="1"
            />
          );
        })}
        <path
          d={`M ${cx} ${cy - r} A ${r} ${r} 0 ${largeArc} 1 ${ex} ${ey}`}
          fill="none"
          stroke={GOLDEN}
          strokeWidth="2"
          opacity="0.8"
        />
        <circle cx={ex} cy={ey} r="4" fill={GOLDEN} />
        <circle cx={cx} cy={cy} r="2" fill="rgba(255,255,255,0.3)" />
      </svg>
      <div style={{ fontSize: '0.8rem', fontFamily: MONO, color: GOLDEN, marginTop: '0.25rem' }}>
        {angle.toFixed(2)}{'\u00B0'}
      </div>
      <div style={{ fontSize: '0.7rem', fontFamily: SANS, color: 'rgba(255,255,255,0.5)' }}>
        Sector {sector} of 8
      </div>
    </div>
  );
}

// ============================================================================
// Extended Element Panel (shown when source === 'live')
// ============================================================================

function ExtendedElementPanel({ el }: { el: ExtendedElement }) {
  const rows: [string, string | null][] = [
    ['Electron Config', el.electron_config || null],
    ['Block', el.block || null],
    ['Category', el.category || null],
    ['Valence', String(el.valence)],
    ['Electron Affinity', el.electron_affinity != null ? `${el.electron_affinity.toFixed(2)} kJ/mol` : null],
    ['Atomic Radius', el.atomic_radius != null ? `${el.atomic_radius.toFixed(1)} pm` : null],
    ['Density', el.density != null ? `${el.density.toFixed(4)} g/cm\u00B3` : null],
    ['Melting Point', el.melting_point != null ? `${el.melting_point.toFixed(2)} K` : null],
    ['Boiling Point', el.boiling_point != null ? `${el.boiling_point.toFixed(2)} K` : null],
    ['Discoverer', el.discoverer || null],
    ['Etymology', el.etymology || null],
  ];
  const visible = rows.filter(([, v]) => v != null && v !== 'null' && v !== '');
  if (visible.length === 0) return null;

  return (
    <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginTop: '0.75rem' }}>
      <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        Extended Data <span style={{ color: GREEN, fontSize: '0.6rem' }}>(backend)</span>
      </div>
      {visible.map(([label, val]) => (
        <div key={label} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.2rem' }}>
          <span style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS }}>{label}</span>
          <span style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.8)', fontFamily: MONO, maxWidth: '60%', textAlign: 'right', wordBreak: 'break-all' }}>{val}</span>
        </div>
      ))}
    </div>
  );
}

// ============================================================================
// Molecule Result Display
// ============================================================================

function MoleculeResultView({ result, source }: { result: MoleculeResult; source: 'live' | 'local' }) {
  return (
    <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
      {/* Header: Mass + Sacred Fit */}
      <div style={{ textAlign: 'center', marginBottom: '1rem', padding: '1rem', background: 'rgba(255, 215, 0, 0.08)', border: '1px solid rgba(255, 215, 0, 0.25)', borderRadius: '8px', position: 'relative' }}>
        <div style={{ position: 'absolute', top: '0.5rem', right: '0.5rem' }}>
          <SourceBadge source={source} />
        </div>
        <div style={{ fontSize: '1.5rem', fontWeight: 700, color: GOLDEN, fontFamily: MONO }}>
          {result.molarMass.toFixed(4)} <span style={{ fontSize: '0.8rem', fontWeight: 400, color: 'rgba(255,255,255,0.5)' }}>g/mol</span>
        </div>
        <div style={{ fontSize: '0.8rem', fontFamily: MONO, color: 'rgba(255,255,255,0.8)', marginTop: '0.5rem' }}>
          {formatSacredFormula(result.sacredFit)}
        </div>
        <div style={{ fontSize: '0.7rem', color: result.sacredFit.error_pct < 0.5 ? GREEN : GOLDEN, marginTop: '0.25rem', fontFamily: MONO }}>
          = {result.sacredFit.computed.toFixed(4)} ({result.sacredFit.error_pct.toFixed(3)}% error)
        </div>
      </div>

      {/* Element Breakdown Table */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Element Breakdown
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '50px 40px 80px 60px', gap: '0.25rem 0.5rem', fontSize: '0.75rem', fontFamily: MONO }}>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>Sym</span>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>Cnt</span>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>Mass</span>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>%</span>
          {result.elements.map(e => (
            <React.Fragment key={e.element.symbol}>
              <span style={{ color: GOLDEN, fontWeight: 600 }}>{e.element.symbol}</span>
              <span style={{ color: 'rgba(255,255,255,0.8)' }}>{e.count}</span>
              <span style={{ color: 'rgba(255,255,255,0.7)' }}>{e.massContrib.toFixed(3)}</span>
              <span style={{ color: CYAN }}>{e.pct.toFixed(1)}%</span>
            </React.Fragment>
          ))}
        </div>
        <div style={{ marginTop: '0.5rem', fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
          Total: {result.totalAtoms} atoms, {result.totalElectrons} electrons
        </div>
      </div>

      {/* Bond Analysis */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Bond Analysis
        </div>
        <div style={{ display: 'flex', gap: '1.5rem', fontSize: '0.8rem', fontFamily: MONO }}>
          <div>
            <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: '0.7rem' }}>Bonds</span>
            <div style={{ color: CYAN, fontWeight: 600 }}>{result.bonds.totalBonds}</div>
          </div>
          <div>
            <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: '0.7rem' }}>Energy</span>
            <div style={{ color: GOLDEN, fontWeight: 600 }}>{result.bonds.bondEnergy} kJ/mol</div>
          </div>
        </div>
        <div style={{ marginTop: '0.5rem', fontSize: '0.75rem', fontFamily: MONO, color: 'rgba(255,255,255,0.7)' }}>
          {formatSacredFormula(result.bondSacredFit)}{' '}
          <span style={{ color: result.bondSacredFit.error_pct < 0.5 ? GREEN : GOLDEN, fontSize: '0.7rem' }}>
            ({result.bondSacredFit.error_pct.toFixed(3)}%)
          </span>
        </div>
      </div>

      {/* Ternary Signature */}
      <TernarySignatureDisplay sig={result.signature} />

      {/* Coptic Glyph */}
      <CopticDisplay coptic={result.coptic} />
    </motion.div>
  );
}

// ============================================================================
// Element Result Display
// ============================================================================

function ElementResultView({ result, source, extendedElement }: { result: ElementResult; source: 'live' | 'local'; extendedElement?: ExtendedElement }) {
  return (
    <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
      {/* Element Card */}
      <div style={{ textAlign: 'center', marginBottom: '1rem', padding: '1rem', background: 'rgba(255, 215, 0, 0.08)', border: '1px solid rgba(255, 215, 0, 0.25)', borderRadius: '8px', position: 'relative' }}>
        <div style={{ position: 'absolute', top: '0.5rem', right: '0.5rem' }}>
          <SourceBadge source={source} />
        </div>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO }}>{result.element.number}</div>
        <div style={{ fontSize: '2rem', fontWeight: 700, color: GOLDEN, fontFamily: SANS }}>{result.element.symbol}</div>
        <div style={{ fontSize: '0.85rem', color: 'rgba(255,255,255,0.8)', fontFamily: SANS }}>{result.element.name}</div>
        <div style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.6)', fontFamily: MONO, marginTop: '0.25rem' }}>
          {result.element.mass.toFixed(4)} u
        </div>
        <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', marginTop: '0.5rem', fontSize: '0.7rem', fontFamily: MONO, color: 'rgba(255,255,255,0.5)' }}>
          <span>Group {result.element.group}</span>
          <span>Period {result.element.period}</span>
        </div>
      </div>

      {/* Extended Element Panel (backend only) */}
      {extendedElement && <ExtendedElementPanel el={extendedElement} />}

      {/* Balanced Ternary */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Balanced Ternary of Z={result.element.number}
        </div>
        <TritDisplay trits={result.balancedTernary} />
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO, marginTop: '0.25rem' }}>
          {result.balancedTernary.length} trits
        </div>
      </div>

      {/* Sacred Fits */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Sacred Formula Decomposition
        </div>
        <SacredFitRow label="Mass" value={result.element.mass} fit={result.sacredMass} color={GOLDEN} />
        {result.sacredIE && (
          <SacredFitRow label="Ionization Energy" value={result.element.ionization_energy!} fit={result.sacredIE} color={CYAN} />
        )}
        {result.sacredEN && (
          <SacredFitRow label="Electronegativity" value={result.element.electronegativity!} fit={result.sacredEN} color={PURPLE} />
        )}
      </div>

      {/* Fibonacci / Lucas + Golden Angle — side by side */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
        {/* Sequence Check */}
        <div style={{ ...GLASS_STYLE, padding: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Sequences
          </div>
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
            <span style={{
              fontSize: '0.7rem', fontFamily: MONO, padding: '0.2rem 0.5rem', borderRadius: '4px',
              background: result.fibonacci.is ? 'rgba(255,215,0,0.2)' : 'rgba(255,255,255,0.05)',
              color: result.fibonacci.is ? GOLDEN : 'rgba(255,255,255,0.3)',
              border: `1px solid ${result.fibonacci.is ? 'rgba(255,215,0,0.4)' : 'rgba(255,255,255,0.1)'}`,
            }}>
              Fib{result.fibonacci.is ? ` #${result.fibonacci.index}` : ' \u2717'}
            </span>
            <span style={{
              fontSize: '0.7rem', fontFamily: MONO, padding: '0.2rem 0.5rem', borderRadius: '4px',
              background: result.lucas.is ? 'rgba(0,204,255,0.2)' : 'rgba(255,255,255,0.05)',
              color: result.lucas.is ? CYAN : 'rgba(255,255,255,0.3)',
              border: `1px solid ${result.lucas.is ? 'rgba(0,204,255,0.4)' : 'rgba(255,255,255,0.1)'}`,
            }}>
              Lucas{result.lucas.is ? ` #${result.lucas.index}` : ' \u2717'}
            </span>
          </div>
        </div>

        {/* Golden Angle */}
        <GoldenAngleSVG angle={result.golden.angle} sector={result.golden.sector} />
      </div>

      {/* Coptic Glyph */}
      <CopticDisplay coptic={result.coptic} />
    </motion.div>
  );
}

// ============================================================================
// Balance Result Display (backend-only feature)
// ============================================================================

function BalanceResultView({ result }: { result: ChemBalanceResponse }) {
  return (
    <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
      {/* Balanced Equation Header */}
      <div style={{ textAlign: 'center', marginBottom: '1rem', padding: '1rem', background: 'rgba(255, 215, 0, 0.08)', border: '1px solid rgba(255, 215, 0, 0.25)', borderRadius: '8px', position: 'relative' }}>
        <div style={{ position: 'absolute', top: '0.5rem', right: '0.5rem' }}>
          <SourceBadge source="live" />
        </div>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Balanced Equation
        </div>
        <div style={{ fontSize: '1.1rem', fontWeight: 700, color: GOLDEN, fontFamily: MONO, wordBreak: 'break-all' }}>
          {result.balanced}
        </div>
      </div>

      {/* Coefficients */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Coefficients
        </div>
        <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap' }}>
          <div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: SANS, marginBottom: '0.25rem' }}>Reactants</div>
            {result.coefficients.reactants.map((r, i) => (
              <div key={i} style={{ fontSize: '0.8rem', fontFamily: MONO, color: CYAN }}>
                <span style={{ color: GOLDEN, fontWeight: 600 }}>{r.coefficient}</span> {r.formula}
              </div>
            ))}
          </div>
          <div style={{ color: 'rgba(255,255,255,0.3)', display: 'flex', alignItems: 'center', fontSize: '1.2rem' }}>{'\u2192'}</div>
          <div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: SANS, marginBottom: '0.25rem' }}>Products</div>
            {result.coefficients.products.map((p, i) => (
              <div key={i} style={{ fontSize: '0.8rem', fontFamily: MONO, color: CYAN }}>
                <span style={{ color: GOLDEN, fontWeight: 600 }}>{p.coefficient}</span> {p.formula}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Atom Conservation */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Atom Conservation
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '60px 60px 60px 40px', gap: '0.2rem 0.5rem', fontSize: '0.75rem', fontFamily: MONO }}>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>Element</span>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>Left</span>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>Right</span>
          <span style={{ color: 'rgba(255,255,255,0.4)' }}>OK</span>
          {result.verification.elements.map((v, i) => (
            <React.Fragment key={i}>
              <span style={{ color: GOLDEN, fontWeight: 600 }}>{v.element}</span>
              <span style={{ color: 'rgba(255,255,255,0.8)' }}>{v.left}</span>
              <span style={{ color: 'rgba(255,255,255,0.8)' }}>{v.right}</span>
              <span style={{ color: v.ok ? GREEN : '#ff5050' }}>{v.ok ? '\u2713' : '\u2717'}</span>
            </React.Fragment>
          ))}
        </div>
        <div style={{ marginTop: '0.5rem', padding: '0.3rem 0.6rem', background: result.verification.balanced ? 'rgba(0,229,153,0.1)' : 'rgba(255,80,80,0.1)', borderRadius: '4px', display: 'inline-block' }}>
          <span style={{ fontSize: '0.7rem', fontFamily: MONO, color: result.verification.balanced ? GREEN : '#ff5050', fontWeight: 600 }}>
            {result.verification.balanced ? '\u2713 BALANCED' : '\u2717 NOT BALANCED'}
          </span>
        </div>
      </div>
    </motion.div>
  );
}

// ============================================================================
// Prediction Result Display (backend-only feature)
// ============================================================================

const REACTION_TYPE_COLORS: Record<string, string> = {
  combustion: '#ff6b35',
  acid_base: PURPLE,
  single_displacement: CYAN,
  synthesis: GOLDEN,
  decomposition: '#888',
  double_displacement: '#00e599',
};

function PredictionResultView({ result }: { result: ChemPredictResponse }) {
  const typeColor = REACTION_TYPE_COLORS[result.reaction_type] || 'rgba(255,255,255,0.5)';
  const confPct = Math.round(result.confidence * 100);
  const confColor = confPct >= 80 ? GREEN : confPct >= 60 ? GOLDEN : '#ff5050';
  const typeLabel = result.reaction_type.replace(/_/g, ' ');

  return (
    <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
      {/* Balanced Equation Header */}
      <div style={{ textAlign: 'center', marginBottom: '1rem', padding: '1rem', background: 'rgba(255, 215, 0, 0.08)', border: '1px solid rgba(255, 215, 0, 0.25)', borderRadius: '8px', position: 'relative' }}>
        <div style={{ position: 'absolute', top: '0.5rem', right: '0.5rem' }}>
          <SourceBadge source="live" />
        </div>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Predicted Reaction
        </div>
        <div style={{ fontSize: '1.1rem', fontWeight: 700, color: GOLDEN, fontFamily: MONO, wordBreak: 'break-all' }}>
          {result.balanced}
        </div>
      </div>

      {/* Reaction Type Badge + Confidence */}
      <div style={{ display: 'flex', gap: '0.75rem', marginBottom: '0.75rem', flexWrap: 'wrap' }}>
        {/* Type Badge */}
        <div style={{
          padding: '0.3rem 0.8rem', borderRadius: '999px',
          background: `${typeColor}20`, border: `1px solid ${typeColor}50`,
          fontSize: '0.75rem', fontFamily: SANS, fontWeight: 600,
          color: typeColor, textTransform: 'uppercase', letterSpacing: '0.04em',
        }}>
          {typeLabel}
        </div>
        {/* Confidence Gauge */}
        <div style={{ flex: 1, minWidth: '120px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.2rem' }}>
            <span style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: SANS }}>Confidence</span>
            <span style={{ fontSize: '0.75rem', fontFamily: MONO, color: confColor, fontWeight: 600 }}>{confPct}%</span>
          </div>
          <div style={{ height: '6px', background: 'rgba(255,255,255,0.08)', borderRadius: '3px', overflow: 'hidden' }}>
            <div style={{
              height: '100%', width: `${confPct}%`, borderRadius: '3px',
              background: confColor, transition: 'width 0.5s ease',
            }} />
          </div>
        </div>
      </div>

      {/* Explanation */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Explanation
        </div>
        <div style={{ fontSize: '0.8rem', fontFamily: SANS, color: 'rgba(255,255,255,0.8)', fontStyle: 'italic' }}>
          {result.explanation}
        </div>
      </div>

      {/* Reactants -> Products */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Reactants & Products
        </div>
        <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
          <div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: SANS, marginBottom: '0.25rem' }}>Reactants</div>
            {result.reactants.map((r, i) => (
              <div key={i} style={{ fontSize: '0.85rem', fontFamily: MONO, color: CYAN }}>{r}</div>
            ))}
          </div>
          <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: '1.2rem' }}>{'\u2192'}</div>
          <div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: SANS, marginBottom: '0.25rem' }}>Products</div>
            {result.products.map((p, i) => (
              <div key={i} style={{ fontSize: '0.85rem', fontFamily: MONO, color: GOLDEN, fontWeight: 600 }}>{p}</div>
            ))}
          </div>
        </div>
      </div>

      {/* Product Sacred Fits */}
      {result.product_details && result.product_details.length > 0 && (
        <div style={{ ...GLASS_STYLE, padding: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Product Sacred Decomposition
          </div>
          {result.product_details.map((pd, i) => (
            <div key={i} style={{ marginBottom: i < result.product_details.length - 1 ? '0.6rem' : 0, paddingBottom: i < result.product_details.length - 1 ? '0.6rem' : 0, borderBottom: i < result.product_details.length - 1 ? '1px solid rgba(255,255,255,0.06)' : 'none' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.15rem' }}>
                <span style={{ fontSize: '0.85rem', fontFamily: MONO, color: GOLDEN, fontWeight: 600 }}>{pd.formula}</span>
                <span style={{ fontSize: '0.8rem', fontFamily: MONO, color: 'rgba(255,255,255,0.7)' }}>{pd.mass.toFixed(4)} g/mol</span>
              </div>
              <div style={{ fontSize: '0.75rem', fontFamily: MONO, color: 'rgba(255,255,255,0.6)' }}>
                {formatSacredFormula(pd.sacred_fit)} = {pd.sacred_fit.computed.toFixed(4)}{' '}
                <span style={{ color: pd.sacred_fit.error_pct < 0.5 ? GREEN : GOLDEN, fontSize: '0.7rem' }}>
                  ({pd.sacred_fit.error_pct.toFixed(3)}%)
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </motion.div>
  );
}

// ============================================================================
// Biology Result View (v14.0)
// ============================================================================

function BiologyResultView({ result, source }: { result: DnaAnalysis | RnaAnalysis | ProteinAnalysis; source: 'live' | 'local' }) {
  const isDna = 'complement' in result;
  const isRna = 'dnaTemplate' in result;
  const isProtein = 'hydrophobicRatio' in result;

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      style={{ marginTop: '1rem' }}
    >
      {/* Header with source badge */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.8rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          {isDna ? 'DNA Analysis' : isRna ? 'RNA Analysis' : 'Protein Analysis'}
        </div>
        <SourceBadge source={source} />
      </div>

      {/* Sequence info */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Sequence
        </div>
        <div style={{ fontSize: '0.85rem', fontFamily: MONO, color: '#fff', wordBreak: 'break-all' }}>
          {result.sequence}
        </div>
        <div style={{ display: 'flex', gap: '1rem', marginTop: '0.5rem', fontSize: '0.75rem', fontFamily: MONO }}>
          <span style={{ color: 'rgba(255,255,255,0.6)' }}>Length: {result.length}</span>
          {isDna && <span style={{ color: CYAN }}>MW: {(result as DnaAnalysis).molecularWeight.toFixed(2)} g/mol</span>}
          {isProtein && <span style={{ color: CYAN }}>MW: {(result as ProteinAnalysis).molecularWeight.toFixed(2)} Da</span>}
          {isRna && <span style={{ color: CYAN }}>MW: {(result as RnaAnalysis).molecularWeight.toFixed(2)} g/mol</span>}
        </div>
      </div>

      {/* Complement (DNA only) */}
      {isDna && (
        <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Complement Strand
          </div>
          <div style={{ fontSize: '0.85rem', fontFamily: MONO, color: CYAN }}>
            {(result as DnaAnalysis).complement}
          </div>
        </div>
      )}

      {/* RNA (DNA only) */}
      {isDna && (
        <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Transcribed RNA
          </div>
          <div style={{ fontSize: '0.85rem', fontFamily: MONO, color: MAGENTA }}>
            {(result as DnaAnalysis).rna}
          </div>
        </div>
      )}

      {/* GC Content (DNA only) */}
      {isDna && (
        <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            GC Content
          </div>
          <div style={{ display: 'flex', gap: '1rem', fontSize: '0.85rem', fontFamily: MONO }}>
            <span style={{ color: 'rgba(255,255,255,0.8)' }}>
              {(result as DnaAnalysis).gcContent} / {(result as DnaAnalysis).gcContent + (result as DnaAnalysis).length - (result as DnaAnalysis).gcContent}
            </span>
            <span style={{ color: (result as DnaAnalysis).isPhiProportioned ? GOLDEN : 'rgba(255,255,255,0.6)' }}>
              {(result as DnaAnalysis).gcRatio.toFixed(3)} {(result as DnaAnalysis).isPhiProportioned && ' ≈ φ'}
            </span>
          </div>
        </div>
      )}

      {/* Sacred Fit */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Sacred Formula Fit
        </div>
        <div style={{ fontSize: '0.85rem', fontFamily: MONO, color: 'rgba(255,255,255,0.9)' }}>
          V = {formatSacredFormula(result.sacredFit)} = {result.sacredFit.computed.toFixed(4)}{' '}
          <span style={{ color: result.sacredFit.error_pct < 1 ? GREEN : result.sacredFit.error_pct < 5 ? GOLDEN : '#ff5050' }}>
            ({result.sacredFit.error_pct.toFixed(3)}%)
          </span>
        </div>
      </div>

      {/* Sacred Properties */}
      <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Sacred Properties
        </div>
        <div style={{ fontSize: '0.8rem', fontFamily: SANS }}>
          {isDna && (result as DnaAnalysis).isFibonacciLength && (
            <div style={{ color: GOLDEN, marginBottom: '0.25rem' }}>
              ✓ Fibonacci length ({result.length} bp)
            </div>
          )}
          {isDna && (result as DnaAnalysis).ternary && (
            <div style={{ color: 'rgba(255,255,255,0.7)', fontSize: '0.75rem' }}>
              Purines: {(result as DnaAnalysis).ternary.purines} Pyrimidines: {(result as DnaAnalysis).ternary.pyrimidines}
            </div>
          )}
          {isProtein && (result as ProteinAnalysis).isFibonacciLength && (
            <div style={{ color: GOLDEN, marginBottom: '0.25rem' }}>
              ✓ Fibonacci length ({result.length} aa)
            </div>
          )}
        </div>
      </div>

      {/* Protein Translation (DNA only) */}
      {isDna && (result as DnaAnalysis).protein && (
        <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Protein Translation
          </div>
          <div style={{ fontSize: '0.85rem', fontFamily: MONO, color: GREEN }}>
            {(result as DnaAnalysis).protein}
          </div>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', marginTop: '0.25rem' }}>
            {(result as DnaAnalysis).proteinLength} amino acids
          </div>
        </div>
      )}
    </motion.div>
  );
}

// ============================================================================
// Cosmology Result View (v15.0)
// ============================================================================

function CosmosResultView({
  result,
  source
}: {
  result: HubbleResult | DarkEnergyAnalysis | ConstantPrediction[];
  source: 'live' | 'local';
}) {
  const isHubble = 'early' in result;
  const isDarkEnergy = 'omegaLambda' in result;
  const isConstants = Array.isArray(result);

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      style={{ marginTop: '1rem' }}
    >
      {/* Header with source badge */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
        <div style={{ fontSize: '0.8rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          {isHubble ? 'Hubble Tension Resolution' : isDarkEnergy ? 'Dark Energy φ-Patterns' : 'Sacred Constant Predictions'}
        </div>
        <SourceBadge source={source} />
      </div>

      {/* Hubble Result */}
      {isHubble && (
        <>
          <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Hubble Constant (km/s/Mpc)
            </div>
            <div style={{ display: 'flex', gap: '1rem', fontSize: '0.85rem', fontFamily: MONO }}>
              <span style={{ color: CYAN }}>Early (Planck): {(result as HubbleResult).early}</span>
              <span style={{ color: '#ff5050' }}>Late (SH0ES): {(result as HubbleResult).late}</span>
              <span style={{ color: GOLDEN }}>Sacred: {(result as HubbleResult).sacred}</span>
            </div>
          </div>
          <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Resolution
            </div>
            <div style={{ fontSize: '0.8rem', fontFamily: SANS }}>
              <div style={{ color: (result as HubbleResult).resolved ? GREEN : '#ff5050', marginBottom: '0.25rem' }}>
                {(result as HubbleResult).resolved ? '✓ Sacred value resolves tension' : 'Tension unresolved'}
              </div>
              <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)' }}>
                {(result as HubbleResult).phiRelation}
              </div>
            </div>
          </div>
        </>
      )}

      {/* Dark Energy Result */}
      {isDarkEnergy && (
        <>
          <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Cosmic Density Parameters
            </div>
            <div style={{ display: 'flex', gap: '1rem', fontSize: '0.85rem', fontFamily: MONO }}>
              <span style={{ color: CYAN }}>Ω_m: {(result as DarkEnergyAnalysis).omegaMatter.toFixed(3)}</span>
              <span style={{ color: PURPLE }}>Ω_Λ: {(result as DarkEnergyAnalysis).omegaLambda.toFixed(3)}</span>
            </div>
          </div>
          <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Sacred Pattern
            </div>
            <div style={{ fontSize: '0.8rem', fontFamily: SANS }}>
              <div style={{ color: GOLDEN, marginBottom: '0.25rem' }}>
                {(result as DarkEnergyAnalysis).sacredPattern}
              </div>
              <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)' }}>
                {(result as DarkEnergyAnalysis).prediction}
              </div>
            </div>
          </div>
        </>
      )}

      {/* Constants Result */}
      {isConstants && (
        <div style={{ ...GLASS_STYLE, padding: '0.75rem', marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: SANS, marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Predicted Sacred Constants
          </div>
          {(result as ConstantPrediction[]).map((c, i) => (
            <div key={i} style={{ padding: '0.5rem 0', borderBottom: i < (result as ConstantPrediction[]).length - 1 ? '1px solid rgba(255,255,255,0.1)' : 'none' }}>
              <div style={{ fontSize: '0.8rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
                {c.constantName}
              </div>
              <div style={{ fontSize: '0.75rem', fontFamily: MONO, color: 'rgba(255,255,255,0.8)' }}>
                {c.formula} = {c.sacredPrediction.toFixed(6)}
              </div>
              <div style={{ fontSize: '0.7rem', color: c.confidence > 0.9 ? GREEN : c.confidence > 0.7 ? GOLDEN : 'rgba(255,255,255,0.5)' }}>
                Confidence: {(c.confidence * 100).toFixed(0)}%
              </div>
            </div>
          ))}
        </div>
      )}
    </motion.div>
  );
}

// ============================================================================
// Neuroscience v16.0 Result View
// ============================================================================

function NeuroResultView({ result, source }: { result: any; source: 'live' | 'local' }) {
  if (!result) return null;

  if (result.type === 'stats') {
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ ...GLASS_STYLE, padding: '1rem', marginTop: '1rem' }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <div>
            <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
              Brain Statistics
            </div>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
              HUMAN BRAIN — SACRED CONSTANTS
            </div>
          </div>
          <SourceBadge source={source} />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.75rem' }}>
          <div style={{ padding: '0.75rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO, marginBottom: '0.25rem' }}>
              NEURONS
            </div>
            <div style={{ fontSize: '1.1rem', color: GOLDEN, fontFamily: MONO }}>
              {(result.neurons / 1e10).toFixed(1)} × 10¹⁰
            </div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO }}>
              ≈ φ¹⁶ × 10⁷
            </div>
          </div>

          <div style={{ padding: '0.75rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO, marginBottom: '0.25rem' }}>
              SYNAPSES/NEURON
            </div>
            <div style={{ fontSize: '1.1rem', color: GOLDEN, fontFamily: MONO }}>
              {result.synapses_per_neuron.toLocaleString()}
            </div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO }}>
              ≈ φ⁵ × 1000
            </div>
          </div>

          <div style={{ padding: '0.75rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO, marginBottom: '0.25rem' }}>
              BRAIN MASS
            </div>
            <div style={{ fontSize: '1.1rem', color: GOLDEN, fontFamily: MONO }}>
              {result.brain_mass} kg
            </div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO }}>
              ≈ φ × 0.86 kg
            </div>
          </div>

          <div style={{ padding: '0.75rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)' }}>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO, marginBottom: '0.25rem' }}>
              CONDUCTION VELOCITY
            </div>
            <div style={{ fontSize: '1.1rem', color: GOLDEN, fontFamily: MONO }}>
              ~162 m/s
            </div>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO }}>
              φ × 100 m/s
            </div>
          </div>
        </div>

        <div style={{ marginTop: '0.75rem', padding: '0.5rem 0.75rem', background: 'rgba(0,0,0,0.2)', borderRadius: '6px' }}>
          <div style={{ fontSize: '0.7rem', color: GOLDEN, marginBottom: '0.5rem', fontFamily: SANS, fontWeight: 600 }}>
            Consciousness Formula
          </div>
          <div style={{ fontSize: '0.8rem', fontFamily: MONO, color: 'rgba(255,255,255,0.8)' }}>
            Ψ = C × φ^t × e^(-E/RT)
          </div>
          <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', marginTop: '0.25rem' }}>
            Where: Ψ = consciousness (0-100), C = neural complexity, φ = golden ratio, t = time integration, E = energy threshold
          </div>
        </div>
      </motion.div>
    );
  }

  if ('delta' in result) {
    // Brain waves response
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ ...GLASS_STYLE, padding: '1rem', marginTop: '1rem' }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <div>
            <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
                Brain Waves — φ-Patterned
            </div>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
              DELTA → GAMMA SACRED FREQUENCIES
            </div>
          </div>
          <SourceBadge source={source} />
        </div>

        <div style={{ display: 'grid', gap: '0.5rem' }}>
          {[
            { name: 'Delta', symbol: 'Δ', freq: `${result.delta.min}-${result.delta.max}`, peak: result.delta.peak, sacred: result.delta.sacred, state: 'Deep Sleep' },
            { name: 'Theta', symbol: 'θ', freq: `${result.theta.min}-${result.theta.max}`, peak: result.theta.peak, sacred: result.theta.sacred, state: 'Meditation' },
            { name: 'Alpha', symbol: 'α', freq: `${result.alpha.min}-${result.alpha.max}`, peak: result.alpha.peak, sacred: result.alpha.sacred, state: 'Flow' },
            { name: 'Beta', symbol: 'β', freq: `${result.beta.min}-${result.beta.max}`, peak: result.beta.peak, sacred: result.beta.sacred, state: 'Focus' },
            { name: 'Gamma', symbol: 'γ', freq: `${result.gamma.min}-${result.gamma.max}`, peak: result.gamma.peak, sacred: result.gamma.sacred, state: 'Peak' },
          ].map((wave) => (
            <div key={wave.name} style={{
              padding: '0.5rem 0.75rem',
              background: 'rgba(255,215,0,0.05)',
              borderRadius: '6px',
              border: '1px solid rgba(255,215,0,0.1)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}>
              <div>
                <span style={{ color: GOLDEN, fontSize: '0.8rem', fontWeight: 600 }}>{wave.symbol}</span>
                <span style={{ color: '#fff', fontSize: '0.75rem', marginLeft: '0.5rem' }}>{wave.name}</span>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: '0.75rem', fontFamily: MONO }}>{wave.freq} Hz</div>
                <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)' }}>{wave.state}</div>
              </div>
              <div style={{ textAlign: 'right', marginLeft: '1rem' }}>
                <div style={{ fontSize: '0.7rem', color: GOLDEN, fontFamily: MONO }}>{wave.sacred.toFixed(2)} Hz</div>
                <div style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.4)' }}>sacred</div>
              </div>
            </div>
          ))}
        </div>

        <div style={{ marginTop: '0.75rem', fontSize: '0.75rem', color: 'rgba(255,255,255,0.6)', fontFamily: MONO }}>
          φ = {result.phi.toFixed(5)} • Ψ = n × 3^k × π^m × φ^p × e^q
        </div>
      </motion.div>
    );
  }

  if ('psi' in result) {
    // Consciousness response
    const level = result.psi;
    const isSacred = result.is_sacred;
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ ...GLASS_STYLE, padding: '1rem', marginTop: '1rem' }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <div>
            <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
                Consciousness Level Ψ
            </div>
            <div style={{ fontSize: '0.7rem', color: isSacred ? GOLDEN : 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
              {isSacred ? 'SACRED CONSCIOUSNESS!' : 'PSI COMPUTATION'}
            </div>
          </div>
          <SourceBadge source={source} />
        </div>

        <div style={{ textAlign: 'center', padding: '1.5rem 0' }}>
          <div style={{ fontSize: '3rem', color: isSacred ? GOLDEN : '#fff', fontFamily: MONO, fontWeight: 700 }}>
            Ψ = {level.toFixed(2)}
          </div>
          <div style={{ fontSize: '1.1rem', color: isSacred ? GOLDEN : 'rgba(255,255,255,0.8)', marginTop: '0.25rem' }}>
            {result.state}
          </div>
          <div style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.5)', marginTop: '0.25rem' }}>
            Dominant Wave: {result.dominant_wave}
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.5rem', marginTop: '0.75rem' }}>
          <div style={{ padding: '0.5rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>φ-RESONANCE</div>
            <div style={{ fontSize: '1rem', color: GOLDEN, fontFamily: MONO }}>{(result.phi_resonance * 100).toFixed(0)}%</div>
          </div>
          <div style={{ padding: '0.5rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>FORMULA</div>
            <div style={{ fontSize: '0.8rem', color: '#fff', fontFamily: MONO }}>{result.formula}</div>
          </div>
          <div style={{ padding: '0.5rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>STATUS</div>
            <div style={{ fontSize: '0.8rem', color: level > 70 ? GREEN : level > 40 ? GOLDEN : 'rgba(255,255,255,0.6)', fontFamily: MONO }}>
              {level > 70 ? 'PEAK' : level > 40 ? 'ACTIVE' : 'RESTING'}
            </div>
          </div>
        </div>

        <div style={{ marginTop: '0.75rem', padding: '0.5rem 0.75rem', background: 'rgba(0,0,0,0.2)', borderRadius: '6px' }}>
          <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)', fontFamily: SANS }}>
            {result.interpretation}
          </div>
        </div>
      </motion.div>
    );
  }

  if ('regions' in result) {
    // Brain regions response
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ ...GLASS_STYLE, padding: '1rem', marginTop: '1rem' }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <div>
            <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
                Sacred Brain Regions
            </div>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
              {result.total} REGIONS • {result.sacred_count} SACRED
            </div>
          </div>
          <SourceBadge source={source} />
        </div>

        <div style={{ display: 'grid', gap: '0.5rem' }}>
          {result.phi_optimized.map((region: any) => (
            <div key={region.id} style={{
              padding: '0.5rem 0.75rem',
              background: 'rgba(255,215,0,0.05)',
              borderRadius: '6px',
              border: '1px solid rgba(255,215,0,0.1)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}>
              <div>
                <div style={{ fontSize: '0.8rem', color: '#fff', fontWeight: 500 }}>{region.name}</div>
                <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>{region.abbreviation}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: MONO }}>{region.phi_index.toFixed(2)}</div>
                <div style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.4)' }}>φ-index</div>
              </div>
              <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', marginLeft: '1rem', fontFamily: MONO, fontStyle: 'italic' }}>
                {region.sacred_function}
              </div>
            </div>
          ))}
        </div>
      </motion.div>
    );
  }

  if ('architecture' in result) {
    // Neural network response
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ ...GLASS_STYLE, padding: '1rem', marginTop: '1rem' }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <div>
            <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
                Neural Network Analysis
            </div>
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
              {result.architecture}
            </div>
          </div>
          <SourceBadge source={source} />
        </div>

        <div style={{ padding: '0.75rem', background: 'rgba(0,0,0,0.2)', borderRadius: '6px', marginBottom: '0.75rem', textAlign: 'center' }}>
          <div style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO, marginBottom: '0.5rem' }}>
            LAYERS
          </div>
          <div style={{ fontSize: '1.1rem', fontFamily: MONO, color: '#fff' }}>
            {result.layers.join(' → ')}
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.5rem' }}>
          <div style={{ padding: '0.5rem', background: result.is_fibonacci ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>FIBONACCI</div>
            <div style={{ fontSize: '0.8rem', color: result.is_fibonacci ? GREEN : 'rgba(255,255,255,0.6)' }}>
              {result.is_fibonacci ? '✓' : '✗'}
            </div>
          </div>
          <div style={{ padding: '0.5rem', background: result.is_trinitary ? 'rgba(170,102,255,0.1)' : 'rgba(255,255,255,0.05)', borderRadius: '6px', border: '1px solid rgba(255,255,255,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>TRINITARY</div>
            <div style={{ fontSize: '0.8rem', color: result.is_trinitary ? PURPLE : 'rgba(255,255,255,0.6)' }}>
              {result.is_trinitary ? '✓' : '✗'}
            </div>
          </div>
          <div style={{ padding: '0.5rem', background: result.phi_index > 0.8 ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>φ-INDEX</div>
            <div style={{ fontSize: '0.8rem', color: result.phi_index > 0.8 ? GOLDEN : 'rgba(255,255,255,0.6)' }}>
              {result.phi_index.toFixed(2)}
            </div>
          </div>
        </div>

        <div style={{ marginTop: '0.75rem', padding: '0.5rem 0.75rem', background: 'rgba(0,0,0,0.2)', borderRadius: '6px' }}>
          <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)', fontFamily: SANS }}>
            {result.description}
          </div>
          {result.sacred_formula && (
            <div style={{ fontSize: '0.7rem', color: GOLDEN, fontFamily: MONO, marginTop: '0.25rem' }}>
              {result.sacred_formula}
            </div>
          )}
        </div>
      </motion.div>
    );
  }

  if ('phases' in result) {
    // Synapse response
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        style={{ ...GLASS_STYLE, padding: '1rem', marginTop: '1rem' }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <div>
            <div style={{ fontSize: '0.9rem', color: GOLDEN, fontFamily: SANS, fontWeight: 600 }}>
                Synaptic Transmission
            </div>
            <div style={{ fontSize: '0.7rem', color: result.is_sacred ? GOLDEN : 'rgba(255,255,255,0.5)', fontFamily: MONO }}>
              {result.is_sacred ? 'SACRED TIMING' : 'SYNAPTIC TIMING'}
            </div>
          </div>
          <SourceBadge source={source} />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.5rem', marginBottom: '0.75rem' }}>
          <div style={{ padding: '0.75rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>TOTAL DELAY</div>
            <div style={{ fontSize: '1.2rem', color: '#fff', fontFamily: MONO }}>{result.total_delay} ms</div>
          </div>
          <div style={{ padding: '0.75rem', background: 'rgba(255,215,0,0.05)', borderRadius: '6px', border: '1px solid rgba(255,215,0,0.1)', textAlign: 'center' }}>
            <div style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', fontFamily: MONO }}>SACRED DELAY</div>
            <div style={{ fontSize: '1.2rem', color: GOLDEN, fontFamily: MONO }}>{result.sacred_delay} ms</div>
            <div style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.4)' }}>φ × 10</div>
          </div>
        </div>

        <div style={{ fontSize: '0.75rem', color: GOLDEN, marginBottom: '0.5rem', fontFamily: SANS, fontWeight: 600 }}>
          Transmission Phases
        </div>
        {result.phases.map((phase: any, i: number) => (
          <div key={i} style={{
            padding: '0.4rem 0.75rem',
            background: 'rgba(255,255,255,0.03)',
            borderBottom: i < result.phases.length - 1 ? '1px solid rgba(255,255,255,0.1)' : 'none',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}>
            <div style={{ fontSize: '0.75rem', color: '#fff' }}>{phase.phase}</div>
            <div style={{ fontSize: '0.75rem', fontFamily: MONO, color: 'rgba(255,255,255,0.7)' }}>{phase.duration} ms</div>
            <div style={{ fontSize: '0.7rem', fontFamily: MONO, color: GOLDEN }}>{phase.sacred_value.toFixed(3)} φ</div>
          </div>
        ))}
      </motion.div>
    );
  }

  return null;
}

// ============================================================================
// Main Widget
// ============================================================================

type WidgetMode = 'molecule' | 'element' | 'balance' | 'predict' | 'biology' | 'cosmos' | 'neuro';

export default function SacredChemistryWidget() {
  const [mode, setMode] = useState<WidgetMode>('molecule');
  const [input, setInput] = useState('');
  const [moleculeResult, setMoleculeResult] = useState<MoleculeResult | null>(null);
  const [elementResult, setElementResult] = useState<ElementResult | null>(null);
  const [balanceResult, setBalanceResult] = useState<ChemBalanceResponse | null>(null);
  const [predictResult, setPredictResult] = useState<ChemPredictResponse | null>(null);
  const [extendedElement, setExtendedElement] = useState<ExtendedElement | undefined>(undefined);
  const [source, setSource] = useState<'live' | 'local'>('local');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [show3D, setShow3D] = useState(false);
  const [showTemporal, setShowTemporal] = useState(false);
  // Biology v14.0
  const [biologyResult, setBiologyResult] = useState<DnaAnalysis | RnaAnalysis | ProteinAnalysis | null>(null);
  const [showBiology3D, setShowBiology3D] = useState(false);
  // Cosmology v15.0
  const [cosmosResult, setCosmosResult] = useState<HubbleResult | DarkEnergyAnalysis | ConstantPrediction[] | null>(null);
  const [showCosmos3D, setShowCosmos3D] = useState(false);
  // Neuroscience v16.0
  const [neuroResult, setNeuroResult] = useState<any>(null);
  const [showNeuro3D, setShowNeuro3D] = useState(false);

  const clearResults = () => {
    setMoleculeResult(null);
    setElementResult(null);
    setBalanceResult(null);
    setPredictResult(null);
    setExtendedElement(undefined);
    setError(null);
    setSource('local');
    setShow3D(false);
    setShowTemporal(false);
    setBiologyResult(null);
    setShowBiology3D(false);
    setCosmosResult(null);
    setShowCosmos3D(false);
    setNeuroResult(null);
    setShowNeuro3D(false);
  };

  const handleAnalyze = useCallback(async () => {
    const query = input.trim();
    if (!query) return;
    clearResults();
    setLoading(true);

    try {
      if (mode === 'molecule') {
        // Try backend first
        const live = await fetchChemSacred(query);
        if (live) {
          // Backend responded — still compute local for full MoleculeResult shape
          const result = await analyzeMolecule(query);
          if (result.elements.length === 0) {
            setError(`No known elements found in "${query}"`);
          } else {
            setMoleculeResult(result);
            setSource('live');
          }
        } else {
          // Fallback to client-side
          const result = await analyzeMolecule(query);
          if (result.elements.length === 0) {
            setError(`No known elements found in "${query}"`);
          } else {
            setMoleculeResult(result);
            setSource('local');
          }
        }
      } else if (mode === 'element') {
        // Try backend first
        const live = await fetchChemElement(query);
        if (live) {
          // Use backend element data for extended panel
          setExtendedElement(live.element);
          // Still compute local ElementResult for consistent display
          const result = await analyzeElement(query);
          if (!result) {
            setError(`Element "${query}" not found. Try a symbol (Au) or number (79).`);
          } else {
            setElementResult(result);
            setSource('live');
          }
        } else {
          // Fallback to client-side
          const result = await analyzeElement(query);
          if (!result) {
            setError(`Element "${query}" not found. Try a symbol (Au) or number (79).`);
          } else {
            setElementResult(result);
            setSource('local');
          }
        }
      } else if (mode === 'balance') {
        // Balance mode — backend only
        const result = await fetchChemBalance(query);
        if (result) {
          setBalanceResult(result);
          setSource('live');
        } else {
          setError('Equation balancing requires the backend. Start: zig build tri -- serve');
        }
      } else if (mode === 'predict') {
        // Predict mode — backend only
        const result = await fetchChemPredict(query);
        if (result) {
          setPredictResult(result);
          setSource('live');
        } else {
          setError('Reaction prediction requires the backend. Start: zig build tri -- serve');
        }
      } else if (mode === 'biology') {
        // Biology v14.0 mode — local analysis
        const upperQuery = query.toUpperCase().replace(/[^ATGCUMVHLIPFWYKRNQDESAZ]/g, '');
        if (upperQuery.length === 0) {
          setError('Invalid biology sequence. Use DNA (ATGC), RNA (AUGC), or protein (ACDEFGHIKLMNPQRSTVWY).');
          return;
        }
        // Detect type: DNA (T present), RNA (U present), or Protein (amino acid letters)
        const hasT = upperQuery.includes('T');
        const hasU = upperQuery.includes('U');
        const hasAminoAcidLetters = /[DEFGHIKLMNPQRSTVWY]/.test(upperQuery);
        let result: DnaAnalysis | RnaAnalysis | ProteinAnalysis;
        if (hasU && !hasT) {
          result = await analyzeRna(upperQuery);
        } else if (hasAminoAcidLetters && (!hasT || /[DEFGHIKLMNPQRSTVWY]/.test(upperQuery.substring(1)))) {
          result = await analyzeProtein(upperQuery);
        } else {
          result = await analyzeDna(upperQuery);
        }
        setBiologyResult(result);
        setSource('local');
      } else if (mode === 'cosmos') {
        // Cosmology v15.0 mode — local analysis
        const lowerQuery = query.toLowerCase().trim();
        if (lowerQuery.includes('hubble') || lowerQuery.includes('tension')) {
          const result = await analyzeHubble();
          setCosmosResult(result);
        } else if (lowerQuery.includes('dark') || lowerQuery.includes('energy') || lowerQuery.includes('omega')) {
          const result = await analyzeDarkEnergy();
          setCosmosResult(result);
        } else if (lowerQuery.includes('predict') || lowerQuery.includes('constant') || lowerQuery.includes('stability')) {
          const result = await predictConstants();
          setCosmosResult(result);
        } else if (lowerQuery.includes('expand') || lowerQuery.includes('universe') || lowerQuery.includes('epoch')) {
          const result = generateExpansionTimeline();
          setCosmosResult(result);
        } else {
          // Default to Hubble analysis
          const result = await analyzeHubble();
          setCosmosResult(result);
        }
        setSource('local');
      } else if (mode === 'neuro') {
        // Neuroscience v16.0 mode
        const lowerQuery = query.toLowerCase().trim();
        if (lowerQuery === 'waves' || lowerQuery === 'wave') {
          const result = await fetchNeuroWaves();
          setNeuroResult(result);
        } else if (lowerQuery.includes('consciousness') || lowerQuery.includes('psi')) {
          // Default consciousness values: C=50, t=2, E=20
          const result = await fetchNeuroConsciousness(50, 2, 20);
          setNeuroResult(result);
        } else if (lowerQuery === 'regions') {
          const result = await fetchNeuroRegions();
          setNeuroResult(result);
        } else if (lowerQuery.includes('network') || lowerQuery.includes('mlp') || lowerQuery.includes('trinitary')) {
          // Try to parse layer sizes from query
          const numbers = lowerQuery.match(/\d+/g);
          const layers = numbers ? numbers.map(Number) : [784, 144, 233, 10];
          const result = await fetchNeuroNetwork(layers);
          setNeuroResult(result);
        } else if (lowerQuery === 'synapse' || lowerQuery === 'synaptic') {
          const result = await fetchNeuroSynapse();
          setNeuroResult(result);
        } else if (lowerQuery === 'neurons' || lowerQuery === 'brain' || lowerQuery === 'statistics') {
          // Show neurons stats
          setNeuroResult({
            type: 'stats',
            neurons: 8.6e10,
            synapses_per_neuron: 12000,
            brain_mass: 1.4,
          });
        } else {
          // Default to brain waves
          const result = await fetchNeuroWaves();
          setNeuroResult(result);
        }
        setSource('local');
      }
    } catch (e: any) {
      setError(e?.message || 'Analysis failed');
    } finally {
      setLoading(false);
    }
  }, [input, mode]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleAnalyze();
  }, [handleAnalyze]);

  const examples: Record<WidgetMode, string[]> = {
    molecule: ['H2O', 'C6H12O6', 'NaCl', 'Ca(OH)2', 'C2H5OH'],
    element: ['Au', 'Fe', 'U', 'C', 'H'],
    balance: ['H2+O2->H2O', 'Fe+O2->Fe2O3', 'CH4+O2->CO2+H2O'],
    predict: ['Fe+HCl', 'CH4+O2', 'Na+Cl2', 'NaOH+HCl', 'CaCO3'],
    biology: ['ATGCGTAA', 'AUGCCAUAA', 'MVHLTPEEK', 'ATG', 'Hemoglobin'],
    cosmos: ['hubble', 'dark energy', 'constants', 'expansion', 'big bang'],
    neuro: ['waves', 'consciousness', 'regions', 'network 784 144 233 10', 'synapse'],
  };

  const placeholders: Record<WidgetMode, string> = {
    molecule: 'Enter formula (H2O, C6H12O6...)',
    element: 'Enter symbol or number (Au, 79...)',
    balance: 'Enter equation (H2+O2->H2O)',
    predict: 'Enter reaction (Fe+HCl)',
    biology: 'Enter DNA/RNA/Protein sequence...',
    cosmos: 'hubble, dark energy, constants, expansion...',
    neuro: 'waves, consciousness, regions, network, synapse, neurons...',
  };

  return (
    <Section id="sacred-chemistry">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        style={{
          ...GLASS_STYLE,
          padding: '1.5rem',
          maxWidth: 'min(700px, 92vw)',
          margin: '0 auto',
        }}
      >
        {/* Title */}
        <div style={{ textAlign: 'center', marginBottom: '1.25rem' }}>
          <h3 style={{
            color: GOLDEN,
            fontSize: '1.1rem',
            fontWeight: 700,
            fontFamily: SANS,
            textTransform: 'uppercase',
            letterSpacing: '0.08em',
            margin: 0,
          }}>
            Sacred Chemistry
          </h3>
          <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO, marginTop: '0.25rem' }}>
            V = n {'\u00D7'} 3{'\u1D4F'} {'\u00D7'} {'\u03C0'}{'\u1D50'} {'\u00D7'} {'\u03C6'}{'\u1D56'} {'\u00D7'} e{'\u1D60'}
          </div>
        </div>

        {/* Mode Toggle (7 modes) */}
        <div style={{ display: 'flex', gap: '0', marginBottom: '1rem', justifyContent: 'center' }}>
          {(['molecule', 'element', 'balance', 'predict', 'biology', 'cosmos', 'neuro'] as const).map((m, idx, arr) => (
            <button
              key={m}
              onClick={() => { setMode(m); clearResults(); }}
              style={{
                padding: '0.4rem 0.8rem',
                fontSize: '0.75rem',
                fontFamily: SANS,
                fontWeight: 600,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
                border: `1px solid ${mode === m ? 'rgba(255,215,0,0.5)' : 'rgba(255,255,255,0.1)'}`,
                background: mode === m ? 'rgba(255,215,0,0.15)' : 'rgba(255,255,255,0.03)',
                color: mode === m ? GOLDEN : 'rgba(255,255,255,0.5)',
                cursor: 'pointer',
                borderRadius: idx === 0 ? '6px 0 0 6px' : idx === arr.length - 1 ? '0 6px 6px 0' : '0',
                transition: 'all 0.2s ease',
              }}
            >
              {m === 'biology' ? 'bio v14' : m === 'cosmos' ? 'cosmos v15' : m === 'neuro' ? 'neuro v16' : m}
            </button>
          ))}
        </div>

        {/* Input Row */}
        <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.75rem' }}>
          <input
            type="text"
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={placeholders[mode]}
            style={{
              flex: 1,
              padding: '0.5rem 0.75rem',
              fontSize: '0.85rem',
              fontFamily: MONO,
              background: 'rgba(0,0,0,0.3)',
              border: '1px solid rgba(255,215,0,0.2)',
              borderRadius: '6px',
              color: '#fff',
              outline: 'none',
            }}
          />
          <button
            onClick={handleAnalyze}
            disabled={loading || !input.trim()}
            style={{
              padding: '0.5rem 1rem',
              fontSize: '0.8rem',
              fontFamily: SANS,
              fontWeight: 600,
              background: 'rgba(255,215,0,0.2)',
              border: '1px solid rgba(255,215,0,0.4)',
              borderRadius: '6px',
              color: GOLDEN,
              cursor: loading || !input.trim() ? 'not-allowed' : 'pointer',
              opacity: loading || !input.trim() ? 0.5 : 1,
              transition: 'all 0.2s ease',
            }}
          >
            {loading ? '\u23F3' : mode === 'balance' ? 'Balance' : mode === 'predict' ? 'Predict' : mode === 'biology' ? 'Analyze Bio' : mode === 'cosmos' ? 'Analyze Cosmos' : mode === 'neuro' ? 'Analyze Neuro' : 'Analyze'}
          </button>
        </div>

        {/* Quick Examples */}
        <div style={{ display: 'flex', gap: '0.35rem', flexWrap: 'wrap', marginBottom: '1rem' }}>
          {examples[mode].map(ex => (
            <button
              key={ex}
              onClick={() => { setInput(ex); }}
              style={{
                padding: '0.2rem 0.5rem',
                fontSize: '0.65rem',
                fontFamily: MONO,
                background: 'rgba(255,255,255,0.05)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: '4px',
                color: 'rgba(255,255,255,0.5)',
                cursor: 'pointer',
                transition: 'all 0.15s ease',
              }}
            >
              {ex}
            </button>
          ))}
        </div>

        {/* Error */}
        {error && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            style={{
              padding: '0.5rem 0.75rem',
              background: 'rgba(255, 80, 80, 0.1)',
              border: '1px solid rgba(255, 80, 80, 0.3)',
              borderRadius: '6px',
              fontSize: '0.75rem',
              color: '#ff5050',
              fontFamily: MONO,
              marginBottom: '1rem',
            }}
          >
            {error}
          </motion.div>
        )}

        {/* Loading */}
        {loading && (
          <div style={{ textAlign: 'center', padding: '2rem 0' }}>
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
              style={{
                display: 'inline-block',
                width: '30px',
                height: '30px',
                border: `2px solid rgba(255,215,0,0.2)`,
                borderTopColor: GOLDEN,
                borderRadius: '50%',
              }}
            />
            <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.4)', fontFamily: MONO, marginTop: '0.5rem' }}>
              {mode === 'balance' ? 'Balancing equation...' : mode === 'predict' ? 'Predicting products...' : mode === 'biology' ? 'Analyzing sacred biology...' : mode === 'cosmos' ? 'Computing sacred cosmology...' : mode === 'neuro' ? 'Analyzing sacred neuroscience...' : 'Computing sacred decomposition...'}
            </div>
          </div>
        )}

        {/* Results */}
        {moleculeResult && <MoleculeResultView result={moleculeResult} source={source} />}
        {moleculeResult && (
          <div style={{ marginTop: '0.75rem' }}>
            <button
              onClick={() => setShow3D(!show3D)}
              style={{
                ...GLASS_STYLE,
                padding: '0.4rem 1rem',
                cursor: 'pointer',
                color: show3D ? GOLDEN : 'rgba(255,255,255,0.6)',
                border: `1px solid ${show3D ? 'rgba(255,215,0,0.4)' : 'rgba(255,255,255,0.15)'}`,
                fontSize: '0.7rem',
                fontFamily: MONO,
                background: show3D ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)',
                transition: 'all 0.2s ease',
              }}
            >
              {show3D ? 'Hide 3D' : 'Show 3D'}
            </button>
            {show3D && (
              <Suspense fallback={
                <div style={{
                  height: 300,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...GLASS_STYLE,
                  marginTop: '0.5rem',
                }}>
                  <span style={{ color: GOLDEN, fontFamily: MONO, fontSize: '0.8rem' }}>
                    Loading 3D viewer...
                  </span>
                </div>
              }>
                <MoleculeViewer3D formula={input} />
              </Suspense>
            )}
          </div>
        )}
        {elementResult && <ElementResultView result={elementResult} source={source} extendedElement={extendedElement} />}
        {balanceResult && <BalanceResultView result={balanceResult} />}
        {predictResult && <PredictionResultView result={predictResult} />}
        {predictResult && (
          <div style={{ marginTop: '0.75rem' }}>
            <button
              onClick={() => setShowTemporal(!showTemporal)}
              style={{
                ...GLASS_STYLE,
                padding: '0.4rem 1rem',
                cursor: 'pointer',
                color: showTemporal ? GOLDEN : 'rgba(255,255,255,0.6)',
                border: `1px solid ${showTemporal ? 'rgba(255,215,0,0.4)' : 'rgba(255,255,255,0.15)'}`,
                fontSize: '0.7rem',
                fontFamily: MONO,
                background: showTemporal ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)',
                transition: 'all 0.2s ease',
              }}
            >
              {showTemporal ? 'Hide φ-Time' : 'Show φ-Time Animation'}
            </button>
            {showTemporal && (
              <Suspense fallback={
                <div style={{
                  height: 400,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...GLASS_STYLE,
                  marginTop: '0.5rem',
                }}>
                  <span style={{ color: GOLDEN, fontFamily: MONO, fontSize: '0.8rem' }}>
                    Loading temporal engine...
                  </span>
                </div>
              }>
                <TemporalMoleculeViewer
                  reactantsFormula={predictResult.reactants.join('+')}
                  productsFormula={predictResult.products.join('+')}
                  duration={5}
                />
              </Suspense>
            )}
          </div>
        )}
        {biologyResult && <BiologyResultView result={biologyResult} source={source} />}
        {biologyResult && 'sequence' in biologyResult && (
          <div style={{ marginTop: '0.75rem' }}>
            <button
              onClick={() => setShowBiology3D(!showBiology3D)}
              style={{
                ...GLASS_STYLE,
                padding: '0.4rem 1rem',
                cursor: 'pointer',
                color: showBiology3D ? GOLDEN : 'rgba(255,255,255,0.6)',
                border: `1px solid ${showBiology3D ? 'rgba(255,215,0,0.4)' : 'rgba(255,255,255,0.15)'}`,
                fontSize: '0.7rem',
                fontFamily: MONO,
                background: showBiology3D ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)',
                transition: 'all 0.2s ease',
              }}
            >
              {showBiology3D ? 'Hide DNA Helix' : 'Show 3D DNA Helix'}
            </button>
            {showBiology3D && (
              <Suspense fallback={
                <div style={{
                  height: 400,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...GLASS_STYLE,
                  marginTop: '0.5rem',
                }}>
                  <span style={{ color: GOLDEN, fontFamily: MONO, fontSize: '0.8rem' }}>
                    Loading DNA helix...
                  </span>
                </div>
              }>
                <DnaHelix3D sequence={biologyResult.sequence} />
              </Suspense>
            )}
          </div>
        )}
        {cosmosResult && <CosmosResultView result={cosmosResult} source={source} />}
        {cosmosResult && (
          <div style={{ marginTop: '0.75rem' }}>
            <button
              onClick={() => setShowCosmos3D(!showCosmos3D)}
              style={{
                ...GLASS_STYLE,
                padding: '0.4rem 1rem',
                cursor: 'pointer',
                color: showCosmos3D ? GOLDEN : 'rgba(255,255,255,0.6)',
                border: `1px solid ${showCosmos3D ? 'rgba(255,215,0,0.4)' : 'rgba(255,255,255,0.15)'}`,
                fontSize: '0.7rem',
                fontFamily: MONO,
                background: showCosmos3D ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)',
                transition: 'all 0.2s ease',
              }}
            >
              {showCosmos3D ? 'Hide Universe' : 'Show 3D Universe Expansion'}
            </button>
            {showCosmos3D && (
              <Suspense fallback={
                <div style={{
                  height: 500,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...GLASS_STYLE,
                  marginTop: '0.5rem',
                }}>
                  <span style={{ color: GOLDEN, fontFamily: MONO, fontSize: '0.8rem' }}>
                    Loading universe expansion...
                  </span>
                </div>
              }>
                <UniverseExpansion3D
                  showTimeline
                  showGoldenSpiral
                  showDarkEnergy
                  epochs={15}
                  autoRotate
                />
              </Suspense>
            )}
          </div>
        )}
        {neuroResult && <NeuroResultView result={neuroResult} source={source} />}
        {neuroResult && neuroResult.type !== 'stats' && (
          <div style={{ marginTop: '0.75rem' }}>
            <button
              onClick={() => setShowNeuro3D(!showNeuro3D)}
              style={{
                ...GLASS_STYLE,
                padding: '0.4rem 1rem',
                cursor: 'pointer',
                color: showNeuro3D ? GOLDEN : 'rgba(255,255,255,0.6)',
                border: `1px solid ${showNeuro3D ? 'rgba(255,215,0,0.4)' : 'rgba(255,255,255,0.15)'}`,
                fontSize: '0.7rem',
                fontFamily: MONO,
                background: showNeuro3D ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)',
                transition: 'all 0.2s ease',
              }}
            >
              {showNeuro3D ? 'Hide Brain' : 'Show 3D Brain Connectivity'}
            </button>
            {showNeuro3D && (
              <Suspense fallback={
                <div style={{
                  height: 500,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...GLASS_STYLE,
                  marginTop: '0.5rem',
                }}>
                  <span style={{ color: GOLDEN, fontFamily: MONO, fontSize: '0.8rem' }}>
                    Loading brain connectivity...
                  </span>
                </div>
              }>
                <BrainConnectivity3D
                  showLabels
                  showConnections
                  autoRotate
                  highlightSacred
                  consciousness={neuroResult.psi ?? 50}
                />
              </Suspense>
            )}
          </div>
        )}
      </motion.div>
    </Section>
  );
}
