"use client";
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Section from '../Section';
import { useI18n } from '../../i18n/context';
import { fetchHolographic, type HolographicResponse, type HoloMode } from '../../services/chatApi';

const MODES: { key: HoloMode; label: string }[] = [
  { key: 'ads', label: 'AdS/CFT' },
  { key: 'spin_network', label: 'Spin Network' },
  { key: 'penrose', label: 'Penrose' },
  { key: 'entropy', label: 'Entropy' },
  { key: 'hawking', label: 'Hawking' },
  { key: 'multiverse', label: 'Multiverse' },
  { key: 'string_landscape', label: 'String Landscape' },
  { key: 'ryu_takayanagi', label: 'Ryu-Takayanagi' },
];

const glass = {
  background: 'rgba(0,0,0,0.5)',
  border: '1px solid rgba(255,215,0,0.2)',
  borderRadius: '12px',
  padding: '16px',
  backdropFilter: 'blur(8px)',
};

export default function HolographicSection() {
  const { t } = useI18n();
  const msg = (t as any).holographic || {};

  const [mode, setMode] = useState<HoloMode>('ads');
  const [data, setData] = useState<HolographicResponse | null>(null);
  const [loading, setLoading] = useState(false);

  const loadData = async (m: HoloMode) => {
    setLoading(true);
    try {
      const result = await fetchHolographic(m);
      setData(result);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(mode); }, [mode]);

  return (
    <Section id="holographic">
      <div style={{ maxWidth: 900, margin: '0 auto', padding: 'clamp(16px, 5vw, 40px) clamp(12px, 4vw, 20px)' }}>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          style={{ color: '#ffd700', fontSize: 'clamp(20px, 6vw, 28px)', fontFamily: 'Outfit, sans-serif', textAlign: 'center', marginBottom: 8 }}
        >
          {msg.title || 'Holographic Renderer v3.1'}
        </motion.h2>
        <p style={{ color: 'rgba(255,215,0,0.5)', textAlign: 'center', fontSize: 13, marginBottom: 24, fontFamily: 'JetBrains Mono, monospace' }}>
          {msg.subtitle || 'Generated from: specs/tri/holographic_renderer.vibee'}
        </p>

        {/* Mode switcher */}
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 24, flexWrap: 'wrap' }}>
          {MODES.map(m => (
            <button
              key={m.key}
              onClick={() => setMode(m.key)}
              style={{
                padding: '6px 16px',
                borderRadius: 8,
                border: mode === m.key ? '1px solid #ffd700' : '1px solid rgba(255,215,0,0.2)',
                background: mode === m.key ? 'rgba(255,215,0,0.15)' : 'rgba(0,0,0,0.3)',
                color: mode === m.key ? '#ffd700' : 'rgba(255,255,255,0.5)',
                cursor: 'pointer',
                fontSize: 12,
                fontFamily: 'JetBrains Mono, monospace',
                transition: 'all 0.2s',
              }}
            >
              {m.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <motion.div
          key={mode}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.3 }}
          style={glass}
        >
          {loading && <p style={{ color: 'rgba(255,215,0,0.5)', textAlign: 'center' }}>Loading...</p>}

          {/* AdS/CFT Layers */}
          {data?.layers && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.adsTitle || 'AdS₅ Radial Slice — Bulk/Boundary Correspondence'}
              </h3>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11 }}>
                {data.layers.map((layer, i) => {
                  const barLen = Math.round(layer.width / 2);
                  const regionColor = layer.region === 'boundary' ? '#ffd700' : layer.region === 'near' ? '#00ccff' : layer.region === 'mid' ? '#00e599' : '#666';
                  return (
                    <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 2 }}>
                      <span style={{ color: '#888', width: 50 }}>z={layer.z.toFixed(2)}</span>
                      <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
                        <div style={{
                          width: `min(${barLen * 3}px, 100%)`,
                          height: 8,
                          background: `linear-gradient(90deg, transparent, ${regionColor}40, transparent)`,
                          borderLeft: `2px solid ${regionColor}`,
                          borderRight: `2px solid ${regionColor}`,
                          borderRadius: 2,
                        }} />
                      </div>
                      <span style={{ color: regionColor, width: 80, textAlign: 'right', fontSize: 10 }}>
                        S/A={layer.entropy_density.toFixed(2)}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Spin Network */}
          {data?.spin_nodes && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.spinTitle || 'Spin Network — Area Eigenvalues'}
              </h3>
              <table style={{ width: '100%', fontSize: 11, fontFamily: 'JetBrains Mono, monospace', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ color: '#ffd700' }}>
                    <th style={{ textAlign: 'left', padding: '4px 8px' }}>j</th>
                    <th style={{ textAlign: 'right', padding: '4px 8px' }}>Area (l_P²)</th>
                    <th style={{ textAlign: 'right', padding: '4px 8px' }}>Volume</th>
                  </tr>
                </thead>
                <tbody>
                  {data.spin_nodes.map(node => (
                    <tr key={node.id} style={{ color: 'rgba(255,255,255,0.7)', borderTop: '1px solid rgba(255,215,0,0.1)' }}>
                      <td style={{ padding: '3px 8px' }}>{node.spin.toFixed(1)}</td>
                      <td style={{ padding: '3px 8px', textAlign: 'right', color: '#00e599' }}>{node.area_eigenvalue.toFixed(6)}</td>
                      <td style={{ padding: '3px 8px', textAlign: 'right' }}>{node.volume_eigenvalue.toFixed(6)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Penrose Properties */}
          {data?.properties && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.penroseTitle || 'Penrose P3 Tiling — Golden Properties'}
              </h3>
              {data.properties.map((prop, i) => (
                <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', borderBottom: '1px solid rgba(255,215,0,0.08)', fontSize: 12, fontFamily: 'JetBrains Mono, monospace' }}>
                  <span style={{ color: 'rgba(255,255,255,0.6)' }}>{prop.description}</span>
                  <span style={{ color: '#ffd700' }}>{prop.value.toFixed(10)}</span>
                </div>
              ))}
            </div>
          )}

          {/* Entropy Surface */}
          {data?.entropy_surface && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.entropyTitle || 'Bekenstein-Hawking Entropy Surface'}
              </h3>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: 'rgba(255,255,255,0.7)' }}>
                <p>{msg.formula || 'Formula'}: <span style={{ color: '#ffd700' }}>{data.entropy_surface.formula}</span></p>
                <p>{msg.solarEntropy || 'Solar mass BH entropy'}: <span style={{ color: '#00e599' }}>~10^{data.entropy_surface.solar_mass_entropy_log10} bits</span></p>
                <p>{msg.holoBits || 'Holographic bits'}: <span style={{ color: '#00ccff' }}>{data.entropy_surface.holographic_bits.toFixed(10)}</span></p>
              </div>
            </div>
          )}

          {/* Hawking Frames */}
          {data?.hawking_frames && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.hawkingTitle || 'Hawking Radiation — Black Hole Evaporation'}
              </h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))', gap: 8 }}>
                {data.hawking_frames.map(frame => (
                  <div key={frame.frame} style={{
                    background: 'rgba(255,0,0,0.05)',
                    border: '1px solid rgba(255,100,100,0.2)',
                    borderRadius: 8,
                    padding: 8,
                    textAlign: 'center',
                    fontFamily: 'JetBrains Mono, monospace',
                    fontSize: 10,
                  }}>
                    <div style={{ color: '#ffd700', fontSize: 12, marginBottom: 4 }}>Frame {frame.frame}/6</div>
                    <div style={{ color: 'rgba(255,255,255,0.6)' }}>M={frame.mass.toFixed(2)} M☉</div>
                    <div style={{ color: '#ff6b6b' }}>T={frame.temperature.toFixed(4)} T_P</div>
                    <div style={{
                      width: `${frame.radius * 6}px`,
                      height: `${frame.radius * 6}px`,
                      borderRadius: '50%',
                      border: '2px solid #ff6b6b',
                      margin: '8px auto 0',
                      background: 'radial-gradient(circle, rgba(255,215,0,0.2), transparent)',
                    }} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Multiverse Bubbles */}
          {data?.multiverse_bubbles && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.multiverseTitle || 'Eternal Inflation — Bubble Universes'}
              </h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 10 }}>
                {data.multiverse_bubbles.map((bubble, i) => (
                  <motion.div
                    key={bubble.id}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.4, delay: i * 0.08 }}
                    style={{
                      background: bubble.is_our_vacuum ? 'rgba(255,215,0,0.08)' : 'rgba(0,0,0,0.3)',
                      border: bubble.is_our_vacuum ? '2px solid #ffd700' : '1px solid rgba(255,215,0,0.15)',
                      borderRadius: 10,
                      padding: 10,
                      textAlign: 'center',
                      fontFamily: 'JetBrains Mono, monospace',
                      fontSize: 10,
                      position: 'relative',
                    }}
                  >
                    {bubble.is_our_vacuum && (
                      <div style={{
                        position: 'absolute', top: -8, left: '50%', transform: 'translateX(-50%)',
                        background: '#ffd700', color: '#000', fontSize: 8, fontWeight: 700,
                        padding: '1px 8px', borderRadius: 4, whiteSpace: 'nowrap',
                      }}>
                        OUR UNIVERSE
                      </div>
                    )}
                    <div style={{ color: '#ffd700', fontSize: 12, marginBottom: 4, marginTop: bubble.is_our_vacuum ? 4 : 0 }}>
                      Bubble #{bubble.id}
                    </div>
                    <div style={{
                      width: `${bubble.radius * 3}px`,
                      height: `${bubble.radius * 3}px`,
                      borderRadius: '50%',
                      border: `2px solid ${bubble.is_our_vacuum ? '#ffd700' : 'rgba(0,204,255,0.4)'}`,
                      margin: '6px auto',
                      background: bubble.is_our_vacuum
                        ? 'radial-gradient(circle, rgba(255,215,0,0.25), transparent)'
                        : 'radial-gradient(circle, rgba(0,204,255,0.15), transparent)',
                    }} />
                    <div style={{ color: 'rgba(255,255,255,0.6)' }}>
                      &#923; = {bubble.cosmological_constant.toFixed(4)}
                    </div>
                    <div style={{ color: '#00ccff' }}>
                      P_tunnel = {bubble.tunneling_prob.toExponential(1)}
                    </div>
                    <div style={{ color: 'rgba(255,255,255,0.5)' }}>
                      r = {bubble.radius} | H = {bubble.inflation_rate}
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          )}

          {/* String Landscape */}
          {data?.string_landscape && (
            <div>
              <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 12 }}>
                {msg.stringTitle || 'String Theory Landscape — Flux Vacua'}
              </h3>
              <div style={{
                position: 'relative',
                background: 'rgba(0,0,0,0.3)',
                border: '1px solid rgba(255,215,0,0.1)',
                borderRadius: 8,
                padding: 16,
                minHeight: 280,
              }}>
                {/* Axes labels */}
                <div style={{ position: 'absolute', bottom: 4, left: '50%', transform: 'translateX(-50%)', fontSize: 9, color: 'rgba(255,255,255,0.3)', fontFamily: 'JetBrains Mono, monospace' }}>
                  modulus_x
                </div>
                <div style={{ position: 'absolute', left: 4, top: '50%', transform: 'translateY(-50%) rotate(-90deg)', fontSize: 9, color: 'rgba(255,255,255,0.3)', fontFamily: 'JetBrains Mono, monospace' }}>
                  modulus_y
                </div>
                {/* Scatter points */}
                {data.string_landscape.map((pt, i) => {
                  const x = (pt.modulus_x / 3.0) * 90 + 5;
                  const y = 95 - (pt.modulus_y / 2.5) * 90;
                  const isStable = pt.energy < 0;
                  const pointColor = pt.is_minimum ? '#ffd700' : isStable ? '#00e599' : '#ff6b6b';
                  return (
                    <motion.div
                      key={i}
                      initial={{ opacity: 0, scale: 0 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{ duration: 0.3, delay: i * 0.06 }}
                      style={{
                        position: 'absolute',
                        left: `${x}%`,
                        top: `${y}%`,
                        transform: 'translate(-50%, -50%)',
                        textAlign: 'center',
                      }}
                    >
                      <div style={{
                        width: pt.is_minimum ? 18 : 12,
                        height: pt.is_minimum ? 18 : 12,
                        borderRadius: '50%',
                        background: `radial-gradient(circle, ${pointColor}60, ${pointColor}20)`,
                        border: `2px solid ${pointColor}`,
                        margin: '0 auto 2px',
                        boxShadow: pt.is_minimum ? `0 0 8px ${pointColor}40` : 'none',
                      }} />
                      {pt.is_minimum && (
                        <div style={{ color: '#ffd700', fontSize: 8, fontWeight: 700, whiteSpace: 'nowrap' }}>
                          &#9733; MINIMUM
                        </div>
                      )}
                      <div style={{ fontSize: 8, color: pointColor, fontFamily: 'JetBrains Mono, monospace', whiteSpace: 'nowrap' }}>
                        E={pt.energy.toFixed(4)}
                      </div>
                      <div style={{ fontSize: 7, color: 'rgba(255,255,255,0.4)', fontFamily: 'JetBrains Mono, monospace' }}>
                        F={pt.flux_config}
                      </div>
                      {pt.tunneling_to !== null && (
                        <div style={{ fontSize: 7, color: 'rgba(0,204,255,0.6)', fontFamily: 'JetBrains Mono, monospace', whiteSpace: 'nowrap' }}>
                          &#8594; Point {pt.tunneling_to + 1}
                        </div>
                      )}
                    </motion.div>
                  );
                })}
              </div>
              <div style={{ display: 'flex', gap: 16, justifyContent: 'center', marginTop: 8, fontFamily: 'JetBrains Mono, monospace', fontSize: 9 }}>
                <span><span style={{ color: '#ffd700' }}>&#9679;</span> <span style={{ color: 'rgba(255,255,255,0.5)' }}>Minimum</span></span>
                <span><span style={{ color: '#00e599' }}>&#9679;</span> <span style={{ color: 'rgba(255,255,255,0.5)' }}>Stable (E&lt;0)</span></span>
                <span><span style={{ color: '#ff6b6b' }}>&#9679;</span> <span style={{ color: 'rgba(255,255,255,0.5)' }}>Unstable (E&gt;0)</span></span>
              </div>
            </div>
          )}

          {/* Ryu-Takayanagi */}
          {data?.ryu_takayanagi && (() => {
            const maxEntropy = Math.max(...data.ryu_takayanagi.map(g => g.entanglement_entropy));
            return (
              <div>
                <h3 style={{ color: '#00ccff', fontSize: 14, marginBottom: 4 }}>
                  {msg.ryuTitle || 'Ryu-Takayanagi — Holographic Entanglement Entropy'}
                </h3>
                <p style={{ color: 'rgba(255,215,0,0.6)', fontSize: 10, fontFamily: 'JetBrains Mono, monospace', marginBottom: 12 }}>
                  S_A = (c/3) &middot; log(&#8467;/&#949;) + &#966;-correction
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {data.ryu_takayanagi.map((geo, i) => (
                    <motion.div
                      key={i}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ duration: 0.35, delay: i * 0.1 }}
                      style={{
                        background: 'rgba(0,0,0,0.3)',
                        border: '1px solid rgba(0,204,255,0.15)',
                        borderRadius: 8,
                        padding: '10px 14px',
                        fontFamily: 'JetBrains Mono, monospace',
                        fontSize: 11,
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                        <span style={{ color: '#ffd700', fontSize: 12 }}>
                          Boundary [{geo.boundary_start.toFixed(2)}, {geo.boundary_end.toFixed(2)}]
                        </span>
                        <span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9 }}>
                          L_geo = {geo.geodesic_length.toFixed(3)}
                        </span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
                        <span style={{ color: '#00ccff', minWidth: 'min(120px, 35%)' }}>
                          S_ent = {geo.entanglement_entropy.toFixed(3)}
                        </span>
                        <div style={{ flex: 1, height: 6, background: 'rgba(0,204,255,0.1)', borderRadius: 3, overflow: 'hidden' }}>
                          <motion.div
                            initial={{ width: 0 }}
                            animate={{ width: `${(geo.entanglement_entropy / maxEntropy) * 100}%` }}
                            transition={{ duration: 0.6, delay: i * 0.1 }}
                            style={{
                              height: '100%',
                              background: 'linear-gradient(90deg, #00ccff, #ffd700)',
                              borderRadius: 3,
                            }}
                          />
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 16, color: 'rgba(255,255,255,0.5)', fontSize: 9 }}>
                        <span>&#966;-corr: <span style={{ color: '#00e599' }}>{geo.phi_correction.toFixed(4)}</span></span>
                        <span>A/4G: <span style={{ color: 'rgba(255,215,0,0.7)' }}>{geo.area_over_4g.toFixed(3)}</span></span>
                      </div>
                    </motion.div>
                  ))}
                </div>
              </div>
            );
          })()}

          {/* Trinity Check */}
          {data && (
            <p style={{ color: '#ffd700', textAlign: 'center', fontSize: 11, marginTop: 16, fontFamily: 'JetBrains Mono, monospace', opacity: 0.6 }}>
              φ² + 1/φ² = {data.trinity_check.toFixed(6)} = TRINITY
            </p>
          )}
        </motion.div>
      </div>
    </Section>
  );
}
