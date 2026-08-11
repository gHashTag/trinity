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
  {
    id: 'T9',
    name: 'An oracle that shares the implementation’s assumption cannot detect a fault in that assumption',
    statement:
      'Detection requires the oracle and the implementation to disagree. If both are derived from the same premise, then on every input where that premise is false they are wrong together and therefore agree — so the probability of detecting a fault in the shared premise is exactly zero, whatever the number of test cases. Independence of a checker is not a property of who wrote it; it is a property of what it was derived from.',
    worked:
      'Measured here, twice in one hour. A parser counted flip-flops in the yosys cell histogram assuming the field order is count-then-name. Both fixtures it was checked against were typed out by hand in that same order, so pattern and fixture agreed and the suite was green — while on ubuntu-latest, where the histogram prints name-then-count, it returned 0 for every design in existence. Two real chips holding 17 and 66 flip-flops were reported “purely combinational” by a green pipeline. The fix was not a better pattern: it was throwing away the invented fixtures and capturing real output from both yosys versions.',
    citation: 'Knight & Leveson, “An Experimental Evaluation of the Assumption of Independence in Multiversion Programming”, IEEE TSE SE-12(1), 1986',
    url: 'https://doi.org/10.1109/TSE.1986.6312924',
    doesNotClaim:
      'That independently sourced oracles fail independently. Knight and Leveson’s result is the opposite: 27 separately written versions failed together far more often than independence predicts, because difficulty is a property of the input rather than of the author. Capturing real output removes one shared premise; it does not make an oracle independent in general.',
  },
  {
    id: 'T10',
    name: 'Asserting a value detects faults that asserting a verdict cannot',
    statement:
      'Under the PIE model a fault is observed only if it is Executed, Infects the program state, and Propagates to an observed output. A test that observes only pass-or-fail has collapsed its output alphabet to a single bit, so every infection mapping to the same bit is absorbed and the propagation term falls with it. Asserting the value keeps the alphabet wide enough for the infection to reach the observer.',
    worked:
      'The self-test for this service ran a clean design and a design with a planted latch, and asserted the verdict of each. A flip-flop counter returning 0 for every design on earth satisfied both assertions for weeks: zero flops is not a failure, it prints as “purely combinational”, and the job stayed green. The counter now asserts the number — the clean fixture is one 4-bit register, so the assertion is 4 — and a third job asserts a count deliberately wrong by one, so the assertion itself has been watched failing.',
    citation: 'Voas & Miller, “Software Testability: The New Verification”, IEEE Software 12(3), 1995',
    url: 'https://doi.org/10.1109/52.382180',
    doesNotClaim:
      'That a value assertion makes a test adequate. It widens the observed output; it says nothing about whether the inputs ever execute the faulty path, which is the first of the three conditions and the one no assertion can supply.',
  },
  {
    id: 'T11',
    name: 'When the input space is small enough to enumerate, the bound disappears',
    statement:
      'T1 bounds a failure rate because a sample leaves the untested part of the space unaccounted for. If every element of the space is tested, there is no untested part: the failure rate over that space is measured at zero rather than bounded below some θ, and no confidence level applies. Goodenough and Gerhart call such a criterion reliable and valid — exhaustive enumeration is the one case where both hold trivially.',
    worked:
      'Seven number formats decoded from every code point they have: 16 for a 4-bit format, 64 for a 6-bit one, 256 for an 8-bit one, 65,536 for bfloat16 — 66,448 in total, against an implementation from the JAX project that was written by other people from the same specifications. Six formats agreed on every code point. The seventh disagreed on eight of sixty-four, and “eight of sixty-four” is a count of the whole format, not of a sample of it.',
    citation: 'Goodenough & Gerhart, “Toward a Theory of Test Data Selection”, IEEE TSE SE-1(2), 1975',
    url: 'https://doi.org/10.1109/TSE.1975.6312836',
    doesNotClaim:
      'Anything outside that space. Exhausting a decoder’s 256 inputs says nothing about the design that instantiates it, about sequences of inputs, about synthesis preserving the behaviour, or about the formats the reference implementation does not cover. It also does not scale: one more bit doubles the work, so this argument is available for a decoder and never for a datapath.',
  },
  {
    id: 'T12',
    name: 'A failure that always happens carries no information',
    statement:
      'The self-information of an observed event is −log₂ P. A build that is red on every run has P(red) = 1, so each new red carries −log₂(1) = 0 bits: it cannot distinguish the state of the world before it from the state after. Detection and information are different quantities, and a verification programme measures only the first.',
    worked:
      'Measured on my own chip. A decoder disagreed with the specification on 8 of 64 code points, and three separate tests in that repository reported it — two exhaustive, one against a reference not derived from the RTL — printing the same eight code points every time. Continuous integration ran all three. Continuous integration had been red for six weeks: four runs, four failures, so P(red) = 1 over the whole window and the fifth red was worth nothing. An outside tool found the defect in five minutes, and what it contributed was not a better oracle but a reader.',
    citation: 'Shannon, “A Mathematical Theory of Communication”, Bell System Technical Journal 27, 1948, §1',
    url: 'https://doi.org/10.1002/j.1538-7305.1948.tb01338.x',
    doesNotClaim:
      'That a red build should be silenced or that the tests were at fault — they were correct, exhaustive and independent, which is precisely what makes the case worth stating. Nor does it give a threshold: Shannon’s quantity goes to zero continuously, so there is no run count at which a signal officially stops meaning anything.',
  },
  {
    id: 'T13',
    name: 'A green earned by deleting the check is indistinguishable from a green earned by fixing the defect',
    statement:
      'Make “the build is green” the target and it stops measuring what it measured, because two different actions satisfy it: repairing the code, or removing whatever was failing. The verdict is identical in both cases, so a pass carries evidence only when it is paired with an invariant on how much was checked — a floor on the number of gates that ran, a count of the code points enumerated, a list of the targets built. Without that floor, the cheapest way to a green is always deletion.',
    worked:
      'Faced tonight, on the repository this service is built in. Its build has failed for hundreds of consecutive runs, and three of the remaining causes are executables whose source files exist nowhere. Deleting those three targets would have let the build start — and their own comments say they are built for a Railway deployment, with another step depending on one of them. Fixing the measure would have removed the thing it measured, so they were left failing and named instead. The counter-example is in my own chip’s tooling, where the gate runner asserts a minimum discovered-gate count precisely so that a glob bug cannot quietly run fewer checks and report the same green.',
    citation: 'Campbell, “Assessing the Impact of Planned Social Change”, Evaluation and Program Planning 2(1), 1979; Goodhart 1975',
    url: 'https://doi.org/10.1016/0149-7189(79)90048-X',
    doesNotClaim:
      'That deleting a target is always wrong — dead code should go. It claims only that the build verdict cannot tell you which happened, so the justification has to be carried outside the metric. Nor does it supply the floor: choosing what must not decrease is a judgement about the project, and no theorem provides it.',
  },
  {
    id: 'T14',
    name: 'A check must gate on the change, not on the level',
    statement:
      'Shewhart’s separation of assignable from chance causes is what makes an alarm worth reacting to: a chart signals when a process departs from its own history, not when it is simply far from ideal. A check that fails on chronic pre-existing breakage cannot make that distinction — it reports the same red on the day somebody breaks something as on the thousand days before — so it is ignored, and by T12 it is right to ignore it. The gate belongs on the derivative: what is dangling that was not dangling yesterday.',
    worked:
      'Written for this service’s own repository, whose build names five files that do not exist. Repairing them needs decisions about a deployment that are not mine to make, so a check failing on all five would have been furniture within a week. It fails instead only on paths outside a baseline that records those five with the reason each one is still there — and the baseline can only shrink: a path that has been repaired and left in the file fails too, or the record turns into a list of things that used to be wrong. Both directions were watched going red before it was turned on.',
    citation: 'Shewhart, Economic Control of Quality of Manufactured Product, Van Nostrand 1931; Deming’s common- and special-cause distinction',
    doesNotClaim:
      'That the chronic level is acceptable. A baseline is a record of debt, not a discharge of it, and this one is published with a paragraph per entry saying what decision each is waiting on. Nor does it apply to a check that has never been green: there is no history to depart from, and the first thing to establish is the level.',
  },
]

export const SCIENCE_INTRO_EN =
  'Every claim in a report is bounded by something, and the bound is worth more than the claim. These are the statements the checks rest on, each with its source and each with what it refuses to say.'

export const SCIENCE_INTRO_RU =
  'Каждое утверждение в отчёте чем-то ограничено, и граница стоит больше самого утверждения. Здесь — то, на чём стоят проверки: с источником и с тем, чего каждая не говорит.'
