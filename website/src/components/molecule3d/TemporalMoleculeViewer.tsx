// ═══════════════════════════════════════════════════════════════════════════════
// TEMPORAL MOLECULE VIEWER — 3D reaction animation with φ-time curves
// Shows reactants transforming into products over sacred time
// ═══════════════════════════════════════════════════════════════════════════════

import { useState, useRef, useMemo, useEffect, useCallback } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Html } from '@react-three/drei';
import * as THREE from 'three';
import { getElementColor, getElementRadius } from '../../data/elementColors';
import { getGeometry, type MoleculeGeometry, type Atom3DData, type Bond3DData } from '../../data/moleculeGeometries';
import { parseFormula } from '../../utils/chemistry';
import {
  phiTimeReaction,
  getTemporalPhase,
  goldenSpiralPoint,
  SACRED_TIME_MARKERS,
  type AtomState,
  type BondState,
  type TemporalFrame,
  createInterpolatedFrame,
  mapReactantAtoms,
} from '../../utils/temporal';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498948;
const GOLDEN_COLOR = new THREE.Color('#ffd700');
const INV_PHI_SQ = 1 / (PHI * PHI); // 0.382

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERTERS
// ═══════════════════════════════════════════════════════════════════════════════

function geometryToAtomStates(geometry: MoleculeGeometry): AtomState[] {
  return geometry.atoms.map(atom => ({
    element: atom.element,
    position: atom.position,
    visible: true,
  }));
}

function geometryToBondStates(geometry: MoleculeGeometry): BondState[] {
  return geometry.bonds.map(bond => ({
    from: bond.from,
    to: bond.to,
    order: bond.order,
    strength: 1,
  }));
}

