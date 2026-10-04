'use client'

// The PASSPORT page: the record that must travel with a reported result, and
// the three measured cases from our own work that pay for it.
//
// Two faces of one document, because the working group reads them for different
// reasons: /passport is the record itself (what a reviewer checks), and
// /passport/research is the evidence behind it (what licenses us to propose it).
// Both render src/content/passport.ts and nothing else -- no number is typed in
// this file, and each case names the artefact it came from. The two marks come
// from there as well: they were the one thing this file still spelled out, and
// the prose spelled them out too, so they drifted.
//
// The Queen's shell mounts the same component at ?tab=passport&embed=1, so the
// map, the page and the message to the working group are one text.

import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { useI18n } from '../i18n/context'
import {
  meta, standing, scope, problem, cases, record, anchorNote, MARK,
  practices, cost, questions, withdrawn, type Bi,
} from '../content/passport'
import { systems, survey, limits } from '../content/passportRecords'
import {
  FigureSeparation, FigureArea, FigureFooting, FigureCoverage,
} from '../components/PassportFigures'
import './passport.css'

function useL() {
  const { lang } = useI18n()
  const key = (lang === 'ru' ? 'ru' : 'en') as 'ru' | 'en'
  return { key, L: (v: Bi): string => v[key] ?? v.en }
}

