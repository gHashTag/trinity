// ═══════════════════════════════════════════════════════════════════════════════
// SACRED NEUROSCIENCE v16.0 — 3D Brain Connectivity Visualization
// ═══════════════════════════════════════════════════════════════════════════════
//
// 3D brain with φ-optimized neural pathways
// Golden ratio connections between sacred regions
//
// ═══════════════════════════════════════════════════════════════════════════════

"use client";

import React, { useRef, useMemo, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';

const PHI = 1.6180339887498948482;
const GOLDEN_GLOW = '#ffd700';
const SACRED_PURPLE = '#9400d3';
const NEURAL_CYAN = '#00ccff';

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

interface BrainRegion {
  id: string;
  name: string;
  position: [number, number, number];
  size: number;
  phiIndex: number;
  color: string;
}

interface NeuralConnection {
  source: [number, number, number];
  target: [number, number, number];
  phiWeight: number;
  isActive: boolean;
}

interface BrainConnectivity3DProps {
  showLabels?: boolean;
  showConnections?: boolean;
  autoRotate?: boolean;
  highlightSacred?: boolean;
  consciousness?: number; // 0-100, affects visualization
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGIONS DATA (Simplified for 3D viz)
// ═══════════════════════════════════════════════════════════════════════════════

const BRAIN_REGIONS_3D: BrainRegion[] = [
  // Limbic system
  { id: 'hippocampus', name: 'Hippocampus', position: [-2, 1, 0], size: 0.6, phiIndex: 0.85, color: GOLDEN_GLOW },
  { id: 'amygdala', name: 'Amygdala', position: [-2.5, -0.5, 0], size: 0.4, phiIndex: 0.78, color: '#ff6b6b' },
  { id: 'thalamus', name: 'Thalamus', position: [0, 0.5, 0], size: 0.75, phiIndex: 0.81, color: '#a29bfe' },
  { id: 'hypothalamus', name: 'Hypothalamus', position: [-0.5, -1, 0], size: 0.3, phiIndex: 0.72, color: '#ff9f43' },

  // Prefrontal cortex
  { id: 'dlpfc', name: 'DLPFC', position: [0, 5, 2], size: 0.9, phiIndex: 0.88, color: NEURAL_CYAN },
  { id: 'vmpfc', name: 'VMPFC', position: [0, 4, 0], size: 0.7, phiIndex: 0.82, color: '#81ecec' },
  { id: 'acc', name: 'ACC', position: [0, 3.5, 0], size: 0.5, phiIndex: 0.79, color: '#74b9ff' },

  // Sensory cortex
  { id: 'v1', name: 'V1 (Visual)', position: [3, 2, -2], size: 0.8, phiIndex: 0.91, color: '#d63031' },
  { id: 'a1', name: 'A1 (Auditory)', position: [3.5, 1, 1], size: 0.65, phiIndex: 0.84, color: '#e17055' },
  { id: 's1', name: 'S1 (Somatosensory)', position: [2, 2, 3], size: 0.75, phiIndex: 0.83, color: '#00b894' },

  // Motor cortex
  { id: 'm1', name: 'M1 (Motor)', position: [1.5, 3, 3.5], size: 0.7, phiIndex: 0.86, color: '#fd79a8' },
  { id: 'pmc', name: 'PMC', position: [2, 3.5, 3], size: 0.6, phiIndex: 0.80, color: '#e84393' },
  { id: 'sma', name: 'SMA', position: [0.5, 4, 2], size: 0.55, phiIndex: 0.77, color: '#c8456f' },

  // Association cortex
  { id: 'pcc', name: 'PCC', position: [1, 1, -1], size: 0.7, phiIndex: 0.80, color: '#fab1a0' },
  { id: 'precuneus', name: 'Precuneus', position: [1.5, 2, -2], size: 0.75, phiIndex: 0.83, color: '#f39c12' },
  { id: 'angular_gyrus', name: 'Angular Gyrus', position: [3.5, 3.5, -1], size: 0.65, phiIndex: 0.87, color: '#0984e3' },

  // Cerebellum
  { id: 'cerebellum', name: 'Cerebellum', position: [0, -2, -3], size: 1.0, phiIndex: 0.89, color: '#a29bfe' },

  // Brainstem
  { id: 'brainstem', name: 'Brainstem', position: [-1, -3, 0], size: 0.5, phiIndex: 0.67, color: '#fdcb6e' },
];

// ═══════════════════════════════════════════════════════════════════════════════
// NEURAL CONNECTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const NEURAL_CONNECTIONS_3D: NeuralConnection[] = [
  { source: [-2, 1, 0], target: [0, 0.5, 0], phiWeight: 0.618, isActive: true }, // hippocampus → thalamus
  { source: [-2, 1, 0], target: [0, 5, 2], phiWeight: 0.382, isActive: true }, // hippocampus → dlpfc
  { source: [-2.5, -0.5, 0], target: [-0.5, -1, 0], phiWeight: 1.0, isActive: true }, // amygdala → hypothalamus
  { source: [-2.5, -0.5, 0], target: [0, 4, 0], phiWeight: 0.618, isActive: true }, // amygdala → vmpfc
  { source: [0, 0.5, 0], target: [3, 2, -2], phiWeight: 1.0, isActive: true }, // thalamus → v1
  { source: [0, 0.5, 0], target: [3.5, 1, 1], phiWeight: 0.854, isActive: true }, // thalamus → a1
  { source: [0, 0.5, 0], target: [2, 2, 3], phiWeight: 1.0, isActive: true }, // thalamus → s1
  { source: [0, 0.5, 0], target: [0, 5, 2], phiWeight: 0.618, isActive: true }, // thalamus → dlpfc
  { source: [0, 5, 2], target: [0, 3.5, 0], phiWeight: 0.618, isActive: true }, // dlpfc → acc
  { source: [0, 5, 2], target: [1.5, 3, 3.5], phiWeight: 0.382, isActive: true }, // dlpfc → m1
  { source: [0, 4, 0], target: [-2.5, -0.5, 0], phiWeight: 0.618, isActive: true }, // vmpfc → amygdala
  { source: [2, 3.5, 3], target: [1.5, 3, 3.5], phiWeight: 0.618, isActive: true }, // pmc → m1
  { source: [0.5, 4, 2], target: [1.5, 3, 3.5], phiWeight: 0.618, isActive: true }, // sma → m1
  { source: [1, 1, -1], target: [1.5, 2, -2], phiWeight: 1.0, isActive: true }, // pcc → precuneus
  { source: [1, 1, -1], target: [0, 4, 0], phiWeight: 0.618, isActive: true }, // pcc → vmpfc
  { source: [1.5, 2, -2], target: [-2, 1, 0], phiWeight: 0.236, isActive: true }, // precuneus → hippocampus
  { source: [0, -2, -3], target: [0, 0.5, 0], phiWeight: 0.618, isActive: true }, // cerebellum → thalamus
  { source: [0, -2, -3], target: [1.5, 3, 3.5], phiWeight: 0.27, isActive: true }, // cerebellum → m1
];

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGION COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

interface BrainRegionMeshProps {
  region: BrainRegion;
  isSelected: boolean;
  highlightSacred: boolean;
  consciousness: number;
}

function BrainRegionMesh({ region, isSelected, highlightSacred, consciousness }: BrainRegionMeshProps) {
  const meshRef = useRef<THREE.Mesh>(null);
  const glowRef = useRef<THREE.Mesh>(null);

  const isSacred = region.phiIndex > 0.8;
  const showHighlight = highlightSacred && isSacred;

  useFrame((state) => {
    if (meshRef.current) {
      // Gentle pulsing based on consciousness level
      const pulseSpeed = 0.5 + (consciousness / 100) * 1.5;
      const pulse = 1 + Math.sin(state.clock.elapsedTime * pulseSpeed + region.position[0]) * 0.05;
      meshRef.current.scale.setScalar(region.size * pulse);
    }
    if (glowRef.current && showHighlight) {
      // Faster pulsing for sacred regions
      const glowPulse = 1 + Math.sin(state.clock.elapsedTime * 2 + region.position[0]) * 0.15;
      glowRef.current.scale.setScalar(region.size * glowPulse * 1.2);
    }
  });

  return (
    <group position={region.position}>
      {/* Main sphere */}
      <mesh ref={meshRef}>
        <sphereGeometry args={[region.size, 32, 32]} />
        <meshStandardMaterial
          color={showHighlight ? GOLDEN_GLOW : region.color}
          emissive={showHighlight ? GOLDEN_GLOW : region.color}
          emissiveIntensity={isSelected ? 0.8 : isSacred ? 0.4 : 0.2}
          transparent
          opacity={0.8}
          metalness={0.3}
          roughness={0.7}
        />
      </mesh>

      {/* Sacred glow halo */}
      {showHighlight && (
        <mesh ref={glowRef}>
          <sphereGeometry args={[region.size * 1.05, 32, 32]} />
          <meshStandardMaterial
            color={GOLDEN_GLOW}
            emissive={GOLDEN_GLOW}
            emissiveIntensity={0.6}
            transparent
            opacity={0.3}
            side={THREE.BackSide}
          />
        </mesh>
      )}

      {/* Consciousness aura */}
      {consciousness > 70 && (
        <mesh>
          <sphereGeometry args={[region.size * 1.3, 32, 32]} />
          <meshStandardMaterial
            color={SACRED_PURPLE}
            emissive={SACRED_PURPLE}
            emissiveIntensity={0.3}
            transparent
            opacity={0.15}
            side={THREE.BackSide}
          />
        </mesh>
      )}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEURAL CONNECTION COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

interface NeuralConnectionLineProps {
  connection: NeuralConnection;
  consciousness: number;
}

function NeuralConnectionLine({ connection, consciousness }: NeuralConnectionLineProps) {
  const lineRef = useRef<THREE.Line>(null);
  const particlesRef = useRef<THREE.Points>(null);

  const points = useMemo(() => [
    new THREE.Vector3(...connection.source),
    new THREE.Vector3(...connection.target),
  ], [connection.source, connection.target]);

  const geometry = useMemo(() => {
    const geo = new THREE.BufferGeometry().setFromPoints(points);
    return geo;
  }, [points]);

  // Flowing particles along connection
  const particleCount = Math.floor(connection.phiWeight * 10);
  const particlePositions = useMemo(() => {
    const pos = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount; i++) {
      const t = i / particleCount;
      pos[i * 3] = connection.source[0] + (connection.target[0] - connection.source[0]) * t;
      pos[i * 3 + 1] = connection.source[1] + (connection.target[1] - connection.source[1]) * t;
      pos[i * 3 + 2] = connection.source[2] + (connection.target[2] - connection.source[2]) * t;
    }
    return pos;
  }, [connection.source, connection.target, particleCount]);

  useFrame((state) => {
    if (particlesRef.current) {
      // Animate particles flowing along connection
      const positions = particlesRef.current.geometry.attributes.position.array as Float32Array;
      const flowSpeed = 0.001 + (consciousness / 100) * 0.003;
      const offset = (state.clock.elapsedTime * flowSpeed) % 1;

      for (let i = 0; i < particleCount; i++) {
        const t = ((i / particleCount) + offset) % 1;
        positions[i * 3] = connection.source[0] + (connection.target[0] - connection.source[0]) * t;
        positions[i * 3 + 1] = connection.source[1] + (connection.target[1] - connection.source[1]) * t;
        positions[i * 3 + 2] = connection.source[2] + (connection.target[2] - connection.source[2]) * t;
      }
      particlesRef.current.geometry.attributes.position.needsUpdate = true;
    }
  });

  const isPhiOptimized = connection.phiWeight > 0.5;
  const color = isPhiOptimized ? GOLDEN_GLOW : NEURAL_CYAN;
  const opacity = connection.phiWeight * 0.6;

  return (
    <group>
      {/* Connection line */}
      <line ref={lineRef} geometry={geometry}>
        <lineBasicMaterial
          color={color}
          transparent
          opacity={opacity}
          linewidth={connection.phiWeight * 2}
        />
      </line>

      {/* Flowing particles */}
      {connection.isActive && (
        <points ref={particlesRef}>
          <bufferGeometry>
            <bufferAttribute
              attach="attributes-position"
              count={particleCount}
              array={particlePositions}
              itemSize={3}
            />
          </bufferGeometry>
          <pointsMaterial
            color={GOLDEN_GLOW}
            size={0.05}
            transparent
            opacity={0.8}
            sizeAttenuation
          />
        </points>
      )}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS METER COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

interface ConsciousnessMeterProps {
  level: number; // 0-100
}

function ConsciousnessMeter({ level }: ConsciousnessMeterProps) {
  const meshRef = useRef<THREE.Mesh>(null);

  useFrame((state) => {
    if (meshRef.current) {
      const rotation = state.clock.elapsedTime * 0.5;
      meshRef.current.rotation.y = rotation;
      meshRef.current.rotation.z = rotation * 0.5;
    }
  });

  // Color based on consciousness level
  let color = '#4a0080'; // Deep sleep
  if (level >= 10) color = '#0080ff'; // Dreaming
  if (level >= 30) color = '#00ff80'; // Relaxed
  if (level >= 50) color = '#80ff80'; // Alert
  if (level >= 70) color = '#ffd700'; // Peak
  if (level >= 85) color = '#ffffff'; // Unity

  const size = 2 + (level / 100) * 3;
  const emissiveIntensity = (level / 100) * 0.8;

  return (
    <mesh position={[0, 0, 0]} ref={meshRef}>
      <icosahedronGeometry args={[size, 1]} />
      <meshStandardMaterial
        color={color}
        emissive={color}
        emissiveIntensity={emissiveIntensity}
        transparent
        opacity={0.3}
        wireframe
      />
    </mesh>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN SCENE
// ═══════════════════════════════════════════════════════════════════════════════

interface BrainSceneProps {
  showLabels: boolean;
  showConnections: boolean;
  autoRotate: boolean;
  highlightSacred: boolean;
  consciousness: number;
}

function BrainScene({
  showLabels,
  showConnections,
  autoRotate,
  highlightSacred,
  consciousness,
}: BrainSceneProps) {
  const groupRef = useRef<THREE.Group>(null);
  const [selectedRegion, setSelectedRegion] = useState<string | null>(null);

  useFrame((state) => {
    if (groupRef.current && autoRotate) {
      groupRef.current.rotation.y = state.clock.elapsedTime * 0.1;
    }
  });

  return (
    <group ref={groupRef}>
      {/* Lighting */}
      <ambientLight intensity={0.4} />
      <pointLight position={[10, 10, 10]} intensity={1} color={GOLDEN_GLOW} />
      <pointLight position={[-10, -5, -5]} intensity={0.5} color={NEURAL_CYAN} />
      <pointLight position={[0, 0, 10]} intensity={0.3} color={SACRED_PURPLE} />

      {/* Consciousness meter (center) */}
      {consciousness > 0 && <ConsciousnessMeter level={consciousness} />}

      {/* Neural connections */}
      {showConnections && NEURAL_CONNECTIONS_3D.map((conn, idx) => (
        <NeuralConnectionLine
          key={`conn-${idx}`}
          connection={conn}
          consciousness={consciousness}
        />
      ))}

      {/* Brain regions */}
      {BRAIN_REGIONS_3D.map((region) => (
        <BrainRegionMesh
          key={region.id}
          region={region}
          isSelected={selectedRegion === region.id}
          highlightSacred={highlightSacred}
          consciousness={consciousness}
        />
      ))}
    </group>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

export default function BrainConnectivity3D({
  showLabels = true,
  showConnections = true,
  autoRotate = true,
  highlightSacred = true,
  consciousness = 50,
}: BrainConnectivity3DProps) {
  const [infoVisible, setInfoVisible] = useState(true);

  return (
    <div style={{ height: 500, position: 'relative', width: '100%' }}>
      <Canvas
        camera={{ position: [15, 10, 15], fov: 60 }}
        style={{
          background: 'radial-gradient(ellipse at center, #1a1a2e 0%, #0a0a15 100%)',
        }}
      >
        <BrainScene
          showLabels={showLabels}
          showConnections={showConnections}
          autoRotate={autoRotate}
          highlightSacred={highlightSacred}
          consciousness={consciousness}
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
            BRAIN CONNECTIVITY v16.0
          </div>
          <div>φ = {PHI.toFixed(5)}</div>
          <div>Ψ = {consciousness.toFixed(1)}</div>
          <div style={{ marginTop: '8px', fontSize: '10px', opacity: 0.8 }}>
            Sacred regions (φ-index &gt; 0.8) glow golden
          </div>
          <div style={{ marginTop: '4px', fontSize: '10px', opacity: 0.8 }}>
            φ-optimized pathways shown with flowing particles
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

      {/* Consciousness indicator */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          left: 10,
          background: 'rgba(0, 0, 0, 0.6)',
          padding: '6px 10px',
          borderRadius: '6px',
          fontSize: '11px',
          color: consciousness > 80 ? GOLDEN_GLOW : '#fff',
        }}
      >
        Ψ = {consciousness.toFixed(1)} {consciousness > 80 && '✨'}
      </div>
    </div>
  );
}
