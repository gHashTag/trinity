import { useEffect, useRef, memo } from 'react'

// A star field that owes its arrangement to the same number the formats do.
//
// Positions come from the Vogel spiral: the i-th star sits at angle i·137.5077°
// and radius √(i/N). That angle is the circle divided by φ², and it is the one
// angle that never lets the stars fall into spokes — a sunflower packs its seeds
// this way for the same reason. So the background is not decoration borrowed
// from somewhere: it is φ doing the only thing φ does on this site, which is
// choose a division that leaves no gap and no collision.
//
// Depth is quantised in powers of φ. A star's parallax weight is φ^-(1+2d), its
// twinkle period is a φ multiple of its neighbour's, and the cursor's reach is
// 233px with a 1/φ falloff — Fibonacci because the sequence and the ratio are
// the same statement.

const PHI = 1.618033988749895
const GOLDEN_ANGLE = Math.PI * 2 / (PHI * PHI) // 137.5077°, the circle over φ²
const CURSOR_REACH = 233 // Fibonacci
const LINK_DIST = 144 // Fibonacci

interface Star {
  bx: number      // base position, the spiral seat it returns to
  by: number
  x: number       // drawn position, displaced by the cursor
  y: number
  depth: number   // 0 near, 1 far
  weight: number  // parallax weight, φ^-(1+2·depth)
  radius: number
  base: number    // base alpha
  period: number  // twinkle period in ms
  phase: number
}

export default memo(function PhiStarfield() {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const reduced = typeof window.matchMedia === 'function'
      && window.matchMedia('(prefers-reduced-motion: reduce)').matches

    let w = 0, h = 0, dpr = 1
    let stars: Star[] = []
    let mx = -9999, my = -9999
    let raf = 0
    let running = true

    const build = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2)
      w = window.innerWidth
      h = window.innerHeight
      canvas.width = Math.floor(w * dpr)
      canvas.height = Math.floor(h * dpr)
      canvas.style.width = w + 'px'
      canvas.style.height = h + 'px'
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

      // Fibonacci counts, and fewer on a phone: this runs behind everything and
      // must never be the reason a scroll stutters.
      const count = w < 768 ? 89 : w < 1200 ? 144 : 233
      const cx = w / 2
      const cy = h / 2
      // The spiral is grown past the viewport corner so the field reaches the
      // edges instead of vignetting into a visible disc.
      const maxR = Math.hypot(w, h) * 0.62

      stars = []
      for (let i = 0; i < count; i++) {
        const t = (i + 0.5) / count
        const r = Math.sqrt(t) * maxR
        const a = i * GOLDEN_ANGLE
        const depth = t
        stars.push({
          bx: cx + Math.cos(a) * r,
          by: cy + Math.sin(a) * r * 0.92, // a touch flatter than the viewport
          x: cx + Math.cos(a) * r,
          y: cy + Math.sin(a) * r * 0.92,
          depth,
          weight: Math.pow(PHI, -(1 + 2 * depth)),
          radius: 0.5 + (1 - depth) * 1.5,
          base: 0.28 + (1 - depth) * 0.5,
          period: 2600 * Math.pow(PHI, (i % 5) - 2),
          phase: (i * GOLDEN_ANGLE) % (Math.PI * 2),
        })
      }
    }

    const frame = (now: number) => {
      ctx.clearRect(0, 0, w, h)

      const cxv = w / 2
      const cyv = h / 2
      const hasCursor = mx > -9000
      // Parallax: the whole field leans against the cursor, near stars more than
      // far ones, which is what makes a flat canvas read as depth.
      const px = hasCursor ? (mx - cxv) / cxv : 0
      const py = hasCursor ? (my - cyv) / cyv : 0

      for (const s of stars) {
        const ox = -px * s.weight * 26
        const oy = -py * s.weight * 26
        let tx = s.bx + ox
        let ty = s.by + oy
        let lift = 0

        if (hasCursor) {
          const dx = tx - mx
          const dy = ty - my
          const d = Math.hypot(dx, dy)
          if (d < CURSOR_REACH && d > 0.01) {
            // 1/φ falloff, so the push is firm near the pointer and gone by the
            // edge of its reach rather than stopping abruptly.
            const f = Math.pow(1 - d / CURSOR_REACH, PHI)
            lift = f
            tx += (dx / d) * f * 34
            ty += (dy / d) * f * 34
          }
        }

        // Ease toward the target instead of snapping: 1/φ² per frame reads as
        // weight without a spring library.
        s.x += (tx - s.x) * 0.38
        s.y += (ty - s.y) * 0.38

        const tw = reduced ? 1 : 0.62 + 0.38 * Math.sin(now / s.period + s.phase)
        const alpha = Math.min(1, s.base * tw + lift * 0.72)
        const rad = s.radius * (1 + lift * 0.7)

        ctx.beginPath()
        ctx.arc(s.x, s.y, rad, 0, Math.PI * 2)
        ctx.fillStyle = lift > 0.02
          // Under the pointer a star warms to the accent; elsewhere it stays
          // white, so the colour marks where the reader is and nothing else.
          ? `rgba(${Math.round(255 - lift * 255)}, 255, ${Math.round(255 - lift * 119)}, ${alpha})`
          : `rgba(255, 255, 255, ${alpha})`
        ctx.fill()
      }

      // Links only among the near half: drawing all pairs is both slow and
      // busy, and the far stars should stay dust.
      const near = stars.filter((s) => s.depth < 0.5)
      for (let i = 0; i < near.length; i++) {
        for (let j = i + 1; j < near.length; j++) {
          const a = near[i], b = near[j]
          const d = Math.hypot(a.x - b.x, a.y - b.y)
          if (d < LINK_DIST) {
            ctx.beginPath()
            ctx.moveTo(a.x, a.y)
            ctx.lineTo(b.x, b.y)
            ctx.strokeStyle = `rgba(255, 255, 255, ${(1 - d / LINK_DIST) / (PHI * 5)})`
            ctx.lineWidth = 0.6
            ctx.stroke()
          }
        }
      }

      if (running && !reduced) raf = requestAnimationFrame(frame)
    }

    const onMove = (e: MouseEvent) => { mx = e.clientX; my = e.clientY }
    const onLeave = () => { mx = -9999; my = -9999 }
    const onTouch = (e: TouchEvent) => {
      const t = e.touches[0]
      if (t) { mx = t.clientX; my = t.clientY }
    }
    const onResize = () => { build() }
    const onVisibility = () => {
      running = !document.hidden
      if (running && !reduced) raf = requestAnimationFrame(frame)
      else cancelAnimationFrame(raf)
    }

    build()
    raf = requestAnimationFrame(frame)
    window.addEventListener('mousemove', onMove, { passive: true })
    window.addEventListener('mouseout', onLeave)
    window.addEventListener('touchmove', onTouch, { passive: true })
    window.addEventListener('resize', onResize)
    document.addEventListener('visibilitychange', onVisibility)

    return () => {
      running = false
      cancelAnimationFrame(raf)
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseout', onLeave)
      window.removeEventListener('touchmove', onTouch)
      window.removeEventListener('resize', onResize)
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [])

  return (
    <div className="phi-starfield" aria-hidden="true">
      <canvas ref={canvasRef} />
    </div>
  )
})
