// The Queen's corpus, read once for every tab.
//
// Before this module the spec corpus was fetched by whoever wanted it: the
// shell read t27/manifest.json, the Explorer frame inside it read the same
// 1.8 MB again, the Specs directive read it a third time for its health strip,
// and the comb and the hero block each read the universe atlas on their own.
// Each held its own copy, so nothing said two tabs were showing one corpus;
// they agreed only because one scan happened to write all the files.
//
// One store now. A part is fetched once per window tree: the Explorer is a
// same-origin iframe of the shell, so the frame adopts the shell's registry
// and both read the very same promise. The registry fetches in its own realm,
// so a frame that is torn down on a tab switch cannot leave a half-read part
// behind for the shell. A cross-origin ancestor ends the walk; a page alone
// keeps its own.
//
// Each part says where it came from (`wire` = the supervisor, `file` = the
// vendored snapshot) and when it was generated. The manifest carries no time
// of its own -- its identity is its commit and the SHA-256 of its bytes, which
// the atlas and the shared core record as the manifest they were built from.
//
// No `import.meta.env` here: qa/spec-catalog-contract.mjs imports the compiler
// driver, which reads the manifest through this store, under plain Node.
// Wire addresses are therefore passed in by the caller.
import type {FoundationIssue,HudModule} from '../components/queenHud.ts';
import {corpusIdentity,corpusVersion,type CorpusIdentity} from './queenCorpusCheck.ts';
import type {SpecManifest} from './t27Compiler.ts';
import {validateAtlas,type UniverseAtlas} from './queenUniverseAtlas.ts';
import {useEffect,useState} from 'react';

export type CorpusSource='wire'|'file';
export interface CorpusPart<T> {data:T;source:CorpusSource;generatedAt:string|null}
export interface ManifestPart extends CorpusPart<SpecManifest> {identity:CorpusIdentity;version:string}

export interface ModulesSnapshot {repo?:string;commit:string|null;generatedAt:string;modules:HudModule[]}
/** The loop's GitHub snapshot: closed issues (the foundation), epics (the castle), rings, releases. */
export interface FoundationSnapshot {
  generatedAt:string;repo:string;rings:string[];closedIssues:FoundationIssue[];
  epics:Array<{number:number;title:string;state:string;closedAt:string|null;labels:string[];ring:string|null;ringBy:string|null;children:Array<{number:number;title:string;state:string;closedAt:string|null}>}>;
  releases:Array<{tag:string;name:string;publishedAt:string|null;prerelease:boolean}>;
}

interface Parts {manifest:ManifestPart;atlas:CorpusPart<UniverseAtlas>;modules:CorpusPart<ModulesSnapshot>;foundation:CorpusPart<FoundationSnapshot>}
export type CorpusPartName=keyof Parts;
export interface LoadOptions {
  /** The supervisor's route for this part, tried before the vendored file. */
  wire?:string|null;
  /** Bypass the cached part (a poll). The cache is replaced only on success. */
  fresh?:boolean;
}

const FILES:Record<CorpusPartName,{path:string;cache:RequestCache}>={
  manifest:{path:'t27/manifest.json',cache:'default'},
  atlas:{path:'t27/universe-atlas.json',cache:'default'},
  modules:{path:'queen/modules.json',cache:'no-store'},
  foundation:{path:'queen/foundation.json',cache:'no-cache'},
};

async function sha256Hex(bytes:ArrayBuffer):Promise<string|null> {
  const subtle=globalThis.crypto?.subtle;
  if(!subtle)return null;// an insecure origin has no SubtleCrypto: the hash is unknown, not invented
  const digest=new Uint8Array(await subtle.digest('SHA-256',bytes));
  return Array.from(digest,b=>b.toString(16).padStart(2,'0')).join('');
}

async function read(url:string,cache:RequestCache):Promise<ArrayBuffer> {
  const response=await fetch(url,{headers:{Accept:'application/json'},cache,credentials:'omit'});
  if(!response.ok)throw Object.assign(new Error(`could not fetch ${url.split('/').slice(-2).join('/')} (${response.status})`),{status:response.status});
  return response.arrayBuffer();
}
const json=(bytes:ArrayBuffer):unknown=>JSON.parse(new TextDecoder().decode(bytes));

function modules(value:unknown):ModulesSnapshot {
  const next=value as ModulesSnapshot;
  if(!Array.isArray(next?.modules)||next.modules.length===0)throw new Error('no modules');
  return next;
}
function foundation(value:unknown):FoundationSnapshot {
  const next=value as FoundationSnapshot;
  if(!Array.isArray(next?.closedIssues)||typeof next.generatedAt!=='string')throw new Error('no snapshot');
  return {...next,rings:Array.isArray(next.rings)?next.rings:[],epics:Array.isArray(next.epics)?next.epics:[],releases:Array.isArray(next.releases)?next.releases:[]};
}

