// What "the same corpus" means, as a pure function both the store and the QA
// contract call. The Queen's tabs read four vendored files written by one scan
// (manifest, universe atlas, shared core, the six spec-* ladders); each tab
// prints a count from a different one. They agree only because one scan wrote
// all of them, so the agreement is checked here rather than assumed.
//
// No `import.meta.env`, no DOM: `node --experimental-strip-types` imports this.
import {sourceRepo} from './sharedSpecCore.ts';

/** The fields of public/t27/manifest.json this module reads. */
export interface CorpusManifest {
  generatedFrom?:{repo?:string;commit?:string;shortCommit?:string};
  specCount:number;
  specs:{path:string;repo?:string}[];
}

/** Who wrote the corpus, at which commit, how many specs, and the exact bytes. */
export interface CorpusIdentity {repo:string;commit:string;specCount:number;manifestSha256:string|null}

export function corpusIdentity(manifest:CorpusManifest,manifestSha256:string|null):CorpusIdentity {
  const from=manifest.generatedFrom??{};
  return {repo:from.repo??'unknown',commit:from.shortCommit??from.commit?.slice(0,9)??'unknown',specCount:manifest.specCount,manifestSha256};
}

/** One string every surface prints and the QA contract compares: `gHashTag/t27@2e4093d33/1577`. */
export function corpusVersion(id:CorpusIdentity):string {return `${id.repo}@${id.commit}/${id.specCount}`;}

/** The world a manifest spec belongs to, in the atlas's key (`ghashtag/t27`). `t27` and a missing repo are the corpus root. */
export function specWorld(repo:string|undefined):string {return sourceRepo(repo||'t27');}

/** A world name from an address, normalised the way the atlas spells it, or null when it is not a world name at all. */
export function worldParam(value:string|null|undefined):string|null {
  if(!value)return null;
  try{return sourceRepo(value);}catch{return null;}
}

export interface CorpusSiblings {
  atlas?:{provenance?:{manifestSha256?:unknown};specs:unknown[];worlds?:{repo:string;specCount:number}[]};
  sharedCore?:{provenance?:{manifestSha256?:unknown};specs:unknown[]};
  /** `ladder.specs` of each spec-* catalog, keyed by file. */
  ladders?:Record<string,number|undefined>;
}

/**
 * Every way the files can tell different tabs different things. Empty means
 * the manifest, the atlas, the shared core and every ladder describe one scan.
 */
export function corpusDisagreements(manifest:CorpusManifest,manifestSha256:string,siblings:CorpusSiblings):string[] {
  const out:string[]=[],n=manifest.specCount;
  if(!Number.isInteger(n)||n<=0)out.push(`manifest.specCount is ${String(n)}`);
  if(manifest.specs.length!==n)out.push(`manifest lists ${manifest.specs.length} specs but claims ${n}`);
  for(const [name,file] of [['universe-atlas',siblings.atlas],['shared-core',siblings.sharedCore]] as const){
    if(!file)continue;
    if(file.specs.length!==n)out.push(`${name} has ${file.specs.length} specs, manifest ${n}`);
    if(file.provenance?.manifestSha256!==manifestSha256)out.push(`${name} was built from manifest ${String(file.provenance?.manifestSha256).slice(0,12)}, the served one is ${manifestSha256.slice(0,12)}`);
  }
  for(const [file,count] of Object.entries(siblings.ladders??{}))if(count!==n)out.push(`${file} ladder says ${String(count)} specs, manifest ${n}`);
  if(siblings.atlas?.worlds){
    const byWorld=new Map<string,number>();
    for(const s of manifest.specs){const w=specWorld(s.repo);byWorld.set(w,(byWorld.get(w)??0)+1);}
    for(const w of siblings.atlas.worlds){const listed=byWorld.get(w.repo)??0;if(w.specCount!==listed)out.push(`world ${w.repo}: comb shows ${w.specCount}, Explorer lists ${listed}`);byWorld.delete(w.repo);}
    for(const [w,listed] of byWorld)out.push(`world ${w}: Explorer lists ${listed}, the atlas has no such world`);
  }
  return out;
}
