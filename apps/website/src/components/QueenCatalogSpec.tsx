import {type UniverseAtlas} from '../lib/queenUniverseAtlas';
import {specExplorerHash} from '../lib/specCatalog';

// The spec explorer, embedded.
//
// This file used to open with a 320px aside that showed a cell beside a moving
// map. QueenCellStage replaced it: the same cell now takes the whole display,
// with the board, the bee's log and the chat in it. What stayed is the one
// thing the aside did that the stage does not -- open a .t27 source in the
// explorer -- and it is kept here because /specs is its own surface.

export function QueenCatalogSpec({atlas,path,lang,onClose}:{atlas:UniverseAtlas;path:string;lang:'ru'|'en';onClose:()=>void}) {
  const ru=lang==='ru',spec=atlas.specs.find(s=>s.sources.some(src=>src.path===path));
  return <section className="queen-catalog-spec" aria-label={ru?'Центральный каталог спек':'Central spec catalog'}>
    <header><strong>Spec Explorer · /specs</strong><button onClick={onClose}>{ru?'← Назад к карте':'← Back to map'}</button></header>
    <p>{ru?'Единый каталог /specs · исходник, анализ и генерация. Правки здесь — черновик, не принятая спека.':'One /specs catalog · source, analysis and generation. Edits here are a draft, not an accepted spec.'}</p>
    {spec?<iframe title={ru?'Обозреватель спецификации T27':'T27 Spec Explorer'} src={`./?lang=${ru?'ru':'en'}${specExplorerHash(path,{embedded:true,sha256:spec.id})}`} sandbox="allow-scripts allow-same-origin" allow="clipboard-write"/>:<p role="alert">{ru?'Спека отсутствует в каталоге карты.':'Spec is missing from the map catalog.'}</p>}
  </section>;
}
