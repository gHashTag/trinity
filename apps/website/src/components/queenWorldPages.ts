import {loadWorldIssues,mergeWorldIssues,retainObservation,type WorldIssue} from './queenRepositoryWorld.ts';
import {worldPagesPolicy as policy} from '../lib/queenWorldPages.generated.ts';

/**
 * specs/queen/world_pages.t27 (#1513): the catalog map reads every page of a
 * supported world's issues, one page at a time, up to MAX_PAGES. GitHub lists
 * issues and pull requests together, so the first page holds fewer issues than
 * PER_PAGE and a repository with more than that has its newest issues later.
 */
export const WORLD_MAX_PAGES=policy.MAX_PAGES;
type Fetcher=typeof fetch;

/** NEXT: the page just read succeeded, GitHub announces another, the number is below the ceiling, the caller is live. */
export const wantsNextPage=(read:boolean,more:boolean,page:number,live:boolean)=>policy.NEXT[Number(read)+2*Number(more)+4*Number(page<policy.MAX_PAGES)+8*Number(live)]===1;
/** COMPLETE: the pages ran out, none failed, the caller is live. A capped world is partial. */
export const worldComplete=(ranOut:boolean,clean:boolean,live:boolean)=>policy.COMPLETE[Number(ranOut)+2*Number(clean)+4*Number(live)]===1;
/** DROP_UNSEEN: a row an earlier visit showed is dropped only when the whole world was read. */
export const dropsUnseen=(complete:boolean)=>policy.DROP_UNSEEN[Number(complete)]===1;

export type WorldRead={
  /** Every issue of the pages read so far, merged by key; the pages after a failure are not invented. */
  rows:WorldIssue[];
  /** Pages read successfully. */
  pages:number;
  /** False while another page is being requested; the last call of a load has done true. */
  done:boolean;
  /** Only a finished load whose pages ran out without error; a capped or failed load is partial. */
  complete:boolean;
  error:string|null;
};

/**
 * Reads page 1, 2, ... of one world. `onRead` runs after every page, so the map
 * shows page 1 at once, and once more when the load is over. A failure of page 1
 * rejects (nothing was read, the caller withdraws proof as before); a failure of
 * a later page ends the load with the rows already read and `complete` false.
 * An aborted signal rejects. Pages are never requested in parallel.
 */
export async function readWorldPages(repo:string,signal:AbortSignal,onRead:(read:WorldRead)=>void,fetcher:Fetcher=fetch):Promise<WorldRead> {
  let rows:WorldIssue[]=[];
  for(let page=1;;page++){
    let step:Awaited<ReturnType<typeof loadWorldIssues>>;
    try{step=await loadWorldIssues(repo,page,signal,fetcher);}
    catch(error){
      if(page===1||signal.aborted)throw error;
      const stopped:WorldRead={rows,pages:page-1,done:true,complete:false,error:error instanceof Error?error.message:'read-failed'};
      onRead(stopped);
      return stopped;
    }
    rows=mergeWorldIssues(rows,step.rows);
    const done=!wantsNextPage(true,step.hasMore,page,!signal.aborted);
    const read:WorldRead={rows,pages:page,done,complete:done&&worldComplete(!step.hasMore,true,!signal.aborted),error:null};
    onRead(read);
    if(done)return read;
    // The callback may have ended the caller's interest: ask the spec again before the next request.
    if(!wantsNextPage(true,step.hasMore,page,!signal.aborted))return {...read,done:true,complete:false};
  }
}

/**
 * Folds a read into the observed rows of the map. Rows this load read replace the
 * earlier ones; rows of other worlds are untouched; slots keep their order so the
 * map does not shift while pages arrive. A row an earlier visit showed and this
 * load did not read again stays untouched while the load runs; when it ends the
 * row is dropped if the world was read completely, otherwise it stays as the last
 * observation with coverage and proof withdrawn (#1392).
 */
export function applyWorldRead(prev:Record<string,WorldIssue>,repo:string,read:WorldRead):Record<string,WorldIssue> {
  const fresh=new Map(read.rows.map(row=>[row.key,row])),next:Record<string,WorldIssue>={};
  for(const [key,row] of Object.entries(prev)) {
    if(row.repo!==repo){next[key]=row;continue;}
    const seen=fresh.get(key);
    if(seen)next[key]=seen;
    else if(!read.done)next[key]=row;
    else if(!dropsUnseen(read.complete))next[key]=retainObservation(row,false,true);
  }
  for(const row of read.rows)if(!Object.hasOwn(next,row.key))next[row.key]=row;
  return next;
}
