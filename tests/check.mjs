// Node 18+. Runs real Luau sources in the official CLI with a small engine mock.
// This does not replace Studio physics, rendering, networking or navmesh tests.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
const root = path.resolve(import.meta.dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const project = JSON.parse(read('default.project.json'));
assert.equal(project.tree.ServerScriptService.Server.$path, 'src/server');
assert.equal(project.tree.StarterPlayer.StarterPlayerScripts.Client.$path, 'src/client');
assert.equal(project.tree.ReplicatedStorage.Shared.$path, 'src/shared');
const layout = [...read('src/server/Facility.luau').matchAll(/^\s*"([#.SABCEMH]+)",/gm)].map(m => m[1]);
assert.equal(layout.length, 19);
assert(layout.every(row => row.length === 23));
assert.equal(layout.join('').split('H').length - 1, 8);
for(const symbol of 'SABCEM') assert.equal(layout.join('').split(symbol).length - 1, 1);
let start;
const targets = [];
layout.forEach((row,z)=>[...row].forEach((c,x)=>{
  if(c==='S') start=[x,z];
  if('ABCEMH'.includes(c)) targets.push([x,z]);
  if(c==='H') assert.equal(layout[z-1][x], '#', 'Closets must have a north wall');
}));
const queue=[start], seen=new Set([start.join(',')]);
for(let i=0;i<queue.length;i++) {
  const [x,z]=queue[i];
  for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
    const nx=x+dx,nz=z+dz,key=`${nx},${nz}`;
    if(layout[nz]?.[nx] && layout[nz][nx]!=='#' && !seen.has(key)) {seen.add(key);queue.push([nx,nz]);}
  }
}
assert(targets.every(p=>seen.has(p.join(','))), 'All relays, exit and monster must be reachable');
assert.equal(seen.size, layout.join('').replaceAll('#','').length, 'No isolated walkable regions');
console.log(`PASS Rojo mappings; ${seen.size} connected walkable cells; all objectives/exit reachable`);
const harness = read('tests/monster.spec.luau').replace('-- MONSTER_SOURCE', read('src/server/MonsterService.luau')) + '\n' + read('tests/hiding.spec.luau').replace('-- HIDING_SOURCE', read('src/server/HidingService.luau'));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'blindspot-test-'));
try {
  const file=path.join(temp,'monster.luau'); fs.writeFileSync(file,harness);
  const result=spawnSync(process.env.LUAU || 'luau',[file],{encoding:'utf8'});
  process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || '');
  if(result.error) throw result.error;
  assert.equal(result.status,0,'Monster behavior tests failed');
} finally {fs.rmSync(temp,{recursive:true,force:true});}
