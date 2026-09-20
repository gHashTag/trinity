import Navigation from './components/Navigation'
import GameHero from './components/GameHero'
import Footer from './components/Footer'
import ServiceEntry from './components/ServiceEntry'
import QueenHeroBlock from './components/QueenHeroBlock'
import SpecHeroBlock from './components/SpecHeroBlock'
import ModuleHeroBlock from './components/ModuleHeroBlock'
import PlayBlock from './components/PlayBlock'
import AgiGameBlock from './components/AgiGameBlock'
import FaqBlock from './components/FaqBlock'
import ModulesBlock from './components/ModulesBlock'

// Модулей на главной три, а не одиннадцать: доску, корпус и этот показ ведут
// собственные блоки, остальные лежат указателем в конце.
const SHOWCASE = ['kanban', 'factory', 'agents'] as const

// Главная — это игра, и читается она как воронка: марка и девиз, живая доска,
// зачем ею управлять, как сделать ход, что спрашивают перед ходом, вход — и
// только потом глубина: корпус, три модуля в полный рост и указатель на все
// остальные.
//
// Порядок такой не по вкусу. Страницу измерили: 20 962px, 27 экранов, из них
// восемнадцать подряд — одиннадцать одинаковых блоков модулей с одной и той же
// кнопкой, а единственный шаг, где посетитель может назваться, стоял двадцать
// пятым. Возражения не разбирались нигде. Всё перечисленное — известные
// причины терять читателя, и все три исправлены здесь, а не переписаны словами.
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

      {/* The mark, the motto under it, and in one line what the site is. The
          number the game exists to build lives on /trinity and is linked from
          here. */}
      <GameHero />

      {/* The board itself, second. It is the strongest thing this page has —
          the live scene the /queen route mounts, not a picture of it — and it
          used to sit at the seventh screen, behind the argument for it. Show
          the board, then argue for it. */}
      <QueenHeroBlock />

      {/* Why a swarm is worth directing, before how to contribute to it. It
          carries the move the site never named — writing the boundary that
          lets the Queen dispatch an issue — and the supervisor's own refusal
          count as the evidence that the move is needed. Its first card hands
          the reader down to PlayBlock, so it sits above it. */}
      <AgiGameBlock />
      {/* The point of the front door: a developer arrives, and the four moves
          that put a cell of the core in their hands are named before the
          modules are. The core is built by playing it. */}
      <PlayBlock />

      {/* What the reader is thinking once the moves are named: what it costs,
          whether the language has to come first, what happens after they send.
          Objections are answered where they are raised, and the ask comes
          straight after them rather than twenty screens later. */}
      <FaqBlock />
      <ServiceEntry />

      {/* Then the depth, for the reader still going: the corpus through the
          real compiler, three modules shown at full size, and an index of all
          of them.
          This place carried eleven identical blocks — eighteen consecutive
          screens of one layout and one button. The header comment above said
          "затем шесть модулей" and had stopped being true. The showcase is now
          a named list, and every other module stands as a card at the end, so
          none is lost and none is repeated. */}
      <SpecHeroBlock />
      {SHOWCASE.map((tab) => (
        <ModuleHeroBlock key={tab} tab={tab} />
      ))}
      {/* Every module is reachable from the homepage: ModulesBlock draws all
          MODULES.length cards, TRI included — whose full-size preview would
          load a whole third-party app for everyone who scrolled past it. */}
      <ModulesBlock />

      <Footer />
    </main>
  )
}