/** Wire routes that answered 404 in this realm; the registry lives in the top window, so every frame shares it. */
const missingWires=new Set<string>();

async function fetchPart(name:CorpusPartName,file:string,wire:string|null):Promise<Parts[CorpusPartName]> {
  const {cache}=FILES[name];
  if(name==='manifest'){
    const bytes=await read(file,cache),data=json(bytes) as SpecManifest;
    if(!Array.isArray(data?.specs)||typeof data.specCount!=='number')throw new Error('the spec manifest has no specs');
    const identity=corpusIdentity(data,await sha256Hex(bytes));
    return {data,source:'file',generatedAt:null,identity,version:corpusVersion(identity)};
  }
  if(name==='atlas'){const data=validateAtlas(json(await read(file,cache)));return {data,source:'file',generatedAt:data.at};}
  const parse=name==='modules'?modules:foundation;
  // The supervisor first; the loop's dated snapshot only when the wire has none.
  // A route the supervisor answers 404 is asked once per page, not on every
  // poll of every frame (measured 2026-10-04: /queen/public-modules and
  // /queen/public-foundation both 404, so the home printed a console error
  // every 15 s per Queen frame). A 5xx or a network failure is asked again.
  if(wire&&!missingWires.has(wire))try{const data=parse(json(await read(wire,'no-store')));return {data,source:'wire',generatedAt:data.generatedAt} as Parts[CorpusPartName];}catch(error){if((error as {status?:number}).status===404)missingWires.add(wire);/* fall through to the file */}
  const data=parse(json(await read(file,cache)));
  return {data,source:'file',generatedAt:data.generatedAt} as Parts[CorpusPartName];
}

/** Version of the registry's calling convention; a frame from another build keeps its own. */
const REGISTRY_VERSION=1;
const REGISTRY_KEY='__t27QueenCorpus';
interface Registry {version:number;load(name:CorpusPartName,file:string,wire:string|null,fresh:boolean):Promise<unknown>}

function createRegistry():Registry {
  const parts=new Map<string,Promise<unknown>>();
  return {version:REGISTRY_VERSION,load(name,file,wire,fresh){
    const key=`${name} ${file}`,held=parts.get(key);
    if(held&&!fresh)return held;
    const next=fetchPart(name,file,wire);
    // A poll replaces the part only when it succeeds; a failed first read is
    // forgotten so the next caller retries instead of inheriting the failure.
    if(held){void next.then(()=>parts.set(key,next),()=>{});return next;}
    const entry:Promise<unknown>=next.catch((error:unknown)=>{if(parts.get(key)===entry)parts.delete(key);throw error;});
    parts.set(key,entry);
    return entry;
  }};
}

let registry:Registry|null=null;
function corpusRegistry():Registry {
  if(registry)return registry;
  if(typeof window==='undefined')return registry=createRegistry();
  let found:Registry|null=null;
  try{
    for(let w:Window=window;;w=w.parent){
      const held=(w as unknown as Record<string,Registry|undefined>)[REGISTRY_KEY];
      if(held?.version===REGISTRY_VERSION)found=held;
      if(w.parent===w)break;
    }
  }catch{/* a cross-origin ancestor: what was found below it stands */}
  if(!found){found=createRegistry();(window as unknown as Record<string,Registry>)[REGISTRY_KEY]=found;}
  return registry=found;
}

/** A vendored path, resolved against this document so a parent window fetches the address this frame meant. */
function address(path:string):string {
  return typeof document==='undefined'?path:new URL(path,document.baseURI).href;
}

export function loadCorpus<K extends CorpusPartName>(name:K,options:LoadOptions={}):Promise<Parts[K]> {
  return corpusRegistry().load(name,address(FILES[name].path),options.wire??null,options.fresh??false) as Promise<Parts[K]>;
}

/**
 * A part for a component. `pollMs` re-reads it (the shell's modules and
 * foundation follow the loop); without it the part is read once per window
 * tree. A failed read stays null and reports its error: unknown, not zero.
 */
export function useCorpus<K extends CorpusPartName>(name:K,options:{wire?:string|null;pollMs?:number}={}):{part:Parts[K]|null;error:string|null} {
  const [part,setPart]=useState<Parts[K]|null>(null);
  const [error,setError]=useState<string|null>(null);
  const {wire=null,pollMs}=options;
  useEffect(()=>{
    let active=true;
    const run=(fresh:boolean)=>loadCorpus(name,{wire,fresh})
      .then(next=>{if(active){setPart(next);setError(null);}})
      .catch((next:unknown)=>{if(active)setError(next instanceof Error?next.message:String(next));});
    void run(false);
    const timer=pollMs?window.setInterval(()=>void run(true),pollMs):undefined;
    return ()=>{active=false;if(timer!==undefined)window.clearInterval(timer);};
  },[name,wire,pollMs]);
  return {part,error};
}
