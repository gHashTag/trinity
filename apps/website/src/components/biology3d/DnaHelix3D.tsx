// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BIOLOGY v14.0 — 3D DNA HELIX
// Double helix visualization with φ-time kinetics
// ═══════════════════════════════════════════════════════════════════════════════

"use client";

import React, { useRef, useMemo } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import { DNA_HELIX, BASE_COLORS, isFibonacciPosition } from '../../data/dnaData';

const PHI = 1.6180339887498948482;
const GOLDEN_GLOW = '#ffd700';

interface DnaHelix3DProps {
  sequence: string;
  showTime?: boolean;
  height?: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BASE PAIR COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

interface BasePairMeshProps {
  position: [number, number, number];
  base1: string;
  base2: string;
  index: number;
  isSacred: boolean;
}

function BasePairMesh({ position, base1, base2, index, isSacred }: BasePairMeshProps) {
  const meshRef = useRef<THREE.Group>(null);

  useFrame((state) => {
    if (meshRef.current) {
      // Gentle rotation for sacred positions
      if (isSacred) {
        meshRef.current.rotation.y = Math.sin(state.clock.elapsedTime * 0.5) * 0.1;
      }
    }
  });

  const color1 = BASE_COLORS[base1 as keyof typeof BASE_COLORS] || '#ffffff';
  const color2 = BASE_COLORS[base2 as keyof typeof BASE_COLORS] || '#ffffff';

  return (
    <group ref={meshRef} position={position}>
      {/* Base 1 sphere */}
      <mesh position={[-1, 0, 0]}>
        <sphereGeometry args={[0.4, 16, 16]} />
        <meshStandardMaterial
          color={color1}
          emissive={isSacred ? GOLDEN_GLOW : color1}
          emissiveIntensity={isSacred ? 0.5 : 0.2}
        />
      </mesh>

      {/* Base 2 sphere */}
      <mesh position={[1, 0, 0]}>
        <sphereGeometry args={[0.4, 16, 16]} />
        <meshStandardMaterial
          color={color2}
          emissive={isSacred ? GOLDEN_GLOW : color2}
          emissiveIntensity={isSacred ? 0.5 : 0.2}
        />
      </mesh>

      {/* Hydrogen bond connector */}
      <mesh>
        <cylinderGeometry args={[0.05, 0.05, 2, 8]} />
        <meshStandardMaterial
          color="rgba(255, 255, 255, 0.3)"
          transparent
          opacity={0.4}
        />
      </mesh>
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKBONE STRAND COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

interface BackboneStrandProps {
  points: [number, number, number][];
  color: string;
}

function BackboneStrand({ points, color }: BackboneStrandProps) {
  const curve = useMemo(() => {
    return new THREE.CatmullRomCurve3(
      points.map(p => new THREE.Vector3(...p))
    );
  }, [points]);

  const tubeGeometry = useMemo(() => {
    return new THREE.TubeGeometry(curve, points.length, 0.15, 8, false);
  }, [curve, points.length]);

  return (
    <mesh geometry={tubeGeometry}>
      <meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.3} />
    </mesh>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DNA HELIX SCENE
// ═══════════════════════════════════════════════════════════════════════════════

interface DnaHelixSceneProps {
  sequence: string;
  showTime: boolean;
}

function DnaHelixScene({ sequence, showTime }: DnaHelixSceneProps) {
  const groupRef = useRef<THREE.Group>(null);

  // Generate helix geometry
  const { strand1, strand2, basePairs } = useMemo(() => {
    const seq = sequence.toUpperCase().replace(/[^ATGC]/g, '').substring(0, 34);
    const len = seq.length;

    const s1: [number, number, number][] = [];
    const s2: [number, number, number][] = [];
    const pairs: Array<{ pos: [number, number, number]; b1: string; b2: string; idx: number; sacred: boolean }> = [];

    const { helixRadius, twistPerBasePair, risePerBasePair } = DNA_HELIX;
    const twistRad = (twistPerBasePair * Math.PI) / 180;

    for (let i = 0; i < len; i++) {
      const base1 = seq[i];
      const base2 = base1 === 'A' ? 'T' : base1 === 'T' ? 'A' : base1 === 'G' ? 'C' : 'G';

      const y = i * risePerBasePair * 0.5; // Scale down for visualization
      const angle = i * twistRad;

      const x1 = helixRadius * 0.1 * Math.cos(angle);
      const z1 = helixRadius * 0.1 * Math.sin(angle);

      const x2 = helixRadius * 0.1 * Math.cos(angle + Math.PI);
      const z2 = helixRadius * 0.1 * Math.sin(angle + Math.PI);

      s1.push([x1, y, z1]);
      s2.push([x2, y, z2]);

      pairs.push({
        pos: [0, y, 0],
        b1: base1,
        b2: base2,
        idx: i,
        sacred: isFibonacciPosition(i),
      });
    }

    return { strand1: s1, strand2: s2, basePairs: pairs };
  }, [sequence]);

  // Animate rotation
  useFrame((state) => {
    if (groupRef.current) {
      groupRef.current.rotation.y = state.clock.elapsedTime * 0.2;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Ambient light */}
      <ambientLight intensity={0.5} />

      {/* Directional light */}
      <directionalLight position={[10, 10, 5]} intensity={1} />

      {/* Point light for sacred glow */}
      <pointLight position={[0, 5, 0]} intensity={0.5} color={GOLDEN_GLOW} />

      {/* Backbone strands */}
      <BackboneStrand points={strand1} color="#4488ff" />
      <BackboneStrand points={strand2} color="#4488ff" />

      {/* Base pairs */}
      {basePairs.map(({ pos, b1, b2, idx, sacred }) => (
        <BasePairMesh
          key={idx}
          position={pos}
          base1={b1}
          base2={b2}
          index={idx}
          isSacred={sacred}
        />
      ))}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN DNA HELIX COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

export default function DnaHelix3D({ sequence, showTime = false, height = 400 }: DnaHelix3DProps) {
  return (
    <div style={{ height, position: 'relative' }}>
      <Canvas
        camera={{ position: [15, 10, 15], fov: 50 }}
        style={{ background: 'linear-gradient(180deg, #0a0a1a 0%, #1a1a2e 100%)' }}
      >
        <DnaHelixScene sequence={sequence} showTime={showTime} />
        <OrbitControls
          enableDamping
          dampingFactor={0.05}
          autoRotate
          autoRotateSpeed={1}
        />
      </Canvas>

      {/* Legend */}
      <div
        style={{
          position: 'absolute',
          bottom: 10,
          left: 10,
          background: 'rgba(0, 0, 0, 0.7)',
          padding: '8px 12px',
          borderRadius: '8px',
          fontSize: '11px',
          fontFamily: 'JetBrains Mono, monospace',
          color: '#fff',
        }}
      >
        <div style={{ marginBottom: '4px', fontWeight: 'bold', color: GOLDEN_GLOW }}>
          DNA BASE PAIRS
        </div>
        <div><span style={{ color: BASE_COLORS.A }}>■</span> Adenine (A)</div>
        <div><span style={{ color: BASE_COLORS.T }}>■</span> Thymine (T)</div>
        <div><span style={{ color: BASE_COLORS.G }}>■</span> Guanine (G)</div>
        <div><span style={{ color: BASE_COLORS.C }}>■</span> Cytosine (C)</div>
        <div style={{ marginTop: '4px', fontSize: '9px', opacity: 0.7 }}>
          φ: {PHI.toFixed(5)} | Pitch: 34 Å
        </div>
      </div>

      {/* φ-Time indicator */}
      {showTime && (
        <div
          style={{
            position: 'absolute',
            top: 10,
            right: 10,
            background: 'rgba(0, 0, 0, 0.7)',
            padding: '8px 12px',
            borderRadius: '8px',
            fontSize: '11px',
            fontFamily: 'JetBrains Mono, monospace',
            color: '#fff',
          }}
        >
          <div style={{ color: GOLDEN_GLOW, fontWeight: 'bold' }}>φ-TIME KINETICS</div>
          <div style={{ fontSize: '9px', opacity: 0.7 }}>
            Unwinding + Synthesis
          </div>
        </div>
      )}
    </div>
  );
}
