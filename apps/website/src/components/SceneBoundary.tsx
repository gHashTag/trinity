import { Component, type ErrorInfo, type ReactNode } from "react";

/**
 * A boundary around the 3D scene, so that losing it does not lose the page.
 *
 * Measured 2026-09-08 in Safari at localhost:4179: the WebGL context was lost
 * the moment Babylon asked for it, the scene threw "Unable to create index
 * buffer" while building the comb, and with no boundary anywhere in this app
 * React unmounted the whole tree — the board, the rail, the Queen's column and
 * the header with them. The report was "the page does not load", and it was
 * accurate: everything except the scene had been working.
 *
 * The scene is one panel of a HUD. When it fails, the rest of the HUD stays and
 * this says what happened, in the same words the console used. Retry remounts
 * the subtree by key, which is the only remedy for a lost context that does not
 * cost a reload — a second context is sometimes granted where the first was not.
 */
const COPY = {
  en: {
    title: "THE MAP'S SCENE STOPPED",
    body: "The browser ended its WebGL context. The board, the modules and the Queen are unaffected.",
    retry: "Draw it again",
  },
  ru: {
    title: "СЦЕНА КАРТЫ ОСТАНОВЛЕНА",
    body: "Браузер закрыл контекст WebGL. Доска, модули и королева работают.",
    retry: "Нарисовать заново",
  },
} as const;

interface Props {
  children: ReactNode;
  lang: "en" | "ru";
  /** Told what broke, so a failure that only this boundary sees is still reported. */
  onError?: (error: Error) => void;
}

interface State {
  /** The error's own words. Null while there is none — never a boolean: the
   *  message is what makes the panel worth reading. */
  message: string | null;
  /** Remounts the subtree; a lost context is not always lost twice. */
  attempt: number;
}

export class SceneBoundary extends Component<Props, State> {
  state: State = { message: null, attempt: 0 };

  static getDerivedStateFromError(error: unknown): Partial<State> {
    return { message: error instanceof Error ? error.message : String(error) };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // The console still gets the stack: this panel is for the person looking at
    // the page, not instead of the record.
    console.error("scene failed", error, info.componentStack);
    this.props.onError?.(error);
  }

  render() {
    const t = COPY[this.props.lang] ?? COPY.en;
    if (this.state.message === null) {
      return <div key={this.state.attempt} className="queen-scene-holder">{this.props.children}</div>;
    }
    return (
      <div className="queen-scene-lost" role="status">
        <strong>{t.title}</strong>
        <p>{t.body}</p>
        <code>{this.state.message}</code>
        <button
          type="button"
          onClick={() => this.setState((prev) => ({ message: null, attempt: prev.attempt + 1 }))}
        >
          {t.retry}
        </button>
      </div>
    );
  }
}

export default SceneBoundary;
