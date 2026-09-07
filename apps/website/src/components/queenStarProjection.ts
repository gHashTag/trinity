export type CatalogStar = readonly [number,string,number,number,number,number,number,number|null];
export interface StarView { yaw: number; pitch: number; offset: number }
export function catalogStarRows(value: unknown): CatalogStar[] {
  if(!Array.isArray(value)) return [];
  return value.filter((r): r is CatalogStar=>Array.isArray(r) && r.length===8 &&
    typeof r[1]==='string' && [0,2,3,4,5,6].every(i=>typeof r[i]==='number' && Number.isFinite(r[i])) &&
    r[0]>0 && r[5]>0 && r[5]<100000 && r[6]<=6 &&
    (r[7]===null || (typeof r[7]==='number' && Number.isFinite(r[7]))));
}
// Perspective view of the original parsec coordinates, not random/spherical particles.
// Offset moves the observer across the view's right axis in parsecs.
export function projectCatalogStar(star: CatalogStar, width: number, height: number, view: StarView) {
  const [, ,x,y,z]=star;
  const cy=Math.cos(view.yaw),sy=Math.sin(view.yaw),cp=Math.cos(view.pitch),sp=Math.sin(view.pitch);
  const depth=x*cp*cy+y*cp*sy+z*sp;
  if(!Number.isFinite(depth) || depth<=0 || width<=0 || height<=0) return null;
  const right=-x*sy+y*cy-view.offset, up=-x*sp*cy-y*sp*sy+z*cp;
  const focal=Math.min(width,height)*.62;
  const px=width/2+right/depth*focal,py=height/2-up/depth*focal;
  return Number.isFinite(px) && Number.isFinite(py) ? {x:px,y:py,depth} : null;
}
