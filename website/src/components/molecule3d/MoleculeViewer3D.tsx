// ═══════════════════════════════════════════════════════════════════════════════
// MOLECULE VIEWER 3D — React Three Fiber ball-and-stick molecule renderer
// Lazy-loaded by SacredChemistryWidget when user clicks "Show 3D"
// ═══════════════════════════════════════════════════════════════════════════════

import { useRef, useMemo } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Html } from '@react-three/drei';
import * as THREE from 'three';
import { getElementColor, getElementRadius } from '../../data/elementColors';
import { getGeometry, type MoleculeGeometry, type Atom3DData } from '../../data/moleculeGeometries';
import { parseFormula } from '../../utils/chemistry';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948;
const PHI_SQ = PHI * PHI;       // 2.618
const INV_PHI = 1 / PHI;        // 0.618
const PHI_TOLERANCE = 0.05;     // 5% tolerance for sacred detection
const GOLDEN_COLOR = new THREE.Color('#ffd700');

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BOND DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

function isPhiProportioned(ratio: number): boolean {
  return (
    Math.abs(ratio - PHI) / PHI < PHI_TOLERANCE ||
    Math.abs(ratio - INV_PHI) / INV_PHI < PHI_TOLERANCE ||
    Math.abs(ratio - PHI_SQ) / PHI_SQ < PHI_TOLERANCE
  );
}

