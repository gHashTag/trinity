"use client";
import React, { useState, useCallback } from 'react';
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
  fetchChemSacred, fetchChemElement, fetchChemBalance,
  type ChemSacredResponse, type ChemElementResponse, type ChemBalanceResponse,
  type ExtendedElement,
} from '../../services/chatApi';

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
          Sum: {sig.sum} \u2192 {sig.label}
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
        {angle.toFixed(2)}\u00B0
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
          <div style={{ color: 'rgba(255,255,255,0.3)', display: 'flex', alignItems: 'center', fontSize: '1.2rem' }}>\u2192</div>
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
// Main Widget
// ============================================================================

type WidgetMode = 'molecule' | 'element' | 'balance';

export default function SacredChemistryWidget() {
  const [mode, setMode] = useState<WidgetMode>('molecule');
  const [input, setInput] = useState('');
  const [moleculeResult, setMoleculeResult] = useState<MoleculeResult | null>(null);
  const [elementResult, setElementResult] = useState<ElementResult | null>(null);
  const [balanceResult, setBalanceResult] = useState<ChemBalanceResponse | null>(null);
  const [extendedElement, setExtendedElement] = useState<ExtendedElement | undefined>(undefined);
  const [source, setSource] = useState<'live' | 'local'>('local');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const clearResults = () => {
    setMoleculeResult(null);
    setElementResult(null);
    setBalanceResult(null);
    setExtendedElement(undefined);
    setError(null);
    setSource('local');
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
      } else {
        // Balance mode — backend only
        const result = await fetchChemBalance(query);
        if (result) {
          setBalanceResult(result);
          setSource('live');
        } else {
          setError('Equation balancing requires the backend. Start: zig build tri -- serve');
        }
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
  };

  const placeholders: Record<WidgetMode, string> = {
    molecule: 'Enter formula (H2O, C6H12O6...)',
    element: 'Enter symbol or number (Au, 79...)',
    balance: 'Enter equation (H2+O2->H2O)',
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
            V = n \u00D7 3\u1D4F \u00D7 \u03C0\u1D50 \u00D7 \u03C6\u1D56 \u00D7 e\u1D60
          </div>
        </div>

        {/* Mode Toggle (3 modes) */}
        <div style={{ display: 'flex', gap: '0', marginBottom: '1rem', justifyContent: 'center' }}>
          {(['molecule', 'element', 'balance'] as const).map((m, idx) => (
            <button
              key={m}
              onClick={() => { setMode(m); clearResults(); }}
              style={{
                padding: '0.4rem 1rem',
                fontSize: '0.75rem',
                fontFamily: SANS,
                fontWeight: 600,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
                border: `1px solid ${mode === m ? 'rgba(255,215,0,0.5)' : 'rgba(255,255,255,0.1)'}`,
                background: mode === m ? 'rgba(255,215,0,0.15)' : 'rgba(255,255,255,0.03)',
                color: mode === m ? GOLDEN : 'rgba(255,255,255,0.5)',
                cursor: 'pointer',
                borderRadius: idx === 0 ? '6px 0 0 6px' : idx === 2 ? '0 6px 6px 0' : '0',
                transition: 'all 0.2s ease',
              }}
            >
              {m}
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
            {loading ? '\u23F3' : mode === 'balance' ? 'Balance' : 'Analyze'}
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
              {mode === 'balance' ? 'Balancing equation...' : 'Computing sacred decomposition...'}
            </div>
          </div>
        )}

        {/* Results */}
        {moleculeResult && <MoleculeResultView result={moleculeResult} source={source} />}
        {elementResult && <ElementResultView result={elementResult} source={source} extendedElement={extendedElement} />}
        {balanceResult && <BalanceResultView result={balanceResult} />}
      </motion.div>
    </Section>
  );
}
