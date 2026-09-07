import { useEffect, useRef, useState } from 'react';
import { projectCatalogStar, catalogStarRows, type CatalogStar } from './queenStarProjection';
import catalogUrl from '../data/hyg-v41-bright.json?url';

export function QueenStarfield({lang}:{lang:'ru'|'en'}) {
  const ref=useRef<HTMLCanvasElement>(null);
  const [count,setCount]=useState<number|null>(null);
  const [failed,setFailed]=useState(false);
  useEffect(()=>{
    const canvas=ref.current,host=canvas?.parentElement,ctx=canvas?.getContext('2d');
    if(!canvas || !host || !ctx) return;
    let stars:readonly CatalogStar[]=[],disposed=false,frame=0,px=0,py=0;
    const request=new AbortController();
    const motion=matchMedia('(prefers-reduced-motion: reduce)');
    const draw=()=>{
      frame=0; if(disposed) return;
      const w=host.clientWidth,h=host.clientHeight,dpr=Math.min(2,devicePixelRatio||1);
      const width=Math.round(w*dpr),height=Math.round(h*dpr);
      if(canvas.width!==width) canvas.width=width;
      if(canvas.height!==height) canvas.height=height;
      ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,w,h);
      const view={yaw:Math.PI/2+(motion.matches?0:px*.018),pitch:-.12+(motion.matches?0:py*.012),offset:motion.matches?0:px*.08};
      let visible=0;
      for(const star of stars) {
        const p=projectCatalogStar(star,w,h,view); if(!p || p.x<0 || p.y<0 || p.x>w || p.y>h) continue;
        visible++;
        const mag=star[6],ci=star[7];
        const color=ci!==null && ci<.2?'172,205,255':ci!==null && ci>.9?'255,218,173':'226,238,255';
        const radius=Math.max(.45,1.8-(mag+1.5)*.18),alpha=Math.min(.92,Math.max(.2,1.05-(mag+1.5)*.1));
        if(mag<2.5) {const glow=ctx.createRadialGradient(p.x,p.y,0,p.x,p.y,radius*6);glow.addColorStop(0,`rgba(${color},.28)`);glow.addColorStop(1,`rgba(${color},0)`);ctx.fillStyle=glow;ctx.fillRect(p.x-radius*6,p.y-radius*6,radius*12,radius*12);}
        ctx.fillStyle=`rgba(${color},${alpha})`;ctx.beginPath();ctx.arc(p.x,p.y,radius,0,Math.PI*2);ctx.fill();
      }
      canvas.dataset.visibleStars=String(visible);canvas.dataset.catalogStars=String(stars.length);
    };
    // Data/size changes need one real paint even in a background tab. Only
    // pointer parallax uses RAF; no continuous idle or hidden-tab animation.
    const redraw=()=>{cancelAnimationFrame(frame);draw();};
    const schedule=()=>{if(!frame && !document.hidden) frame=requestAnimationFrame(draw);};
    const pointer=(e:PointerEvent)=>{if(motion.matches) return;const b=host.getBoundingClientRect();px=(e.clientX-b.left)/b.width-.5;py=(e.clientY-b.top)/b.height-.5;schedule();};
    const reset=()=>{px=py=0;redraw();};
    const observer=new ResizeObserver(redraw);observer.observe(host);
    host.addEventListener('pointermove',pointer);host.addEventListener('pointerleave',reset);
    motion.addEventListener('change',reset);document.addEventListener('visibilitychange',schedule);
    fetch(catalogUrl,{signal:request.signal}).then(response=>{if(!response.ok)throw new Error('Catalog unavailable');return response.json();}).then(catalog=>{if(disposed)return;stars=catalogStarRows(catalog.stars);if(!stars.length)throw new Error('Empty catalog');setCount(stars.length);redraw();}).catch(()=>{if(!disposed)setFailed(true);});
    redraw();
    return()=>{disposed=true;request.abort();cancelAnimationFrame(frame);observer.disconnect();host.removeEventListener('pointermove',pointer);host.removeEventListener('pointerleave',reset);motion.removeEventListener('change',reset);document.removeEventListener('visibilitychange',schedule);};
  },[]);
  return <>
    <canvas ref={ref} className="queen-starfield" aria-hidden="true" data-catalog="HYG4.1"/>
    <a className="queen-starfield-source" href="https://github.com/astronexus/HYG-Database/blob/main/hyg/README.md" target="_blank" rel="noopener noreferrer"
      title={lang==='ru'?'Координаты в парсеках · эпоха J2000 · David Nash / Astronexus · CC BY-SA4.0. Стилизованная проекция каталога, не текущее небо.':'Coordinates in parsecs · J2000 epoch · David Nash / Astronexus · CC BY-SA4.0. Styled catalog projection, not the current sky.'}>
      {failed?(lang==='ru'?'Каталог звёзд недоступен':'Star catalog unavailable'):`HYG4.1 · J2000${count===null?'':` · ${count} ${lang==='ru'?'звёзд':'stars'}`}`} ↗
    </a>
  </>;
}
