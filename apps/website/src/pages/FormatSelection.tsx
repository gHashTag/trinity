import { useState } from 'react'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

type TaskId = 'weights' | 'accumulation' | 'fpga' | 'audit'

type Cell = { status: 'start' | 'compare' | 'check' | 'not'; text: { ru: string; en: string } }

type Candidate = {
  name: string
  family: { ru: string; en: string }
  note: { ru: string; en: string }
  cells: Record<TaskId, Cell>
}

const TASKS: { id: TaskId; ru: string; en: string }[] = [
  { id: 'weights', ru: 'Веса модели', en: 'Model weights' },
  { id: 'accumulation', ru: 'Накопление', en: 'Accumulation' },
  { id: 'fpga', ru: 'Арифметика на FPGA', en: 'FPGA arithmetic' },
  { id: 'audit', ru: 'Аудит и воспроизводимость', en: 'Audit and reproduction' },
]

const CANDIDATES: Candidate[] = [
  {
    name: 'int8',
    family: { ru: 'целочисленный', en: 'integer' },
    note: { ru: 'практическая точка сравнения для низкой разрядности', en: 'a practical low-bit comparison point' },
    cells: {
      weights: { status: 'start', text: { ru: 'начать с замера на своих данных', en: 'start with a measurement on your data' } },
      accumulation: { status: 'check', text: { ru: 'проверить ширину аккумулятора отдельно', en: 'check accumulator width separately' } },
      fpga: { status: 'compare', text: { ru: 'сопоставить с ресурсами и задержкой', en: 'compare resources and latency' } },
      audit: { status: 'start', text: { ru: 'удобная базовая линия для векторов', en: 'a useful baseline for vectors' } },
    },
  },
  {
    name: 'FP8 e4m3',
    family: { ru: 'плавающая точка', en: 'floating point' },
    note: { ru: 'кандидат для компактного представления с явными границами', en: 'a compact candidate with explicit bounds' },
    cells: {
      weights: { status: 'compare', text: { ru: 'сравнить с ошибкой и переполнением', en: 'compare error and overflow' } },
      accumulation: { status: 'check', text: { ru: 'накапливать в более широком формате', en: 'accumulate in a wider format' } },
      fpga: { status: 'check', text: { ru: 'проверить декодер и тайминг', en: 'check decoder and timing' } },
      audit: { status: 'compare', text: { ru: 'закрепить независимый оракул', en: 'pin an independent oracle' } },
    },
  },
  {
    name: 'GF16',
    family: { ru: 'фиксированные поля', en: 'fixed fields' },
    note: { ru: 'кандидат GoldenFloat; выбор зависит от задачи и распределения', en: 'a GoldenFloat candidate; the choice depends on task and distribution' },
    cells: {
      weights: { status: 'compare', text: { ru: 'сверить с вашей моделью, не с SQNR одного слоя', en: 'compare on your model, not one layer’s SQNR' } },
      accumulation: { status: 'start', text: { ru: 'проверить широкий аккумулятор', en: 'check a wide accumulator' } },
      fpga: { status: 'compare', text: { ru: 'прогнать RTL и векторы на AX7203', en: 'run RTL and vectors on AX7203' } },
      audit: { status: 'start', text: { ru: 'зафиксировать формат и версию векторов', en: 'record format and vector version' } },
    },
  },
  {
    name: 'binary16',
    family: { ru: 'плавающая точка', en: 'floating point' },
    note: { ru: 'широкая точка отсчёта для точности и диапазона', en: 'a wider reference point for accuracy and range' },
    cells: {
      weights: { status: 'compare', text: { ru: 'использовать как контрольный вариант', en: 'use as a control variant' } },
      accumulation: { status: 'start', text: { ru: 'сравнить ошибки накопления', en: 'compare accumulation error' } },
      fpga: { status: 'check', text: { ru: 'оценить цену ресурсов на плате', en: 'estimate board resource cost' } },
      audit: { status: 'start', text: { ru: 'проверить согласованность оракулов', en: 'check oracle agreement' } },
    },
  },
  {
    name: 'takum16',
    family: { ru: 'tapered', en: 'tapered' },
    note: { ru: 'сравнительный формат; не заменяет замер на вашей нагрузке', en: 'a comparison format; it does not replace a workload measurement' },
    cells: {
      weights: { status: 'compare', text: { ru: 'сопоставить на том же наборе данных', en: 'compare on the same data' } },
      accumulation: { status: 'check', text: { ru: 'проверить поведение хвоста и округления', en: 'check tail and rounding behaviour' } },
      fpga: { status: 'check', text: { ru: 'проверить отдельный RTL-путь', en: 'check a separate RTL path' } },
      audit: { status: 'compare', text: { ru: 'использовать одинаковые векторы входов', en: 'use identical input vectors' } },
    },
  },
]

