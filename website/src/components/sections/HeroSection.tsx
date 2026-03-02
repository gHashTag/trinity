"use client";
import { useState, useCallback, useRef } from 'react';
import { motion } from 'framer-motion';
import { useI18n } from '../../i18n/context';

// 27 triangle petal paths from trinity-logo-with-label.svg (lines 2-28)
const SYMBOL_PATHS = [
  "M543.609 639.667L490.537 546.456L468.444 585.304L543.609 717.477V639.667Z",
  "M489.786 545.199L438.209 453.966H393.861L467.788 584.09L489.786 545.199Z",
  "M384.525 360.512L436.994 452.791L393.091 452.811L319.18 322.035L384.525 360.512Z",
  "M319.922 320.841L385.231 358.858H489.638L468.408 320.815L319.922 320.841Z",
  "M469.854 320.81L491.695 358.618L596.337 358.912L618.433 320.801L469.854 320.81Z",
  "M703.129 359.011L598.207 358.965L619.983 321.06L767.697 321.125L703.129 359.011Z",
  "M702.54 360.827L650.501 452.677L695.338 452.697L769.614 321.531L702.54 360.827Z",
  "M598.155 544.433L620.701 584.062L694.724 453.922L649.575 453.972L598.155 544.433Z",
  "M544.819 639.162L597.407 545.611L619.959 585.522L544.819 717.812V639.162Z",
  "M543.946 567.149L511.486 510.031L491.755 544.962L543.946 636.825V567.149Z",
  "M510.857 508.805L479.79 454.184H440.322L490.965 543.644L510.857 508.805Z",
  "M479.052 452.892L447.096 396.758L387.857 362.23L439.599 453.267L479.052 452.892Z",
  "M389.427 361.072L447.673 395.597L511.235 395.595L491.23 360.678L389.427 361.072Z",
  "M512.836 395.557L576.043 395.537L595.834 360.751H492.923L512.836 395.557Z",
  "M577.573 395.548L641.433 395.482L700.284 360.835H597.379L577.573 395.548Z",
  "M641.979 396.644L609.958 452.951L649.135 452.858L700.736 362.59L641.979 396.644Z",
  "M578.24 508.803L597.734 543.266L648.408 454.174L609.263 454.131L578.24 508.803Z",
  "M545.483 567.025L577.45 510.047L597.043 544.548L545.483 635.215V567.025Z",
  "M543.157 496.408L530.886 474.893L511.632 508.976L543.157 564.23V496.408Z",
  "M510.799 507.831L530.268 473.478L519.428 454.358L480.586 454.341L510.799 507.831Z",
  "M506.749 432.127L518.606 453.09L479.871 453.107L448.64 398.108L506.749 432.127Z",
  "M507.208 431.026L530.649 431.016L511.365 397.077L449.27 397.105L507.208 431.026Z",
  "M512.645 397.101L531.982 430.989H555.007L574.428 397.101H512.645Z",
  "M580.435 431.079L556.539 431.069L575.922 397.106L638.353 397.134L580.435 431.079Z",
  "M580.705 432.287L568.987 453.102L607.741 453.119L638.937 398.141L580.705 432.287Z",
  "M576.766 507.787L557.383 473.503L568.216 454.334L607.09 454.317L576.766 507.787Z",
  "M544.716 496.337L556.648 474.865L575.81 509.007L544.716 564.007V496.337Z",
];