const fade = {
  initial: { opacity: 0, y: 16 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: '-60px' },
  transition: { duration: 0.45, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
}

const T = {
  record: { en: 'The record', ru: 'Запись' },
  research: { en: 'The evidence', ru: 'Свидетельство' },
  standing: { en: 'Standing of this document', ru: 'Статус документа' },
  scope: { en: 'Scope', ru: 'Область' },
  problem: { en: 'The problem', ru: 'Задача' },
  table: { en: 'Minimum record accompanying a reported benchmark result', ru: 'Минимальная запись, сопровождающая опубликованный результат бенчмарка' },
  colField: { en: 'Field', ru: 'Поле' },
  colWhat: { en: 'What is recorded', ru: 'Что записывается' },
  colAbsence: { en: 'What its absence permits', ru: 'Что позволяет его отсутствие' },
  practices: { en: 'Three practices the table implies', ru: 'Три практики, которые следуют из таблицы' },
  cost: { en: 'Cost', ru: 'Цена' },
  questions: { en: 'Open questions for the team', ru: 'Открытые вопросы к группе' },
  cases: { en: 'Three cases, in both directions', ru: 'Три случая, в обе стороны' },
  casesLede: {
    en: 'Two records that lie apart, two that lie together, and one pair that was never comparable. Each is our own failure, found in our own data, and each is why a field exists in the table.',
    ru: 'Две записи, которые лгут врозь, две — которые лгут заодно, и одна пара, которая никогда не была сравнимой. Каждый случай — наш собственный промах, найденный в наших же данных, и каждый — причина, по которой в таблице есть поле.',
  },
  withdrawn: { en: 'Withdrawn from this document', ru: 'Отозвано из этого документа' },
  withdrawnLede: {
    en: 'Numbers this document used to carry and no longer does, kept visible on purpose. A document about provenance that quietly dropped them would be making the same mistake it describes.',
    ru: 'Числа, которые этот документ носил и больше не носит, оставлены на виду намеренно. Документ о происхождении данных, тихо убравший их, совершил бы ровно ту ошибку, которую описывает.',
  },
  source: { en: 'source', ru: 'источник' },
  anchored: { en: 'rests on a measured case that still stands', ru: 'опирается на измеренный случай, который ещё держится' },
  // Kept separate from †: what was withdrawn here is a COUNT, not a case --
  // all three cases still stand. Nothing measured pays for this row, so
  // counting its mark with the others would overstate the footing.
  onWithdrawn: { en: 'rests only on a count this document withdrew', ru: 'опирается только на число, отозванное этим документом' },
  survey: { en: 'Filled for seven published results', ru: 'Заполнено по семи опубликованным результатам' },
  surveyLede: {
    en: 'The last open question asks whether anyone would try filling this record for one real result. Rather than wait for an answer, we filled it — against seven results other people published, five of them neuromorphic parts, one a benchmark framework, and one a control drawn from a body that already operates formal disclosure rules.',
    ru: 'Последний открытый вопрос спрашивает, попробует ли кто-нибудь заполнить эту запись для одного настоящего результата. Вместо того чтобы ждать ответа, мы её заполнили — по семи результатам, опубликованным другими: пять нейроморфных микросхем, один бенчмарк-фреймворк и один контроль из организации, которая уже применяет формальные правила раскрытия.',
  },
  sources: { en: 'The seven records, and where each was read', ru: 'Семь записей и где каждая прочитана' },
  limits: { en: 'What this does not establish', ru: 'Чего это не устанавливает' },
}

export default function Passport({ face = 'record' }: { face?: 'record' | 'research' }) {
  const { L, key } = useL()

  return (
    <main className="pp">
      <div className="pp-wrap">
        <motion.header {...fade} className="pp-head">
          <p className="pp-eyebrow">{L(meta.venue)}</p>
          <h1>{L(meta.title)}</h1>
          <p className="pp-sub">{L(meta.subtitle)}</p>
          <p className="pp-by">{meta.author}</p>
          <p className="pp-status">
            <span className="pp-chip">{meta.submitted}</span>
            <span className="pp-chip pp-chip-warn">{L(meta.status)}</span>
          </p>
          <nav className="pp-faces">
            <Link to="/passport" className={face === 'record' ? 'is-on' : undefined}>{L(T.record)}</Link>
            <Link to="/passport/research" className={face === 'research' ? 'is-on' : undefined}>{L(T.research)}</Link>
          </nav>
        </motion.header>

        {/* Both faces open on the limits, so that neither can be read without them. */}
        <motion.section {...fade} className="pp-sec">
          <h2>{L(T.standing)}</h2>
          <ol className="pp-standing">
            {standing.map((s) => (
              <li key={s.n}>
                <strong>{L(s.h)}</strong>
                <p>{L(s.b)}</p>
              </li>
            ))}
          </ol>
          <p className="pp-scope"><strong>{L(T.scope)}. </strong>{L(scope)}</p>
        </motion.section>

        {face === 'record' ? (
          <>
            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.problem)}</h2>
              {problem.map((p, i) => <p key={i}>{L(p)}</p>)}
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.table)}</h2>
              <div className="pp-scroll">
                <table className="pp-table">
                  <thead>
                    <tr>
                      <th scope="col">{L(T.colField)}</th>
                      <th scope="col">{L(T.colWhat)}</th>
                      <th scope="col">{L(T.colAbsence)}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {record.map((r) => {
                      // Two marks, not one: a field whose only case was withdrawn
                      // is still anchored to something, but not to something that
                      // still stands, and the table should not hide the difference.
                      const onWithdrawn = r.anchoredTo.length > 0 && r.anchoredTo.every((a) => a === 'withdrawn')
                      return (
                        <tr key={r.field.en}>
                          <th scope="row">
                            {L(r.field)}
                            {r.anchoredTo.length > 0 && (
                              <abbr title={L(onWithdrawn ? T.onWithdrawn : T.anchored)}> {onWithdrawn ? MARK.onWithdrawn : MARK.anchored}</abbr>
                            )}
                          </th>
                          <td>{L(r.what)}</td>
                          <td className="pp-absence">{L(r.absence)}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              <p className="pp-note">{L(anchorNote)}</p>
              <FigureFooting lang={key} />
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.survey)}</h2>
              <p className="pp-lede">{L(T.surveyLede)}</p>
              <FigureCoverage lang={key} />
              {survey.map((s) => (
                <div key={s.h.en} className="pp-practice">
                  <strong>{L(s.h)}</strong>
                  <p>{L(s.b)}</p>
                </div>
              ))}

              <h3 className="pp-subh">{L(T.sources)}</h3>
              <ul className="pp-sources">
                {systems.map((s) => (
                  <li key={s.label} className={s.control ? 'is-control' : undefined}>
                    <strong>{L(s.full)}</strong>
                    <p>{L(s.headline)}</p>
                    <p className="pp-case-src">
                      {L(T.source)}: {L(s.source)}{' '}
                      <a href={s.url} target="_blank" rel="noreferrer noopener">{s.url}</a>
                    </p>
                  </li>
                ))}
              </ul>

              <h3 className="pp-subh">{L(T.limits)}</h3>
              <p className="pp-note">{L(limits)}</p>
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.practices)}</h2>
              {practices.map((p) => (
                <div key={p.h.en} className="pp-practice">
                  <strong>{L(p.h)}</strong>
                  <p>{L(p.b)}</p>
                </div>
              ))}
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.cost)}</h2>
              {cost.map((c, i) => <p key={i}>{L(c)}</p>)}
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.questions)}</h2>
              <ol className="pp-questions">
                {questions.map((q, i) => <li key={i}>{L(q)}</li>)}
              </ol>
            </motion.section>
          </>
        ) : (
          <>
            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.cases)}</h2>
              <p className="pp-lede">{L(T.casesLede)}</p>
              {cases.map((c, i) => (
                <div key={c.n}>
                  <article className="pp-case">
                    <header>
                      <span className="pp-case-n">{c.n}</span>
                      <span className="pp-chip pp-chip-kind">{L(c.kind)}</span>
                      <h3>{L(c.title)}</h3>
                    </header>
                    <p className="pp-case-setup">{L(c.setup)}</p>
                    <p className="pp-case-finding">{L(c.finding)}</p>
                    <p className="pp-case-moral">{L(c.moral)}</p>
                    <p className="pp-case-src">{L(T.source)}: {c.source}</p>
                  </article>
                  {/* Figure 1 plots cases 1 and 2 together, so it follows the second
                      of them; figure 2 belongs to case 3 alone and follows it. */}
                  {i === 1 && <FigureSeparation lang={key} />}
                  {i === 2 && <FigureArea lang={key} />}
                </div>
              ))}
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.withdrawn)}</h2>
              <p className="pp-lede">{L(T.withdrawnLede)}</p>
              {withdrawn.map((w, i) => (
                <div key={i} className="pp-withdrawn">
                  <strong>{L(w.claim)}</strong>
                  <p>{L(w.why)}</p>
                </div>
              ))}
            </motion.section>

            <motion.section {...fade} className="pp-sec">
              <h2>{L(T.questions)}</h2>
              <ol className="pp-questions">
                {questions.map((q, i) => <li key={i}>{L(q)}</li>)}
              </ol>
            </motion.section>
          </>
        )}

        <footer className="pp-foot">
          <Link to="/queen?tab=passport">{key === 'ru' ? '← на карту' : '← to the map'}</Link>
        </footer>
      </div>
    </main>
  )
}
