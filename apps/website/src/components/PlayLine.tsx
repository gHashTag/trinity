import './PlayLine.css'

// One line, under the description of a view, saying what the view is FOR: which
// move a reader makes there. The pair is the point — a description with no
// reason is an instrument handed to someone who was never told what it is for —
// and the text always comes from lib/queenModules, so the module's description
// and the move it enables are the same record and cannot drift apart.
//
// It is a component rather than a class name because three different blocks
// mount it (the comb's, the corpus's, and the one every other module shares),
// and a class name typed three times is a class name that will be typed wrong
// once.
export default function PlayLine({ children }: { children: string }) {
  return <p className="play-line">{children}</p>
}
