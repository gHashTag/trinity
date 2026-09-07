import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Matrix, Vector3 } from '@babylonjs/core/Maths/math.vector.js';
import { HIVE_WALL_ROTATION, hiveWallToWorld, hiveWorldToWall } from '../src/components/queenHiveOrientation.ts';

const close = (a,b) => assert.ok(Math.abs(a-b)<1e-5, `${a} != ${b}`);
const rotation = Matrix.RotationYawPitchRoll(HIVE_WALL_ROTATION.y,HIVE_WALL_ROTATION.x,HIVE_WALL_ROTATION.z);
const view = Matrix.LookAtLH(new Vector3(0,0,4000),Vector3.Zero(),Vector3.Up());
const screen = (x,z,height=0) => {
  const p=Vector3.TransformCoordinates(new Vector3(x,height,z),rotation.multiply(view));
  return {x:p.x,y:-p.y,depth:p.z};
};
// Screen axes retain the source handedness after the true half-turn.
assert.ok(screen(100,0).x>screen(0,0).x, 'local right must project right, not mirrored');
assert.ok(screen(0,100).y<screen(0,0).y, 'positive local z is above the hub after the turn');
assert.ok(screen(0,0,8).depth<screen(0,0).depth, 'hover lift remains toward the camera');
// The mark uses source SVG x/y with local z=-svgY. Base above, apex below.
const baseLeft=screen(-.5,Math.sqrt(3)/6),baseRight=screen(.5,Math.sqrt(3)/6);
const apex=screen(0,-Math.sqrt(3)/3);
assert.ok(apex.y>baseLeft.y && apex.y>baseRight.y, 'original logo apex points DOWN');
assert.ok(baseLeft.x<baseRight.x, 'original logo must not be mirrored');
for (const [x,z] of [[0,0],[123,-87],[-400,222]]) {
  const expected=Vector3.TransformCoordinates(new Vector3(x,0,z),rotation);
  const world=hiveWallToWorld(x,z); close(world.x,expected.x); close(world.y,expected.y);
  const local=hiveWorldToWall(world.x,world.y+7,7); close(local.x,x); close(local.z,z);
}
const scene=readFileSync(new URL('../src/components/QueenCombBabylon.tsx',import.meta.url),'utf8');
assert.match(scene,/fieldRoot.rotation.copyFromFloats\(HIVE_WALL_ROTATION.x, HIVE_WALL_ROTATION.y, HIVE_WALL_ROTATION.z\)/);
assert.match(scene,/return hiveWorldToWall\(wx, wy, fieldRoot.position.y\)/, 'picking uses inverse including wall drift');
assert.match(scene,/hiveWallToWorld\(cells\[focusIndex\].x, cells\[focusIndex\].y\)/, 'inspect targets the rotated cell');
assert.match(scene,/hiveWallToWorld\(anchor.x, anchor.z\)/, 'cursor zoom targets the rotated cell');
assert.match(scene,/cells\[home\].y - ay \* k/, 'original SVG coordinates remain unchanged');
assert.match(scene,/new ArcRotateCamera\("cam", Math.PI \/ 2, Math.PI \/ 2/, 'camera stays in front');
console.log('Hive orientation: PASS (point-down logo, handedness, lift, inverse picking, focus, zoom)');