function computeBondLength(a: [number, number, number], b: [number, number, number]): number {
  const dx = a[0] - b[0];
  const dy = a[1] - b[1];
  const dz = a[2] - b[2];
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

// ═══════════════════════════════════════════════════════════════════════════════
// AtomMesh — Sphere with CPK color + element label
// ═══════════════════════════════════════════════════════════════════════════════

function AtomMesh({ atom }: { atom: Atom3DData }) {
  const color = getElementColor(atom.element);
  const radius = getElementRadius(atom.element);

  return (
    <group position={atom.position}>
      <mesh>
        <sphereGeometry args={[radius, 24, 24]} />
        <meshStandardMaterial
          color={color}
          roughness={0.3}
          metalness={0.2}
        />
      </mesh>
      <Html
        center
        distanceFactor={8}
        style={{
          color: '#fff',
          fontSize: '10px',
          fontFamily: 'JetBrains Mono, monospace',
          fontWeight: 700,
          textShadow: '0 0 4px rgba(0,0,0,0.8)',
          pointerEvents: 'none',
          userSelect: 'none',
        }}
      >
        {atom.element}
      </Html>
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BondMesh — Cylinder between two atoms with optional golden sacred glow
// ═══════════════════════════════════════════════════════════════════════════════

function BondMesh({
  from,
  to,
  order,
  sacred,
}: {
  from: [number, number, number];
  to: [number, number, number];
  order: 1 | 2 | 3;
  sacred: boolean;
}) {
  const glowRef = useRef<THREE.Mesh>(null);

  // Animate sacred glow pulse
  useFrame(({ clock }) => {
    if (glowRef.current && sacred) {
      const mat = glowRef.current.material as THREE.MeshStandardMaterial;
      mat.emissiveIntensity = 0.4 + Math.sin(clock.elapsedTime * 2) * 0.2;
    }
  });

  const { midpoint, length, quaternion } = useMemo(() => {
    const a = new THREE.Vector3(...from);
    const b = new THREE.Vector3(...to);
    const mid = a.clone().add(b).multiplyScalar(0.5);
    const dir = b.clone().sub(a);
    const len = dir.length();
    dir.normalize();
    const quat = new THREE.Quaternion();
    quat.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    return { midpoint: mid, length: len, quaternion: quat };
  }, [from, to]);

  const bondRadius = 0.06;
  const offsets = order === 1 ? [0] : order === 2 ? [-0.08, 0.08] : [-0.1, 0, 0.1];

  return (
    <group>
      {offsets.map((offset, i) => (
        <group key={i} position={[midpoint.x, midpoint.y, midpoint.z]} quaternion={quaternion}>
          <mesh position={[offset, 0, 0]}>
            <cylinderGeometry args={[bondRadius, bondRadius, length, 8]} />
            <meshStandardMaterial
              color={sacred ? '#ffd700' : '#888899'}
              emissive={sacred ? GOLDEN_COLOR : undefined}
              emissiveIntensity={sacred ? 0.4 : 0}
              roughness={0.5}
              metalness={sacred ? 0.3 : 0.1}
            />
          </mesh>
          {/* Sacred glow halo */}
          {sacred && i === 0 && (
            <mesh ref={glowRef} position={[offset, 0, 0]}>
              <cylinderGeometry args={[bondRadius * 2.5, bondRadius * 2.5, length, 8]} />
              <meshStandardMaterial
                color="#ffd700"
                emissive={GOLDEN_COLOR}
                emissiveIntensity={0.4}
                transparent
                opacity={0.15}
                roughness={1}
              />
            </mesh>
          )}
        </group>
      ))}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MoleculeScene — Maps geometry to 3D meshes, detects phi-proportioned bonds
// ═══════════════════════════════════════════════════════════════════════════════

function MoleculeScene({ geometry }: { geometry: MoleculeGeometry }) {
  const sacredBonds = useMemo(() => {
    if (geometry.bonds.length < 2) return new Set<number>();

    const lengths = geometry.bonds.map(b =>
      computeBondLength(
        geometry.atoms[b.from].position,
        geometry.atoms[b.to].position
      )
    );
    const minLen = Math.min(...lengths);
    if (minLen === 0) return new Set<number>();

    const sacred = new Set<number>();
    for (let i = 0; i < lengths.length; i++) {
      const ratio = lengths[i] / minLen;
      if (ratio > 1.001 && isPhiProportioned(ratio)) {
        sacred.add(i);
      }
    }
    return sacred;
  }, [geometry]);

  return (
    <>
      {geometry.atoms.map((atom, i) => (
        <AtomMesh key={`atom-${i}`} atom={atom} />
      ))}
      {geometry.bonds.map((bond, i) => (
        <BondMesh
          key={`bond-${i}`}
          from={geometry.atoms[bond.from].position}
          to={geometry.atoms[bond.to].position}
          order={bond.order}
          sacred={sacredBonds.has(i)}
        />
      ))}
    </>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MoleculeViewer3D — Main exported component with Canvas + controls
// ═══════════════════════════════════════════════════════════════════════════════

interface MoleculeViewer3DProps {
  formula: string;
}

export default function MoleculeViewer3D({ formula }: MoleculeViewer3DProps) {
  const geometry = useMemo(() => {
    const parsed = parseFormula(formula);
    return getGeometry(formula, parsed);
  }, [formula]);

  if (geometry.atoms.length === 0) {
    return (
      <div style={{
        height: 300,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'rgba(255, 255, 255, 0.05)',
        backdropFilter: 'blur(10px)',
        border: '1px solid rgba(255, 215, 0, 0.2)',
        borderRadius: '8px',
        marginTop: '0.5rem',
      }}>
        <span style={{ color: 'rgba(255,255,255,0.4)', fontFamily: 'JetBrains Mono, monospace', fontSize: '0.8rem' }}>
          No geometry for {formula}
        </span>
      </div>
    );
  }

  return (
    <div style={{
      height: 350,
      marginTop: '0.5rem',
      background: 'rgba(0, 0, 0, 0.4)',
      backdropFilter: 'blur(10px)',
      border: '1px solid rgba(255, 215, 0, 0.2)',
      borderRadius: '8px',
      overflow: 'hidden',
      position: 'relative',
    }}>
      {/* Legend */}
      <div style={{
        position: 'absolute',
        bottom: '0.5rem',
        left: '0.5rem',
        zIndex: 10,
        display: 'flex',
        gap: '0.5rem',
        alignItems: 'center',
      }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: '0.25rem',
          fontSize: '0.6rem', fontFamily: 'JetBrains Mono, monospace',
          color: 'rgba(255,255,255,0.4)',
        }}>
          <div style={{ width: 8, height: 3, background: '#888899', borderRadius: 1 }} />
          bond
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: '0.25rem',
          fontSize: '0.6rem', fontFamily: 'JetBrains Mono, monospace',
          color: '#ffd700',
        }}>
          <div style={{ width: 8, height: 3, background: '#ffd700', borderRadius: 1, boxShadow: '0 0 4px #ffd700' }} />
          sacred
        </div>
      </div>
      <Canvas
        camera={{ position: [0, 0, 6], fov: 50 }}
        dpr={[1, 1.5]}
        gl={{ antialias: true, alpha: true }}
      >
        <ambientLight intensity={0.6} />
        <directionalLight position={[5, 5, 5]} intensity={0.8} />
        <directionalLight position={[-3, -3, 2]} intensity={0.3} />
        <MoleculeScene geometry={geometry} />
        <OrbitControls
          autoRotate
          autoRotateSpeed={1.5}
          enableZoom
          enablePan={false}
          minDistance={3}
          maxDistance={15}
        />
      </Canvas>
    </div>
  );
}
