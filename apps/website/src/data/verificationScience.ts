// What a passing run does and does not establish, with the citation for each.
//
// This exists because "0 mismatches over 170,068 vectors" reads like
// exhaustiveness and is not. Every statement below is bounded, sourced, and
// paired with what it refuses to claim. The refusals are the point: a report
// that only says what it proves is indistinguishable from one that overclaims,
// because the reader cannot see the edge.
//
// The arithmetic in T1 was checked against the rule of three: at N = 1000 and
// C = 95% the exact bound is 0.00299 against the textbook 3/N = 0.00300.

export type Theorem = {
  id: string
  name: string
  statement: string
  /** Worked through with our own numbers, so the reader sees the size of it. */
  worked?: string
  citation: string
  url?: string
  doesNotClaim: string
}

export const THEOREMS: Theorem[] = [
  {
    id: 'T1',
    name: 'A passing run bounds the failure rate; it does not eliminate it',
    statement:
      'For independent random vectors with per-vector failure probability θ, the chance that N vectors all pass is (1−θ)^N. So N passes reject any θ ≥ 1 − (1−C)^(1/N) at confidence C — for small θ, approximately ln(1/(1−C))/N.',
    worked:
      '170,068 passing vectors put the per-vector failure probability below 2.7 × 10⁻⁵ at 99% confidence — about one in 37,000. That is a bound, not a zero.',
    citation: 'Duran & Ntafos, “An Evaluation of Random Testing”, IEEE TSE SE-10(4), 1984',
    url: 'https://doi.org/10.1109/TSE.1984.5010257',
    doesNotClaim:
      'Nothing about correctness. (1−θ)^N is strictly below 1 for every finite N, and the bound is empty without an assumed θ. It also assumes the vectors are independent and drawn from the distribution the design will actually see — a claim about the test generator, not about the design.',
  },
  {
    id: 'T2',
    name: 'Confidence scales with the number of distinguishable behaviours, not with the number of tests',
    statement:
      'Under Valiant’s model the count of passing trials needed for a given confidence grows with K, the number of distinguishable behaviours of the program, and that term dominates the confidence level demanded.',
    citation: 'Hamlet & Taylor, “Partition Testing Does Not Inspire Confidence”, IEEE TSE 16(12), 1990',
    url: 'https://doi.org/10.1109/32.62448',
    doesNotClaim:
      'That a large N is therefore sufficient. The paper exists to describe the gap between “found no failures” and “is correct”, and its numbers are not a table to read a verdict out of.',
  },
  {
    id: 'T3',
    name: 'Reaching N distinct states by random sampling costs about N ln N draws',
    statement:
      'Collecting all N coupon types by uniform sampling with replacement takes N·H_N ≈ N ln N trials in expectation. A run shorter than that has not visited the space it claims to cover, whatever its length looks like.',
    worked:
      '65,536 distinct bins need on the order of 765,000 uniform draws before all of them are expected to have been seen even once.',
    citation: 'Motwani & Raghavan, Randomized Algorithms, CUP 1995, §3.6',
    doesNotClaim:
      'That N ln N draws are sufficient for real RTL. The bound assumes uniform reachability; hardware states reachable only through long, low-probability input sequences are not covered by it at any length.',
  },
  {
    id: 'T4',
    name: 'One random run is a high-variance measurement',
    statement:
      'For a target hit with per-test probability θ, the number of tests to first hit is geometric with mean 1/θ and standard deviation of the same order. A single run’s result therefore carries a spread as large as its own value.',
    citation: 'Arcuri, Iqbal & Briand, “Random Testing: Theoretical Results and Practical Implications”, IEEE TSE 38(2), 2012',
    url: 'https://doi.org/10.1109/TSE.2011.121',
    doesNotClaim:
      'That θ is knowable. For a real corner case θ is exactly the quantity nobody can compute, so this bounds the shape of the uncertainty, not its size.',
  },
  {
    id: 'T5',
    name: 'A coverage figure is not evidence of defect detection',
    statement:
      'Across five large projects and 31,000 generated suites, statement, decision and modified-condition coverage correlated only low-to-moderately with mutation kill score once suite size was controlled for. The asymmetry survives: low coverage is informative, high coverage is not a quality claim.',
    citation: 'Inozemtseva & Holmes, “Coverage Is Not Strongly Correlated with Test Suite Effectiveness”, ICSE 2014',
    url: 'https://doi.org/10.1145/2568225.2568271',
    doesNotClaim:
      'That coverage is useless. The correlation is low-to-moderate, not zero — for one project it reached 0.85. What it forbids is quoting a coverage percentage as if it were a defect-detection rate.',
  },
  {
    id: 'T6',
    name: 'The same holds in hardware, and the metric chosen decides which bugs are reachable at all',
    statement:
      'Hardware coverage metrics — line, branch, expression, FSM state and transition, toggle — have no proven mathematical relationship to design-error detection, and in RTL fuzzing the metric driving the search determines which vulnerability classes can be found at all. A saturated metric proves the metric saturated.',
    citation:
      'Tasiran & Keutzer, “Coverage Metrics for Functional Validation of Hardware Designs”, IEEE Design & Test 18(4), 2001; Saravanan & Pudukotai Dinakarrao, GLSVLSI 2024',
    url: 'https://doi.org/10.1109/54.936247',
    doesNotClaim:
      'A numeric coverage-to-defect correlation for RTL. Neither source provides one; the first is a survey and the second a fuzzing-benchmark analysis.',
  },
  {
    id: 'T7',
    name: 'Mutation score measures observability, which coverage does not',
    statement:
      'Mutation analysis injects a single syntactic change and asks whether the checking apparatus notices. Passing a mutant means the harness reached the code and could see the difference — reachability plus observability, where coverage measures only the first.',
    citation: 'DeMillo, Lipton & Sayward, “Hints on Test Data Selection”, IEEE Computer 11(4), 1978',
    url: 'https://doi.org/10.1109/C-M.1978.218136',
    doesNotClaim:
      'That a high mutation score implies few real defects. Its validity as a proxy rests entirely on the competent-programmer hypothesis and the coupling effect, both stated as hypotheses and neither proved.',
  },
  {
    id: 'T8',
    name: 'A gate is trusted only after it has been shown to fail',
    statement:
      'Each check is run against a fixture carrying exactly one planted defect of that check’s class, and against a clean fixture, in the same job. The check is applied to a customer’s design only if it went red on the planted defect and green on the clean one.',
    worked:
      'Applied to this service’s own tooling: the identifier validation added to the intake was accepted only after rejecting eleven injection strings and accepting six real module names, zero wrong either way.',
    citation: 'Practice, not literature — the estate’s own selftest gate (t27/tools/wp18_selftest_gate.py)',
    doesNotClaim:
      'That the check catches every member of its class. Passing its own planted defect shows the check can go red, nothing more.',
  },
]

export const SCIENCE_INTRO_EN =
  'Every claim in a report is bounded by something, and the bound is worth more than the claim. These are the statements the checks rest on, each with its source and each with what it refuses to say.'

export const SCIENCE_INTRO_RU =
  'Каждое утверждение в отчёте чем-то ограничено, и граница стоит больше самого утверждения. Здесь — то, на чём стоят проверки: с источником и с тем, чего каждая не говорит.'