// "TRINITY" text path from trinity-logo-with-label.svg (line 29)
const TEXT_PATH = "M198 917V776.2H233.8V917H198ZM154.6 806V775.2H277.2V806H154.6ZM321.883 859.6V834H348.883C354.749 834 359.216 832.6 362.283 829.8C365.483 826.867 367.083 822.933 367.083 818C367.083 813.2 365.483 809.333 362.283 806.4C359.216 803.333 354.749 801.8 348.883 801.8H321.883V775.2H353.883C363.483 775.2 371.883 777 379.083 780.6C386.416 784.2 392.149 789.133 396.283 795.4C400.416 801.667 402.483 809 402.483 817.4C402.483 825.8 400.349 833.2 396.083 839.6C391.949 845.867 386.149 850.8 378.683 854.4C371.216 857.867 362.483 859.6 352.483 859.6H321.883ZM293.483 917V775.2H329.283V917H293.483ZM370.283 917L329.083 856.2L361.283 848.4L411.683 917H370.283ZM423.366 917V775.2H459.166V917H423.366ZM484.303 917V775.2H509.303L520.103 804.2V917H484.303ZM582.103 917L499.303 811.8L509.303 775.2L592.303 880.4L582.103 917ZM582.103 917L572.903 887.2V775.2H608.703V917H582.103ZM633.913 917V775.2H669.713V917H633.913ZM729.25 917V776.2H765.05V917H729.25ZM685.85 806V775.2H808.45V806H685.85ZM862.078 866.2L807.878 775.2H848.878L890.278 849H861.478L902.878 775.2H943.078L888.478 866.2H862.078ZM857.878 917V851.6H893.678V917H857.878Z";

// Pre-computed centroids for each petal (in SVG viewBox coords)
const PETAL_CENTERS: [number, number][] = [
  [518.0, 625.7], [455.9, 516.5], [383.7, 389.7], [396.6, 336.0],
  [529.2, 336.0], [678.4, 343.8], [704.1, 389.7], [632.3, 516.2],
  [570.4, 625.5], [527.0, 565.2], [486.6, 493.9], [446.5, 423.6],
  [445.8, 374.8], [538.1, 381.6], [618.8, 381.6], [648.8, 412.3],
  [602.4, 493.8], [562.2, 564.8], [534.4, 508.2], [510.4, 479.6],
  [492.1, 433.7], [501.1, 417.4], [537.3, 410.7], [586.3, 417.5],
  [595.4, 433.8], [577.2, 479.5], [553.3, 508.1],
];

const MAX_DIST = 180; // influence radius in SVG units
const SPRING = { type: 'spring' as const, stiffness: 200, damping: 15, mass: 0.5 };

// Individual metallic petal — reacts to cursor proximity via animate prop
function MetallicPetal({ d, cx, cy, cursorX, cursorY }: {
  d: string; cx: number; cy: number; cursorX: number; cursorY: number;
}) {
  const dist = Math.sqrt((cx - cursorX) ** 2 + (cy - cursorY) ** 2);
  const proximity = Math.max(0, 1 - dist / MAX_DIST);

  const sc = 1 + proximity * 0.15;
  const ty = -proximity * 8;

  return (
    <motion.path
      fillRule="evenodd"
      clipRule="evenodd"
      d={d}
      fill="white"
      stroke="black"
      strokeWidth="1"
      animate={{
        scale: sc,
        y: ty,
        filter: `brightness(${1 + proximity * 0.7}) drop-shadow(0 ${proximity * 4}px ${proximity * 6}px rgba(255,255,255,${proximity * 0.3}))`,
      }}
      transition={SPRING}
      style={{ transformOrigin: `${cx}px ${cy}px` }}
    />
  );
}

// Full logo with per-petal physics — original viewBox & size preserved
function MetallicLogo() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [cursor, setCursor] = useState<{ x: number; y: number } | null>(null);

  const handleMouseMove = useCallback((e: React.MouseEvent<SVGSVGElement>) => {
    const svg = svgRef.current;
    if (!svg) return;
    const rect = svg.getBoundingClientRect();
    // Map pixel → SVG viewBox coords (viewBox="100 280 880 680")
    const vbX = 100 + (e.clientX - rect.left) / rect.width * 880;
    const vbY = 280 + (e.clientY - rect.top) / rect.height * 680;
    setCursor({ x: vbX, y: vbY });
  }, []);

  const handleMouseLeave = useCallback(() => setCursor(null), []);

  const cx = cursor?.x ?? 540;
  const cy = cursor?.y ?? -9999; // far away = no effect

  return (
    <svg
      ref={svgRef}
      viewBox="100 280 880 680"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="TRINITY - Native Ternary Hardware"
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      style={{
        height: 'clamp(100px, 21vw, 269px)',
        width: 'auto',
        filter: 'brightness(1.2)',
        cursor: 'pointer',
      }}
    >
      {/* Triangle petals — each reacts independently */}
      {SYMBOL_PATHS.map((d, i) => (
        <MetallicPetal
          key={i}
          d={d}
          cx={PETAL_CENTERS[i][0]}
          cy={PETAL_CENTERS[i][1]}
          cursorX={cx}
          cursorY={cy}
        />
      ))}
      {/* TRINITY text — static, no physics */}
      <path d={TEXT_PATH} fill="white" />
    </svg>
  );
}

