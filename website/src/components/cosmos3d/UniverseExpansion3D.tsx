// ═══════════════════════════════════════════════════════════════════════════════
// SACRED COSMOLOGY v15.0 — 3D Universe Expansion Visualization
// ═══════════════════════════════════════════════════════════════════════════════
//
// 3D expanding universe with golden spiral timeline
// Sacred epochs glow golden at Fibonacci time points
//
// ═══════════════════════════════════════════════════════════════════════════════

"use client";

import React, { useRef, useMemo, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';

const PHI = 1.6180339887498948482;
const GOLDEN_GLOW = '#ffd700';
const DARK_ENERGY_COLOR = '#9400d3';
const MATTER_COLOR = '#4169e1';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

interface UniverseExpansion3DProps {
  showTimeline?: boolean;
  showGoldenSpiral?: boolean;
  showDarkEnergy?: boolean;
  epochs?: number;
  autoRotate?: boolean;
}

interface CosmicEpochProps {
  time: number;
  scale: number;
  isSacred: boolean;
  opacity: number;
}

interface SpiralPoint {
  x: number;
  y: number;
  z: number;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COSMIC EPOCH COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

function CosmicEpoch({ time, scale, isSacred, opacity }: CosmicEpochProps) {
  const meshRef = useRef<THREE.Mesh>(null);
  const glowRef = useRef<THREE.Mesh>(null);

  useFrame((state) => {
    if (meshRef.current) {
      // Gentle pulsing animation
      const pulse = 1 + Math.sin(state.clock.elapsedTime * 0.5 + time) * 0.05;
      meshRef.current.scale.setScalar(scale * pulse);
    }
    if (glowRef.current && isSacred) {
      // Faster pulsing for sacred epochs
      const glowPulse = 1 + Math.sin(state.clock.elapsedTime * 2 + time) * 0.1;
      glowRef.current.scale.setScalar(scale * glowPulse * 1.05);
    }
  });

  const color = isSacred ? GOLDEN_GLOW : MATTER_COLOR;
  const emissive = isSacred ? GOLDEN_GLOW : DARK_ENERGY_COLOR;

  return (
    <group>
      {/* Main sphere */}
      <mesh ref={meshRef}>
        <sphereGeometry args={[scale, 32, 32]} />
        <meshStandardMaterial
          color={color}
          emissive={emissive}
          emissiveIntensity={isSacred ? 0.5 : 0.2}
          transparent
          opacity={opacity}
        />
      </mesh>

      {/* Sacred glow halo */}
      {isSacred && (
        <mesh ref={glowRef}>
          <sphereGeometry args={[scale * 1.02, 32, 32]} />
          <meshStandardMaterial
            color={GOLDEN_GLOW}
            emissive={GOLDEN_GLOW}
            emissiveIntensity={0.8}
            transparent
            opacity={0.2}
            side={THREE.BackSide}
          />
        </mesh>
      )}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN SPIRAL TIMELINE
// ═══════════════════════════════════════════════════════════════════════════════

interface GoldenSpiralTimelineProps {
  showPoints?: boolean;
  count?: number;
}

function GoldenSpiralTimeline({ showPoints = false, count = 100 }: GoldenSpiralTimelineProps) {
  const points = useMemo(() => {
    const spiralPoints: SpiralPoint[] = [];
    const turns = 2;
    const maxRadius = 8;

    for (let i = 0; i < count; i++) {
      const t = i / count;
      const angle = t * turns * Math.PI * 2;
      const growth = Math.pow(PHI, t);
      const radius = maxRadius * t * growth;

      spiralPoints.push({
        x: radius * Math.cos(angle),
        y: radius * Math.sin(angle),
        z: t * 10, // Rise along z-axis (time)
      });
    }
    return spiralPoints;
  }, [count]);

  const lineGeometry = useMemo(() => {
    const points3D = points.map(p => new THREE.Vector3(p.x, p.y, p.z));
    return new THREE.BufferGeometry().setFromPoints(points3D);
  }, [points]);

  return (
    <group>
      {/* Spiral curve */}
      <line geometry={lineGeometry}>
        <lineBasicMaterial color={GOLDEN_GLOW} opacity={0.6} transparent />
      </line>

      {/* Sacred epoch points on spiral */}
      {showPoints && points.filter((_, i) => [1, 2, 3, 5, 8, 13, 21].includes(i)).map((p, i) => (
        <mesh key={i} position={[p.x, p.y, p.z]}>
          <sphereGeometry args={[0.15, 8, 8]} />
          <meshStandardMaterial
            color={GOLDEN_GLOW}
            emissive={GOLDEN_GLOW}
            emissiveIntensity={1}
          />
        </mesh>
      ))}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// GALAXY PARTICLES
// ═══════════════════════════════════════════════════════════════════════════════

interface GalaxyParticlesProps {
  count: number;
  radius: number;
}

function GalaxyParticles({ count, radius }: GalaxyParticlesProps) {
  const particlesRef = useRef<THREE.Points>(null);

  const positions = useMemo(() => {
    const pos = new Float32Array(count * 3);
    const fib = [1, 2, 3, 5, 8, 13, 21, 34];

    for (let i = 0; i < count; i++) {
      // Random position within sphere
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(2 * Math.random() - 1);
      const r = Math.pow(Math.random(), 1/3) * radius;

      pos[i * 3] = r * Math.sin(phi) * Math.cos(theta);
      pos[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta);
      pos[i * 3 + 2] = r * Math.cos(phi);
    }
    return pos;
  }, [count, radius]);

  useFrame((state) => {
    if (particlesRef.current) {
      particlesRef.current.rotation.y = state.clock.elapsedTime * 0.05;
    }
  });

  return (
    <points ref={particlesRef}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          count={positions.length / 3}
          array={positions}
          itemSize={3}
        />
      </bufferGeometry>
      <pointsMaterial
        color={GOLDEN_GLOW}
        size={0.05}
        transparent
        opacity={0.6}
      />
    </points>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPANSION SCENE
// ═══════════════════════════════════════════════════════════════════════════════

interface ExpansionSceneProps {
  epochs: number;
  showTimeline: boolean;
  showGoldenSpiral: boolean;
  showDarkEnergy: boolean;
  autoRotate: boolean;
}

function ExpansionScene({
  epochs,
  showTimeline,
  showGoldenSpiral,
  showDarkEnergy,
  autoRotate,
}: ExpansionSceneProps) {
  const groupRef = useRef<THREE.Group>(null);

  // Sacred epochs (Fibonacci in Gyr)
  const sacredEpochs = useMemo(() => [1, 2, 3, 5, 8, 13], []);

  // Generate epoch data
  const epochData = useMemo(() => {
    const data: CosmicEpochProps[] = [];
    const maxEpoch = 13.82; // Current universe age

    for (let i = 0; i < epochs; i++) {
      const t = (i / epochs) * maxEpoch;
      const scale = Math.pow(PHI, i / epochs) * 3;
      const isSacred = sacredEpochs.some(e => Math.abs(t - e) < 0.25);
      const opacity = 0.1 + (i / epochs) * 0.2;

      data.push({ time: t, scale, isSacred, opacity });
    }
    return data;
  }, [epochs, sacredEpochs]);

  useFrame((state) => {
    if (groupRef.current) {
      groupRef.current.rotation.y = state.clock.elapsedTime * 0.05;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Lighting */}
      <ambientLight intensity={0.3} />
      <pointLight position={[10, 10, 10]} intensity={1} color={GOLDEN_GLOW} />
      <pointLight position={[-10, -5, -5]} intensity={0.5} color={MATTER_COLOR} />

      {/* Dark energy field (outer glow) */}
      {showDarkEnergy && (
        <mesh>
          <sphereGeometry args={[12, 32, 32]} />
          <meshStandardMaterial
            color={DARK_ENERGY_COLOR}
            emissive={DARK_ENERGY_COLOR}
            emissiveIntensity={0.3}
            transparent
            opacity={0.1}
            side={THREE.BackSide}
          />
        </mesh>
      )}

      {/* Universe epochs (expanding spheres) */}
      {epochData.map((epoch, idx) => (
        <CosmicEpoch key={idx} {...epoch} />
      ))}

      {/* Galaxy particles */}
      <GalaxyParticles count={500} radius={10} />

      {/* Golden spiral timeline */}
      {showGoldenSpiral && <GoldenSpiralTimeline showPoints />}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

export default function UniverseExpansion3D({
  showTimeline = true,
  showGoldenSpiral = true,
  showDarkEnergy = true,
  epochs = 15,
  autoRotate = true,
}: UniverseExpansion3DProps) {
  const [infoVisible, setInfoVisible] = useState(true);

  return (
    <div style={{ height: 500, position: 'relative', width: '100%' }}>
      <Canvas
        camera={{ position: [20, 15, 20], fov: 60 }}
        style={{
          background: 'radial-gradient(ellipse at center, #1a1a2e 0%, #0a0a15 100%)',
        }}
      >
        <ExpansionScene
          epochs={epochs}
          showTimeline={showTimeline}
          showGoldenSpiral={showGoldenSpiral}
          showDarkEnergy={showDarkEnergy}
          autoRotate={autoRotate}
        />
        <OrbitControls
          enableDamping
          dampingFactor={0.05}
          autoRotate={autoRotate}
          autoRotateSpeed={0.5}
        />
      </Canvas>

      {/* Info panel */}
      {infoVisible && (
        <div
          style={{
            position: 'absolute',
            bottom: 10,
            left: 10,
            background: 'rgba(0, 0, 0, 0.8)',
            padding: '12px 16px',
            borderRadius: '12px',
            fontFamily: 'JetBrains Mono, monospace',
            color: '#fff',
            fontSize: '11px',
            border: '1px solid rgba(255, 215, 0, 0.3)',
            backdropFilter: 'blur(4px)',
          }}
        >
          <div style={{ color: GOLDEN_GLOW, fontWeight: 'bold', marginBottom: '8px', fontSize: '13px' }}>
            UNIVERSE EXPANSION v15.0
          </div>
          <div>φ = {PHI.toFixed(5)}</div>
          <div>Age: 13.82 Gyr = π×φ×e</div>
          <div style={{ marginTop: '8px', fontSize: '10px', opacity: 0.8 }}>
            Golden epochs: 1, 2, 3, 5, 8, 13 Gyr
          </div>
          <div style={{ marginTop: '4px', fontSize: '10px', opacity: 0.8 }}>
            Ω_Λ = {((Math.PI - 1) / Math.PI).toFixed(3)} = φ - 1/φ²
          </div>
          <button
            onClick={() => setInfoVisible(false)}
            style={{
              position: 'absolute',
              top: 4,
              right: 4,
              background: 'none',
              border: 'none',
              color: '#fff',
              cursor: 'pointer',
              fontSize: '14px',
            }}
          >
            ×
          </button>
        </div>
      )}

      {/* Info toggle when hidden */}
      {!infoVisible && (
        <button
          onClick={() => setInfoVisible(true)}
          style={{
            position: 'absolute',
            bottom: 10,
            left: 10,
            background: 'rgba(0, 0, 0, 0.6)',
            border: '1px solid rgba(255, 215, 0, 0.3)',
            color: GOLDEN_GLOW,
            padding: '8px 12px',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '12px',
          }}
        >
          Info
        </button>
      )}

      {/* Controls hint */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          right: 10,
          background: 'rgba(0, 0, 0, 0.6)',
          padding: '6px 10px',
          borderRadius: '6px',
          fontSize: '10px',
          color: '#fff',
          opacity: 0.6,
        }}
      >
        Drag to rotate • Scroll to zoom
      </div>
    </div>
  );
}
