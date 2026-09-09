import Navigation from './components/Navigation'
import GameHero from './components/GameHero'
import Footer from './components/Footer'
import ServiceEntry from './components/ServiceEntry'
import QueenHeroBlock from './components/QueenHeroBlock'
import SpecHeroBlock from './components/SpecHeroBlock'
import ModulesBlock from './components/ModulesBlock'
import ModuleHeroBlock from './components/ModuleHeroBlock'
import PlayBlock from './components/PlayBlock'

// Главная — это игра. Первый экран: карта, на которой лежат спеки, затем сама
// спека, затем шесть модулей, каждый показан собой же.
//
// Число и заявление о форматах — r² = r + 1 и всё, что из него следует, — были
// здесь первым экраном и переехали на /trinity целиком. Тот, кто пришёл за
// арифметикой, находит её в одном месте, а не прокручивает мимо, чтобы дойти
// до доски.
//
// Прежняя главная несла 21 секцию и 31 393px (около 35 экранов): вся статья
// «Trinity S³AI: Ternary Network Floats» лежала на одной странице, и цель игры
// в ней терялась. Ни одна секция не удалена — каждая переехала на свою
// страницу и живёт там целиком:
//
//   formats, visuals, calculators → /gft
//   ladder, theorems, limits      → /proof
//   frontier, reproduce           → /verification
//   decision                      → /select
//   landscape, findings           → /cases
//   lineage, author               → /about
//   faq, publications             → /resources
//   start                         → /start
//   invest                        → /ip
export default function App() {
  return (
    <main>
      <Navigation />

      {/* The mark first, and then in one line what the site is. The number the
          game exists to build lives on /trinity and is linked from here. */}
      <GameHero />
      <QueenHeroBlock />
      <SpecHeroBlock />
      {/* The six modules of the shell, each with what it actually shows and a
          link that opens that tab. The two blocks above are the map and the
          corpus; this is the rest of the same one screen. */}
      {/* The point of the front door: a developer arrives, and the four moves
          that put a cell of the core in their hands are named before the
          modules are. The core is built by playing it. */}
      <PlayBlock />
      <ModulesBlock />
      {/* And then each of the four the two blocks above do not already show,
          the same way those two do it: the module itself in a frame, not a
          picture of one. The map is the QUEEN block, the corpus the SPEC one. */}
      <ModuleHeroBlock tab="kanban" />
      <ModuleHeroBlock tab="map" />
      <ModuleHeroBlock tab="factory" />
      <ModuleHeroBlock tab="research" />

      <ServiceEntry />

      <Footer />
    </main>
  )
}
