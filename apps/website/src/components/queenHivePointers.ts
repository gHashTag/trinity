type Point = {x:number;y:number};
/** Screen-space gesture state; no synthetic tasks or renderer dependencies. */
export class HivePointers {
  private points=new Map<number,Point>();
  private travel=0;
  suppressClick=false;
  down(id:number,x:number,y:number) {
    if(!this.points.size){this.travel=0;this.suppressClick=false;}
    this.points.set(id,{x,y});
    if(this.points.size>1)this.suppressClick=true;
  }
  move(id:number,x:number,y:number):{from:Point;to:Point;scale:number}|null {
    const previous=this.points.get(id);if(!previous)return null;
    const before=[...this.points.values()].slice(0,2);
    this.travel+=Math.hypot(x-previous.x,y-previous.y);
    this.points.set(id,{x,y});
    const after=[...this.points.values()].slice(0,2);
    if(this.travel>6)this.suppressClick=true;
    if(!this.suppressClick)return null;
    const centre=(points:Point[])=>({x:points.reduce((n,p)=>n+p.x,0)/points.length,y:points.reduce((n,p)=>n+p.y,0)/points.length});
    const distance=(points:Point[])=>Math.hypot(points[0].x-points[1].x,points[0].y-points[1].y);
    return {from:centre(before),to:centre(after),scale:before.length===2?Math.max(1,distance(after))/Math.max(1,distance(before)):1};
  }
  up(id:number,cancelled=false) {if(this.points.delete(id)&&cancelled)this.suppressClick=true;}
  cancel() {if(this.points.size)this.suppressClick=true;this.points.clear();}
}