// Animated equation component - LaTeX-style math
function AnimatedEquation() {
  return (
    <motion.div
      className="fade"
      style={{
        fontSize: 'clamp(1.1rem, 4.2vw, 2rem)',
        marginBottom: '1.5rem',
        fontFamily: '"Times New Roman", Times, serif',
        fontStyle: 'italic',
        color: '#00ff88',
        position: 'relative',
        display: 'inline-block'
      }}
    >
      <motion.span
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5, duration: 0.8 }}
      >
        <span style={{ fontFamily: 'inherit' }}>φ</span>
        <sup>2</sup>
        <span style={{ margin: '0 0.1em' }}> + </span>
        <span style={{ fontFamily: 'inherit' }}>1/φ</span>
        <sup>2</sup>
        <span style={{ margin: '0 0.1em' }}> = </span>
        <span style={{ fontWeight: 500 }}>3</span>
      </motion.span>
    </motion.div>
  );
}

export default function HeroSection() {
  const { t: { hero: t } } = useI18n(); 
  
  return (
    <section id="hero">
      <div className="radial-glow" />
      
      <motion.div 
        className="fade" 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        style={{ color: 'var(--accent)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: 'clamp(0.1em, 2vw, 0.3em)', marginBottom: '0' }}
      >
        {t.tag}
      </motion.div>
      
      <motion.div
        className="fade"
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.8, delay: 0.2 }}
        style={{ marginBottom: '0', display: 'flex', justifyContent: 'center' }}
      >
        <MetallicLogo />
      </motion.div>
      
      <AnimatedEquation />
      
      {/* Only show headline if it's not the φ equation (already shown above) */}
      {t.headline && !t.headline.includes('φ²') && (
        <motion.h2 
          className="fade" 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 1.8 }}
          style={{ fontSize: 'clamp(1.8rem, 6vw, 2.8rem)', marginBottom: '1.2rem', letterSpacing: '-0.03em' }} 
          dangerouslySetInnerHTML={{ __html: t.headline }} 
        />
      )}
      
      <motion.p 
        className="fade" 
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.7 }}
        transition={{ duration: 0.6, delay: 2.0 }}
        style={{ fontSize: 'clamp(1rem, 2.5vw, 1.15rem)', marginBottom: '3rem', maxWidth: '800px' }}
      >
        {t.quote}
      </motion.p>
      
      <motion.div 
        className="fade" 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 2.2 }}
        style={{ display: 'flex', gap: '1rem', marginTop: '2.5rem', justifyContent: 'center', flexWrap: 'wrap' }}
      >
        <motion.a 
          href="#theorems" 
          className="btn" 
          style={{ minWidth: 'clamp(140px, 40vw, 200px)' }}
          whileHover={{ scale: 1.05, boxShadow: '0 0 20px rgba(218,165,32,0.3)' }}
          whileTap={{ scale: 0.95 }}
        >
          {t.cta}
        </motion.a>
        <motion.a 
          href="#calculator" 
          className="btn secondary"
          style={{ minWidth: 'clamp(140px, 40vw, 200px)' }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
        >
          {t.ctaSecondary}
        </motion.a>
      </motion.div>
      
      {/* Scroll indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.4, y: [0, 10, 0] }}
        transition={{ opacity: { delay: 3 }, y: { duration: 2, repeat: Infinity } }}
        style={{ 
          position: 'absolute', 
          bottom: '2rem', 
          left: '50%', 
          transform: 'translateX(-50%)',
          fontSize: '1.5rem'
        }}
      >
        ↓
      </motion.div>
    </section>
  )
}