function atomStateTo3DData(state: AtomState): Atom3DData {
  return {
    element: state.element,
    position: state.position,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// AnimatedAtomMesh — Sphere with fade in/out
// ═══════════════════════════════════════════════════════════════════════════════

function AnimatedAtomMesh({
  atom,
  strength,
}: {
  atom: AtomState;
  strength: number;
}) {
  const color = getElementColor(atom.element);
  const radius = getElementRadius(atom.element);

  if (!atom.visible || strength < 0.01) return null;

  return (
    <group position={atom.position}>
      <mesh>
        <sphereGeometry args={[radius * (0.8 + strength * 0.2), 24, 24]} />
        <meshStandardMaterial
          color={color}
          roughness={0.3}
          metalness={0.2}
          transparent={strength < 1}
          opacity={strength}
        />
      </mesh>
      {strength > 0.5 && (
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
            opacity: strength,
          }}
        >
          {atom.element}
        </Html>
      )}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// AnimatedBondMesh — Cylinder with strength-based opacity
// ═══════════════════════════════════════════════════════════════════════════════

function AnimatedBondMesh({
  from,
  to,
  order,
  strength,
  sacred,
}: {
  from: [number, number, number];
  to: [number, number, number];
  order: 1 | 2 | 3;
  strength: number;
  sacred: boolean;
}) {
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

  if (strength < 0.01) return null;

  const bondRadius = 0.06;
  const offsets = order === 1 ? [0] : order === 2 ? [-0.08, 0.08] : [-0.1, 0, 0.1];

  // Color transition: gray (forming) → golden (sacred) → white (complete)
  const bondColor = sacred ? GOLDEN_COLOR : new THREE.Color('#888899');

  return (
    <group>
      {offsets.map((offset, i) => (
        <group key={i} position={[midpoint.x, midpoint.y, midpoint.z]} quaternion={quaternion}>
          <mesh position={[offset, 0, 0]}>
            <cylinderGeometry args={[bondRadius, bondRadius, length, 8]} />
            <meshStandardMaterial
              color={bondColor}
              emissive={sacred ? GOLDEN_COLOR : undefined}
              emissiveIntensity={sacred ? strength * 0.5 : 0}
              roughness={0.5}
              metalness={sacred ? 0.3 : 0.1}
              transparent={strength < 1}
              opacity={strength}
            />
          </mesh>
          {/* Sacred glow halo */}
          {sacred && i === 0 && strength > 0.5 && (
            <mesh position={[offset, 0, 0]}>
              <cylinderGeometry args={[bondRadius * 2.5, bondRadius * 2.5, length, 8]} />
              <meshStandardMaterial
                color="#ffd700"
                emissive={GOLDEN_COLOR}
                emissiveIntensity={strength * 0.4}
                transparent
                opacity={0.15 * strength}
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
// TemporalScene — Animated 3D scene
// ═══════════════════════════════════════════════════════════════════════════════

interface TemporalSceneProps {
  frame: TemporalFrame;
  atomMapping: Map<number, number>;
}

function TemporalScene({ frame, atomMapping }: TemporalSceneProps) {
  // Detect sacred bonds (phi-proportioned)
  const sacredBonds = useMemo(() => {
    const sacred = new Set<number>();
    if (frame.bonds.length < 2) return sacred;

    const lengths = frame.bonds
      .filter(b => b.strength > 0.5)
      .map(b => {
        const fromAtom = frame.atoms[b.from];
        const toAtom = frame.atoms[b.to];
        const dx = fromAtom.position[0] - toAtom.position[0];
        const dy = fromAtom.position[1] - toAtom.position[1];
        const dz = fromAtom.position[2] - toAtom.position[2];
        return Math.sqrt(dx * dx + dy * dy + dz * dz);
      });

    if (lengths.length === 0) return sacred;
    const minLen = Math.min(...lengths);
    if (minLen === 0) return sacred;

    const phi = PHI;
    const invPhi = 1 / phi;
    const phiSq = phi * phi;
    const tolerance = 0.05;

    let idx = 0;
    for (const bond of frame.bonds) {
      if (bond.strength < 0.5) {
        idx++;
        continue;
      }
      const fromAtom = frame.atoms[bond.from];
      const toAtom = frame.atoms[bond.to];
      const dx = fromAtom.position[0] - toAtom.position[0];
      const dy = fromAtom.position[1] - toAtom.position[1];
      const dz = fromAtom.position[2] - toAtom.position[2];
      const len = Math.sqrt(dx * dx + dy * dy + dz * dz);
      const ratio = len / minLen;

      if (
        (ratio > 1.001 && Math.abs(ratio - phi) / phi < tolerance) ||
        Math.abs(ratio - invPhi) / invPhi < tolerance ||
        Math.abs(ratio - phiSq) / phiSq < tolerance
      ) {
        sacred.add(idx);
      }
      idx++;
    }
    return sacred;
  }, [frame]);

  return (
    <>
      {frame.atoms.map((atom, i) => (
        <AnimatedAtomMesh key={`atom-${i}`} atom={atom} strength={1} />
      ))}
      {frame.bonds.map((bond, i) => (
        <AnimatedBondMesh
          key={`bond-${i}`}
          from={frame.atoms[bond.from].position}
          to={frame.atoms[bond.to].position}
          order={bond.order}
          strength={bond.strength}
          sacred={sacredBonds.has(i)}
        />
      ))}
    </>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// GoldenSpiralTimeline — UI timeline component
// ═══════════════════════════════════════════════════════════════════════════════

interface GoldenSpiralTimelineProps {
  currentTime: number;
  onTimeChange: (t: number) => void;
  isPlaying: boolean;
  onPlayPause: () => void;
}

function GoldenSpiralTimeline({
  currentTime,
  onTimeChange,
  isPlaying,
  onPlayPause,
}: GoldenSpiralTimelineProps) {
  const svgWidth = 280;
  const svgHeight = 60;
  const centerX = svgWidth / 2;
  const centerY = svgHeight / 2;

  // Generate spiral points
  const spiralPath = useMemo(() => {
    const points: [number, number][] = [];
    for (let t = 0; t <= 1; t += 0.02) {
      const [x, y] = goldenSpiralPoint(t, 20);
      points.push([centerX + x, centerY + y]);
    }
    return points;
  }, []);

  // Current position on spiral
  const currentPos = useMemo(() => {
    const [x, y] = goldenSpiralPoint(currentTime, 20);
    return [centerX + x, centerY + y];
  }, [currentTime, centerX, centerY]);

  return (
    <div style={{
      marginTop: '0.5rem',
      padding: '0.5rem',
      background: 'rgba(0, 0, 0, 0.3)',
      border: '1px solid rgba(255, 215, 0, 0.15)',
      borderRadius: '6px',
    }}>
      {/* Header with label and controls */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '0.4rem',
      }}>
        <span style={{
          fontSize: '0.65rem',
          fontFamily: 'JetBrains Mono, monospace',
          color: '#ffd700',
          fontWeight: 600,
        }}>
          φ-TIME
        </span>
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          <span style={{
            fontSize: '0.6rem',
            fontFamily: 'JetBrains Mono, monospace',
            color: 'rgba(255,255,255,0.5)',
          }}>
            {getTemporalPhase(currentTime).toUpperCase()}
          </span>
          <button
            onClick={onPlayPause}
            style={{
              padding: '0.2rem 0.5rem',
              fontSize: '0.7rem',
              fontFamily: 'JetBrains Mono, monospace',
              background: isPlaying ? 'rgba(255,100,100,0.2)' : 'rgba(0,229,153,0.2)',
              border: isPlaying ? '1px solid rgba(255,100,100,0.4)' : '1px solid rgba(0,229,153,0.4)',
              borderRadius: '4px',
              color: isPlaying ? '#ff6464' : '#00e599',
              cursor: 'pointer',
            }}
          >
            {isPlaying ? '❚❚' : '▶'}
          </button>
        </div>
      </div>

      {/* Spiral SVG */}
      <svg width={svgWidth} height={svgHeight} style={{ display: 'block', margin: '0 auto' }}>
        {/* Spiral path */}
        <path
          d={`M ${spiralPath.map(p => p.join(',')).join(' L ')}`}
          fill="none"
          stroke="rgba(255, 215, 0, 0.2)"
          strokeWidth="1"
        />
        {/* Traveled path */}
        <path
          d={`M ${spiralPath.slice(0, Math.floor(currentTime * spiralPath.length) + 1).map(p => p.join(',')).join(' L ')}`}
          fill="none"
          stroke="#ffd700"
          strokeWidth="2"
        />
        {/* Sacred markers */}
        {SACRED_TIME_MARKERS.slice(1, -1).map(marker => {
          const [mx, my] = goldenSpiralPoint(marker.t, 20);
          return (
            <circle
              key={marker.t}
              cx={centerX + mx}
              cy={centerY + my}
              r="3"
              fill={currentTime >= marker.t ? '#ffd700' : 'rgba(255,255,255,0.2)'}
            />
          );
        })}
        {/* Current position */}
        <circle cx={currentPos[0]} cy={currentPos[1]} r="5" fill="#ffd700">
          <animate
            attributeName="r"
            values="5;7;5"
            dur="1s"
            repeatCount="indefinite"
          />
        </circle>
      </svg>

      {/* Slider */}
      <input
        type="range"
        min="0"
        max="1"
        step="0.001"
        value={currentTime}
        onChange={(e) => onTimeChange(parseFloat(e.target.value))}
        style={{
          width: '100%',
          marginTop: '0.3rem',
          height: '4px',
          borderRadius: '2px',
          background: 'linear-gradient(to right, rgba(255,215,0,0.2), #ffd700)',
          appearance: 'none',
          cursor: 'pointer',
        }}
      />
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TemporalMoleculeViewer — Main exported component
// ═══════════════════════════════════════════════════════════════════════════════

interface TemporalMoleculeViewerProps {
  reactantsFormula: string;
  productsFormula: string;
  duration?: number; // animation duration in seconds
}

export default function TemporalMoleculeViewer({
  reactantsFormula,
  productsFormula,
  duration = 5,
}: TemporalMoleculeViewerProps) {
  const [currentTime, setCurrentTime] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const animationRef = useRef<number | null>(null);
  const startTimeRef = useRef<number | null>(null);

  // Get geometries
  const reactantGeometry = useMemo(() => {
    const parsed = parseFormula(reactantsFormula);
    return getGeometry(reactantsFormula, parsed);
  }, [reactantsFormula]);

  const productGeometry = useMemo(() => {
    const parsed = parseFormula(productsFormula);
    return getGeometry(productsFormula, parsed);
  }, [productsFormula]);

  // Create temporal frames
  const reactantsFrame = useMemo(() => ({
    atoms: geometryToAtomStates(reactantGeometry),
    bonds: geometryToBondStates(reactantGeometry),
    time: 0,
    label: `Reactants: ${reactantsFormula}`,
  }), [reactantGeometry, reactantsFormula]);

  const productsFrame = useMemo(() => ({
    atoms: geometryToAtomStates(productGeometry),
    bonds: geometryToBondStates(productGeometry),
    time: 1,
    label: `Products: ${productsFormula}`,
  }), [productGeometry, productsFormula]);

  const atomMapping = useMemo(() => {
    return mapReactantAtoms(reactantsFrame.atoms, productsFrame.atoms);
  }, [reactantsFrame.atoms, productsFrame.atoms]);

  // Current interpolated frame
  const currentFrame = useMemo(() => {
    return createInterpolatedFrame(reactantsFrame, productsFrame, currentTime, atomMapping);
  }, [reactantsFrame, productsFrame, currentTime, atomMapping]);

  // Animation loop
  useEffect(() => {
    if (!isPlaying) {
      if (animationRef.current !== null) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
      startTimeRef.current = null;
      return;
    }

    const animate = (timestamp: number) => {
      if (startTimeRef.current === null) {
        startTimeRef.current = timestamp - (currentTime * duration * 1000);
      }

      const elapsed = timestamp - startTimeRef.current;
      const newTime = Math.min(elapsed / (duration * 1000), 1);

      setCurrentTime(newTime);

      if (newTime < 1) {
        animationRef.current = requestAnimationFrame(animate);
      } else {
        setIsPlaying(false);
      }
    };

    animationRef.current = requestAnimationFrame(animate);

    return () => {
      if (animationRef.current !== null) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isPlaying, duration, currentTime]);

  const handleTimeChange = useCallback((t: number) => {
    setCurrentTime(t);
    if (isPlaying && t >= 1) {
      setIsPlaying(false);
    }
  }, [isPlaying]);

  const handlePlayPause = useCallback(() => {
    if (currentTime >= 1) {
      setCurrentTime(0);
      startTimeRef.current = null;
    }
    setIsPlaying(!isPlaying);
  }, [isPlaying, currentTime]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (animationRef.current !== null) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, []);

  if (reactantGeometry.atoms.length === 0 || productGeometry.atoms.length === 0) {
    return (
      <div style={{
        height: 400,
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
          Cannot visualize: {reactantsFormula} → {productsFormula}
        </span>
      </div>
    );
  }

  return (
    <div style={{
      marginTop: '0.5rem',
      background: 'rgba(0, 0, 0, 0.4)',
      backdropFilter: 'blur(10px)',
      border: '1px solid rgba(255, 215, 0, 0.2)',
      borderRadius: '8px',
      overflow: 'hidden',
    }}>
      {/* Reaction equation header */}
      <div style={{
        textAlign: 'center',
        padding: '0.5rem',
        background: 'rgba(255, 215, 0, 0.08)',
        borderBottom: '1px solid rgba(255, 215, 0, 0.15)',
      }}>
        <span style={{
          fontSize: '0.8rem',
          fontFamily: 'JetBrains Mono, monospace',
          color: '#ffd700',
          fontWeight: 600,
        }}>
          {reactantsFormula} → {productsFormula}
        </span>
        <span style={{
          marginLeft: '0.5rem',
          fontSize: '0.65rem',
          fontFamily: 'JetBrains Mono, monospace',
          color: 'rgba(255,255,255,0.5)',
        }}>
          {currentFrame.label}
        </span>
      </div>

      {/* 3D Canvas */}
      <div style={{ height: 300, position: 'relative' }}>
        <Canvas
          camera={{ position: [0, 0, 6], fov: 50 }}
          dpr={[1, 1.5]}
          gl={{ antialias: true, alpha: true }}
        >
          <ambientLight intensity={0.6} />
          <directionalLight position={[5, 5, 5]} intensity={0.8} />
          <directionalLight position={[-3, -3, 2]} intensity={0.3} />
          <TemporalScene frame={currentFrame} atomMapping={atomMapping} />
          <OrbitControls
            enableZoom
            enablePan={false}
            minDistance={3}
            maxDistance={15}
          />
        </Canvas>

        {/* Phase indicator overlay */}
        <div style={{
          position: 'absolute',
          top: '0.5rem',
          right: '0.5rem',
          padding: '0.3rem 0.6rem',
          borderRadius: '4px',
          background: 'rgba(0,0,0,0.6)',
          border: '1px solid rgba(255,215,0,0.2)',
          fontSize: '0.6rem',
          fontFamily: 'JetBrains Mono, monospace',
          color: '#ffd700',
        }}>
          t = {currentTime.toFixed(3)}
        </div>
      </div>

      {/* Timeline */}
      <div style={{ padding: '0.5rem' }}>
        <GoldenSpiralTimeline
          currentTime={currentTime}
          onTimeChange={handleTimeChange}
          isPlaying={isPlaying}
          onPlayPause={handlePlayPause}
        />
      </div>
    </div>
  );
}
