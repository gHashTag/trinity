import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const SOURCE_BLOB='ba2dec4eb0f6768914c7fc1051258100214ddf84';
// CSV quoted fields can contain commas, escaped quotes and line breaks.
export function selectHygStars(text) {
  const rows=[]; let row=[],field='',quoted=false;
  for(let i=0;i<text.length;i++) {
    const ch=text[i];
    if(ch==='"') { if(quoted && text[i+1]==='"') {field+='"';i++;} else quoted=!quoted; }
    else if(!quoted && (ch===',' || ch==='\n')) {
      row.push(field.replace(/\r$/,''));field='';
      if(ch==='\n') {rows.push(row);row=[];}
    } else field+=ch;
  }
  if(quoted) throw new Error('Unterminated CSV quote');
  if(field || row.length) {row.push(field.replace(/\r$/,''));rows.push(row);}
  const columns=rows.shift();
  const required=['id','proper','x','y','z','dist','mag','ci'];
  if(!columns || required.some(k=>!columns.includes(k))) throw new Error('Missing HYG columns');
  const at=Object.fromEntries(required.map(k=>[k,columns.indexOf(k)]));
  const number=(r,k)=>r[at[k]]?.trim() ? Number(r[at[k]]) : NaN;
  return rows.flatMap(r=>{
    const id=number(r,'id'),x=number(r,'x'),y=number(r,'y'),z=number(r,'z'),d=number(r,'dist'),m=number(r,'mag'),ci=number(r,'ci');
    if(![id,x,y,z,d,m].every(Number.isFinite) || id<=0 || d<=0 || d>=100000 || m>6 || Math.abs(Math.hypot(x,y,z)-d)>Math.max(.02,d*.001)) return [];
    return [[id,r[at.proper],x,y,z,d,m,Number.isFinite(ci)?ci:null]];
  }).sort((a,b)=>a[0]-b[0]);
}

if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  const input=process.argv[2]; if(!input) throw new Error('Usage: node scripts/import-hyg.mjs /path/to/hygdata_v41.csv');
  const bytes=readFileSync(input);
  const blob=createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex');
  if(blob!==SOURCE_BLOB) throw new Error('Source differs from reviewed HYG4.1 snapshot');
  const stars=selectHygStars(bytes.toString('utf8'));
  const catalog={catalog:'HYG4.1',epoch:'J2000',units:'parsec',credit:'David Nash / Astronexus',license:'CC BY-SA4.0',
    source:'https://github.com/astronexus/HYG-Database/blob/c7f7f883fe678cc7680169a50ccd7dcc49b060ce/hyg/CURRENT/hygdata_v41.csv',
    sourceBlob:blob,sha256:createHash('sha256').update(bytes).digest('hex'),
    filter:'id>0; 0<dist<100000pc; mag<=6; finite xyz/dist/mag; xyz norm agrees with dist',
    fields:['id','proper','x','y','z','dist','mag','ci'],stars};
  writeFileSync(new URL('../src/data/hyg-v41-bright.json',import.meta.url),JSON.stringify(catalog)+'\n');
  console.log(`HYG4.1 subset: ${stars.length} verified rows; source blob ${blob}`);
}