const STATUS_LABELS = {
  start: { ru: 'начать здесь', en: 'start here' },
  compare: { ru: 'сравнить', en: 'compare' },
  check: { ru: 'проверить', en: 'check' },
  not: { ru: 'не применять', en: 'do not use' },
}

export default function FormatSelection() {
  const { lang } = useI18n()
  const ru = lang === 'ru'
  const [task, setTask] = useState<TaskId>('weights')
  const selectedTask = TASKS.find((item) => item.id === task) ?? TASKS[0]

  usePageMeta(
    ru ? 'Выбор формата' : 'Format selection',
    ru
      ? 'Матрица выбора формата по задаче: 83 кандидата каталога, явные критерии сравнения и границы измерения.'
      : 'A task-by-format selection matrix for the 83-format catalogue, with explicit comparison criteria and measurement boundaries.',
  )

  const text = (value: { ru: string; en: string }) => ru ? value.ru : value.en

  return (
    <main>
      <QuantumBackground />
      <Navigation />
      <section id="format-selection" className="subpage-layout" style={{ maxWidth: '1100px', alignItems: 'stretch', textAlign: 'left' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        <div style={{ marginBottom: '2rem' }}>
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.82rem', margin: '0 0 0.75rem', maxWidth: 'none' }}>
            {ru ? 'Процедура выбора' : 'Selection procedure'}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {ru ? 'Как сузить каталог форматов под задачу' : 'How to narrow the format catalogue to a task'}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: '0', maxWidth: 'none' }}>
            {ru
              ? 'Это не автоматический вердикт и не рейтинг. Матрица помогает выбрать набор кандидатов для одного и того же замера: сначала фиксируются задача, данные и устройство, затем сравниваются точность, диапазон, ресурсы и воспроизводимость.'
              : 'This is not an automatic verdict or a ranking. The matrix narrows the candidates for one measurement: fix the task, data and device first, then compare accuracy, range, resources and reproducibility.'}
          </p>
        </div>

        <div className="premium-card" style={{ textAlign: 'left', marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', margin: '0 0 0.75rem' }}>
            {ru ? 'Четыре вопроса перед выбором' : 'Four questions before choosing'}
          </h2>
          <ol style={{ margin: '0', paddingLeft: '1.3rem', display: 'grid', gap: '0.65rem' }}>
            {(ru
              ? ['Что именно кодируется: веса, активации, скоры или аккумуляторы?', 'Какова форма распределения и допустимая ошибка на вашей задаче?', 'Какое устройство ограничивает проект: CPU, GPU или бинарная FPGA AX7203?', 'Какие векторы и независимый оракул позволят повторить результат?']
              : ['What is being encoded: weights, activations, scores or accumulators?', 'What is the distribution and acceptable error for your task?', 'Which device constrains the project: CPU, GPU or the binary AX7203 FPGA?', 'Which vectors and independent oracle will make the result reproducible?']
            ).map((item) => <li key={item} style={{ fontSize: '0.92rem', lineHeight: 1.6 }}>{item}</li>)}
          </ol>
        </div>

        <div style={{ marginBottom: '1.25rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', margin: '0 0 0.65rem' }}>
            {ru ? 'Матрица формат × задача' : 'Format × task matrix'}
          </h2>
          <p style={{ margin: '0', maxWidth: 'none', fontSize: '0.92rem', lineHeight: 1.6 }}>
            {ru
              ? <>В каталоге 83 формата. Ниже — пять отправных кандидатов, а не сокращение каталога: в каждой ячейке указано, какое действие нужно выполнить до вывода.</>
              : <>The catalogue contains 83 formats. Below are five starting candidates, not a reduction of the catalogue: each cell states what to do before drawing a conclusion.</>}
          </p>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.6rem', margin: '0 0 1rem' }} role="tablist" aria-label={ru ? 'Выбор задачи' : 'Choose a task'}>
          {TASKS.map((item) => (
            <button
              key={item.id}
              type="button"
              role="tab"
              aria-selected={task === item.id}
              onClick={() => setTask(item.id)}
              className={task === item.id ? 'btn' : 'btn secondary'}
              style={{ padding: '0.7rem 1rem', fontSize: '0.85rem' }}
            >
              {ru ? item.ru : item.en}
            </button>
          ))}
        </div>

        <div style={{ overflowX: 'auto', width: '100%', border: '1px solid var(--border)', borderRadius: '12px', marginBottom: '1.25rem' }}>
          <table style={{ width: '100%', minWidth: '900px', borderCollapse: 'collapse', textAlign: 'left' }}>
            <caption style={{ textAlign: 'left', padding: '1rem', color: 'var(--muted)', fontSize: '0.86rem' }}>
              {ru ? <>Фокус сейчас: <strong style={{ color: 'var(--text)' }}>{selectedTask.ru}</strong>. Выбор действия не означает измеренный результат.</> : <>Current focus: <strong style={{ color: 'var(--text)' }}>{selectedTask.en}</strong>. An action label is not a measured result.</>}
            </caption>
            <thead>
              <tr style={{ borderTop: '1px solid var(--border)', borderBottom: '1px solid var(--border)' }}>
                <th scope="col" style={{ padding: '0.85rem 0.75rem', fontSize: '0.84rem', color: 'var(--text)' }}>{ru ? 'Формат' : 'Format'}</th>
                {TASKS.map((item) => (
                  <th key={item.id} scope="col" style={{ padding: '0.85rem 0.75rem', fontSize: '0.84rem', color: task === item.id ? 'var(--accent)' : 'var(--text)', background: task === item.id ? 'rgba(0,255,136,0.06)' : 'transparent' }}>{ru ? item.ru : item.en}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {CANDIDATES.map((candidate) => (
                <tr key={candidate.name} style={{ borderBottom: '1px solid var(--border)', verticalAlign: 'top' }}>
                  <th scope="row" style={{ padding: '0.9rem 0.75rem', minWidth: '130px', color: 'var(--text)', fontSize: '0.92rem' }}>
                    {candidate.name}
                    <span style={{ display: 'block', color: 'var(--muted)', fontWeight: 400, fontSize: '0.82rem', marginTop: '0.25rem' }}>{text(candidate.family)}</span>
                  </th>
                  {TASKS.map((item) => {
                    const cell = candidate.cells[item.id]
                    return (
                      <td key={item.id} style={{ padding: '0.9rem 0.75rem', background: task === item.id ? 'rgba(0,255,136,0.04)' : 'transparent' }}>
                        <span style={{ display: 'inline-block', marginBottom: '0.35rem', color: cell.status === 'start' ? 'var(--accent)' : 'var(--text)', fontSize: '0.82rem', fontWeight: 600 }}>
                          {text(STATUS_LABELS[cell.status])}
                        </span>
                        <span style={{ display: 'block', color: 'var(--muted)', fontSize: '0.84rem', lineHeight: 1.5 }}>{text(cell.text)}</span>
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="premium-card" style={{ textAlign: 'left', marginBottom: '2rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', margin: '0 0 0.75rem' }}>
            {ru ? 'Как читать результат' : 'How to read the result'}
          </h2>
          <p style={{ margin: '0 0 0.85rem', maxWidth: 'none', fontSize: '0.92rem', lineHeight: 1.65 }}>
            {ru
              ? 'Метка «начать здесь» означает удобную первую проверку, а не присвоение формату статуса. «Сравнить» требует одинаковых данных, бюджета и метрики. «Проверить» указывает на риск, который нельзя закрыть одной таблицей.'
              : '“Start here” marks a practical first check, not a status assigned to a format. “Compare” requires the same data, budget and metric. “Check” points to a risk that one table cannot close.'}
          </p>
          <p style={{ margin: '0', maxWidth: 'none', fontSize: '0.92rem', lineHeight: 1.65 }}>
            {ru
              ? 'Итоговый кандидат появляется только после прогона на вашей нагрузке. Публичные аппаратные проверки в этом проекте относятся к бинарной FPGA ALINX AX7203 на Xilinx Artix-7 XC7A200T; они не заменяют замер на другом устройстве.'
              : 'A final candidate appears only after a run on your workload. Public hardware checks in this project target the binary ALINX AX7203 FPGA with a Xilinx Artix-7 XC7A200T; they do not replace a measurement on another device.'}
          </p>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', margin: '0' }}>
          <a href="#/start" className="btn" style={{ padding: '0.75rem 1.25rem', fontSize: '0.86rem' }}>{ru ? 'Запустить проверки' : 'Run the checks'}</a>
          <a href="#/verification" className="btn secondary" style={{ padding: '0.75rem 1.25rem', fontSize: '0.86rem' }}>{ru ? 'Методика FPGA' : 'FPGA method'}</a>
        </div>
      </section>
      <Footer />
    </main>
  )
}
