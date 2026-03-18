"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchQGSim, type QGSimResponse } from '../../services/chatApi';

const glass = {
  background: 'rgba(0,0,0,0.5)',
  border: '1px solid rgba(0,204,255,0.2)',
  borderRadius: '12px',
  padding: '16px',
  backdropFilter: 'blur(8px)',
};

type QGTab = 'spin_foam' | 'regge' | 'ads_thermal' | 'area_spectrum' | 'cdt' | 'veneziano' | 'page_curve';

const TABS: { key: QGTab; label: string }[] = [
  { key: 'spin_foam', label: 'Spin Foam' },
  { key: 'regge', label: 'Regge Calculus' },
  { key: 'ads_thermal', label: 'AdS Thermal' },
  { key: 'area_spectrum', label: 'Area Spectrum' },
  { key: 'cdt', label: 'CDT' },
  { key: 'veneziano', label: 'Veneziano' },
  { key: 'page_curve', label: 'Page Curve' },
];

export default function QuantumGravitySection() {
  const { t } = useI18n();
  const msg = (t as any).quantumGravity || {};

  const [tab, setTab] = useState<QGTab>('spin_foam');
  const [steps, setSteps] = useState(10);
  const [data, setData] = useState<QGSimResponse | null>(null);
  const [loading, setLoading] = useState(false);

  const loadData = async () => {
    setLoading(true);
    try {
      const result = await fetchQGSim(steps);
      setData(result);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, [steps]);

  return (
    <Section id="quantum-gravity">
      <div style={{ maxWidth: 900, margin: '0 auto', padding: 'clamp(16px, 5vw, 40px) clamp(12px, 4vw, 20px)' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          style={{ color: '#00ccff', fontSize: 'clamp(20px, 6vw, 28px)', fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 8 }}
        >
          {msg.title || 'Quantum Gravity Simulation v3.1'}
        </motion.h2>
        <p style={{ color: 'rgba(0,204,255,0.5)', textAlign: 'center', fontSize: 13, marginBottom: 16, fontFamily: 'JetBrains Mono, monospace' }}>
          {msg.subtitle || 'Generated from: specs/tri/quantum_gravity_sim.vibee'}
        </p>

        {/* Steps selector */}
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 16, alignItems: 'center' }}>
          <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: 12, fontFamily: 'JetBrains Mono, monospace' }}>
            {msg.steps || 'Steps'}:
          </span>
          {[5, 10, 15, 20].map(s => (
            <button
              key={s}
              onClick={() => setSteps(s)}
              style={{
                padding: '4px 12px', borderRadius: 6, fontSize: 11, cursor: 'pointer',
                fontFamily: 'JetBrains Mono, monospace',
                border: steps === s ? '1px solid #00ccff' : '1px solid rgba(0,204,255,0.2)',
                background: steps === s ? 'rgba(0,204,255,0.15)' : 'rgba(0,0,0,0.3)',
                color: steps === s ? '#00ccff' : 'rgba(255,255,255,0.5)',
              }}
            >
              {s}
            </button>
          ))}
        </div>

        {/* Tab switcher */}
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 24, flexWrap: 'wrap' }}>
          {TABS.map(t => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              style={{
                padding: '6px 16px', borderRadius: 8, fontSize: 12, cursor: 'pointer',
                fontFamily: 'JetBrains Mono, monospace', transition: 'all 0.2s',
                border: tab === t.key ? '1px solid #00ccff' : '1px solid rgba(0,204,255,0.2)',
                background: tab === t.key ? 'rgba(0,204,255,0.15)' : 'rgba(0,0,0,0.3)',
                color: tab === t.key ? '#00ccff' : 'rgba(255,255,255,0.5)',
              }}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <motion.div key={tab} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.3 }} style={glass}>
          {loading && <p style={{ color: 'rgba(0,204,255,0.5)', textAlign: 'center' }}>Simulating...</p>}

          {/* Spin Foam */}
          {tab === 'spin_foam' && data?.spin_foam && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 12 }}>
                {msg.spinFoamTitle || 'Spin Foam Evolution (Ponzano-Regge)'}
              </h3>
              <table style={{ width: '100%', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '3px 6px' }}>Step</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Amplitude</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Action</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Phase</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>V</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>E</th>
                  </tr>
                </thead>
                <tbody>
                  {data.spin_foam.map(s => (
                    <tr key={s.step} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(0,204,255,0.1)' }}>
                      <td style={{ padding: '2px 6px' }}>{s.step}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: '#00e599' }}>{s.amplitude.toFixed(6)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{s.action.toFixed(4)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{s.phase.toFixed(4)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{s.vertices}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{s.edges}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Regge Calculus */}
          {tab === 'regge' && data?.regge && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 12 }}>
                {msg.reggeTitle || 'Regge Calculus (Simplicial Quantum Gravity)'}
              </h3>
              <table style={{ width: '100%', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '3px 6px' }}>Iter</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Simplices</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Deficit ∠</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Action</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Curvature</th>
                  </tr>
                </thead>
                <tbody>
                  {data.regge.map(r => (
                    <tr key={r.iteration} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(0,204,255,0.1)' }}>
                      <td style={{ padding: '2px 6px' }}>{r.iteration}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{r.simplices}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: '#00e599' }}>{r.deficit_angle.toFixed(6)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{r.regge_action.toFixed(4)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{r.curvature.toFixed(4)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* AdS Thermalization */}
          {tab === 'ads_thermal' && data?.ads_thermal && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 12 }}>
                {msg.adsTitle || 'AdS/CFT Thermalization Dynamics'}
              </h3>
              {data.ads_thermal.map((a, i) => (
                <div key={i} style={{ marginBottom: 6 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', color: 'rgba(255,255,255,0.6)', marginBottom: 2 }}>
                    <span>t={a.time.toFixed(1)}</span>
                    <span>S_ent={a.s_entangle.toFixed(3)}</span>
                    <span style={{ color: '#00e599' }}>{a.scrambling_pct.toFixed(1)}%</span>
                  </div>
                  <div style={{ width: '100%', height: 6, background: 'rgba(255,255,255,0.05)', borderRadius: 3 }}>
                    <div style={{
                      width: `${Math.min(a.scrambling_pct, 100)}%`,
                      height: '100%',
                      background: 'linear-gradient(90deg, #00ccff, #00e599)',
                      borderRadius: 3,
                      transition: 'width 0.3s',
                    }} />
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Area Spectrum */}
          {tab === 'area_spectrum' && data?.area_spectrum && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 8 }}>
                {msg.areaTitle || 'LQG Area Spectrum (Barbero-Immirzi)'}
              </h3>
              <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', marginBottom: 12 }}>
                A_j = 8πγl_P² √(j(j+1))  |  {msg.areaGap || 'Area gap'}: {data.area_gap.toFixed(6)} l_P²
              </p>
              <table style={{ width: '100%', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '3px 6px' }}>j</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>A_j / l_P²</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>A_j × φ</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Ratio</th>
                  </tr>
                </thead>
                <tbody>
                  {data.area_spectrum.map(a => (
                    <tr key={a.j} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(0,204,255,0.1)' }}>
                      <td style={{ padding: '2px 6px' }}>{a.j.toFixed(1)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: '#00ccff' }}>{a.area.toFixed(6)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{a.area_phi.toFixed(6)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: a.ratio_to_prev > 0 ? '#ffd700' : '#666' }}>{a.ratio_to_prev > 0 ? a.ratio_to_prev.toFixed(6) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* CDT - Causal Dynamical Triangulations */}
          {tab === 'cdt' && data?.cdt && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 4 }}>
                Causal Dynamical Triangulations
              </h3>
              <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', marginBottom: 12 }}>
                CDT: Spectral dimension flows from 4D → 2D at Planck scale
              </p>
              <table style={{ width: '100%', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '3px 6px' }}>Time Slice</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>(2,4) Simplices</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>(4,1) Simplices</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Spatial Volume</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>d_spectral</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {data.cdt.map(c => (
                    <tr key={c.time_slice} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(0,204,255,0.1)' }}>
                      <td style={{ padding: '2px 6px' }}>{c.time_slice}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{c.simplices_24}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{c.simplices_41}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{c.spatial_volume}</td>
                      <td style={{
                        padding: '2px 6px', textAlign: 'right',
                        color: c.dim_spectral >= 3.5 ? '#00e599' : '#00ccff',
                      }}>
                        {c.dim_spectral.toFixed(3)}
                      </td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{c.total_simplices}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Veneziano - String Amplitudes */}
          {tab === 'veneziano' && data?.veneziano && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 4 }}>
                Veneziano String Amplitudes
              </h3>
              <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', marginBottom: 12 }}>
                {'A(s,t) = \u0393(-\u03B1(s))\u00B7\u0393(-\u03B1(t)) / \u0393(-\u03B1(s)-\u03B1(t))'}
              </p>
              <table style={{ width: '100%', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '3px 6px' }}>s</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>t</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>{'\u03B1(s)'}</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>{'\u03B1(t)'}</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>Amplitude</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>{"\u03B1'"}</th>
                    <th style={{ textAlign: 'right', padding: '3px 6px' }}>T_string</th>
                  </tr>
                </thead>
                <tbody>
                  {data.veneziano.map((v, i) => (
                    <tr key={i} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(0,204,255,0.1)' }}>
                      <td style={{ padding: '2px 6px' }}>{v.s.toFixed(2)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{v.t.toFixed(2)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{v.alpha_s.toFixed(4)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{v.alpha_t.toFixed(4)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right', color: v.amplitude > 0 ? '#00e599' : 'rgba(255,255,255,0.7)' }}>
                        {v.amplitude.toFixed(6)}
                      </td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{v.regge_slope.toFixed(4)}</td>
                      <td style={{ padding: '2px 6px', textAlign: 'right' }}>{v.string_tension.toFixed(4)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {data.veneziano.length > 0 && (
                <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', marginTop: 8, textAlign: 'center' }}>
                  String tension T = 1/(2{"\u03C0\u03B1'"}) = {data.veneziano[0].string_tension.toFixed(6)}
                </p>
              )}
            </div>
          )}

          {/* Page Curve - Black Hole Information */}
          {tab === 'page_curve' && data?.page_curve && (
            <div>
              <h3 style={{ color: '#00e599', fontSize: 14, marginBottom: 4 }}>
                Black Hole Information (Page Curve)
              </h3>
              <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', marginBottom: 12 }}>
                Information is conserved: S_total = const
              </p>
              {data.page_curve.map((p, i) => {
                const maxEntropy = p.total_entropy > 0 ? p.total_entropy : 1;
                const bhPct = (p.bh_entropy / maxEntropy) * 100;
                const radPct = (p.radiation_entropy / maxEntropy) * 100;
                return (
                  <div key={i} style={{ marginBottom: 8 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', color: 'rgba(255,255,255,0.6)', marginBottom: 2 }}>
                      <span>t={p.time.toFixed(1)} | M={p.bh_mass.toFixed(3)}</span>
                      <span>
                        S_total={p.total_entropy.toFixed(3)}
                        {p.past_page_time && <span style={{ color: '#ffd700', marginLeft: 6 }}>{'\uD83D\uDCCD'} Page Time</span>}
                      </span>
                    </div>
                    <div style={{ display: 'flex', gap: 2, width: '100%', height: 8, position: 'relative' }}>
                      {/* BH entropy bar (cyan) */}
                      <div style={{
                        width: `${bhPct}%`,
                        height: '100%',
                        background: '#00ccff',
                        borderRadius: '3px 0 0 3px',
                        transition: 'width 0.3s',
                        minWidth: bhPct > 0 ? 2 : 0,
                      }} />
                      {/* Radiation entropy bar (gold) */}
                      <div style={{
                        width: `${radPct}%`,
                        height: '100%',
                        background: '#ffd700',
                        borderRadius: '0 3px 3px 0',
                        transition: 'width 0.3s',
                        minWidth: radPct > 0 ? 2 : 0,
                      }} />
                      {/* Dashed total line */}
                      <div style={{
                        position: 'absolute',
                        top: 0, left: 0, right: 0, bottom: 0,
                        borderRight: '2px dashed rgba(255,255,255,0.3)',
                        pointerEvents: 'none',
                      }} />
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 9, fontFamily: 'JetBrains Mono, monospace', marginTop: 1 }}>
                      <span style={{ color: '#00ccff' }}>BH: {p.bh_entropy.toFixed(3)}</span>
                      <span style={{ color: '#ffd700' }}>Rad: {p.radiation_entropy.toFixed(3)}</span>
                    </div>
                  </div>
                );
              })}
              {/* Legend */}
              <div style={{ display: 'flex', gap: 16, justifyContent: 'center', marginTop: 8, fontSize: 9, fontFamily: 'JetBrains Mono, monospace' }}>
                <span><span style={{ display: 'inline-block', width: 8, height: 8, background: '#00ccff', borderRadius: 2, marginRight: 4, verticalAlign: 'middle' }} />BH Entropy</span>
                <span><span style={{ display: 'inline-block', width: 8, height: 8, background: '#ffd700', borderRadius: 2, marginRight: 4, verticalAlign: 'middle' }} />Radiation Entropy</span>
                <span style={{ color: 'rgba(255,255,255,0.4)' }}>┆ Total (const)</span>
              </div>
            </div>
          )}

          {/* Trinity Check */}
          {data && (
            <p style={{ color: '#00ccff', textAlign: 'center', fontSize: 11, marginTop: 16, fontFamily: 'JetBrains Mono, monospace', opacity: 0.6 }}>
              φ² + 1/φ² = {data.trinity_check.toFixed(6)} = TRINITY
            </p>
          )}
        </motion.div>
      </div>
    </Section>
  );
}
