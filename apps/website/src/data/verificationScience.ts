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
  nameRu?: string
  statement: string
  statementRu?: string
  /** Worked through with our own numbers, so the reader sees the size of it. */
  worked?: string
  workedRu?: string
  citation: string
  url?: string
  doesNotClaim: string
  doesNotClaimRu?: string
}

export const THEOREMS: Theorem[] = [
  {
    id: 'T1',
    name: 'A passing run bounds the failure rate; it does not eliminate it',
    nameRu: 'Успешный прогон ограничивает частоту отказов, но не устраняет её',
    statement:
      'For independent random vectors with per-vector failure probability θ, the chance that N vectors all pass is (1−θ)^N. So N passes reject any θ ≥ 1 − (1−C)^(1/N) at confidence C — for small θ, approximately ln(1/(1−C))/N.',
    statementRu:
      'Для независимых случайных векторов с вероятностью отказа на вектор θ вероятность того, что все N векторов пройдут успешно, равна (1−θ)^N. Следовательно, N успешных прохождений отвергают любое θ ≥ 1 − (1−C)^(1/N) с доверительной вероятностью C — для малых θ приблизительно ln(1/(1−C))/N.',
    worked:
      '170,068 passing vectors put the per-vector failure probability below 2.7 × 10⁻⁵ at 99% confidence — about one in 37,000. That is a bound, not a zero.',
    workedRu:
      '170,068 успешно пройденных векторов дают вероятность отказа на вектор ниже 2.7 × 10⁻⁵ при доверительной вероятности 99% — примерно один случай на 37,000. Это граница, а не ноль.',
    citation: 'Duran & Ntafos, “An Evaluation of Random Testing”, IEEE TSE SE-10(4), 1984',
    url: 'https://doi.org/10.1109/TSE.1984.5010257',
    doesNotClaim:
      'Nothing about correctness. (1−θ)^N is strictly below 1 for every finite N, and the bound is empty without an assumed θ. It also assumes the vectors are independent and drawn from the distribution the design will actually see — a claim about the test generator, not about the design.',
    doesNotClaimRu:
      'Ничего о корректности. (1−θ)^N строго меньше 1 для любого конечного N, а без предполагаемого θ граница пуста. Также предполагается, что векторы независимы и взяты из распределения, которое проект действительно увидит, — это утверждение о генераторе тестов, а не о проекте.',
  },
  {
    id: 'T2',
    name: 'Confidence scales with the number of distinguishable behaviours, not with the number of tests',
    nameRu: 'Доверительная вероятность масштабируется с числом различимых поведений, а не с числом тестов',
    statement:
      'Under Valiant’s model the count of passing trials needed for a given confidence grows with K, the number of distinguishable behaviours of the program, and that term dominates the confidence level demanded.',
    statementRu:
      'В модели Valiant число успешных испытаний, нужных для заданной доверительной вероятности, растёт с K, числом различимых поведений программы, и этот член доминирует над требуемым уровнем доверия.',
    citation: 'Hamlet & Taylor, “Partition Testing Does Not Inspire Confidence”, IEEE TSE 16(12), 1990',
    url: 'https://doi.org/10.1109/32.62448',
    doesNotClaim:
      'That a large N is therefore sufficient. The paper exists to describe the gap between “found no failures” and “is correct”, and its numbers are not a table to read a verdict out of.',
    doesNotClaimRu:
      'Что поэтому достаточно большого N. Статья описывает разрыв между «не найдено отказов» и «корректно», а её числа не являются таблицей, из которой можно получить вердикт.',
  },
  {
    id: 'T3',
    name: 'Reaching N distinct states by random sampling costs about N ln N draws',
    nameRu: 'Достижение N различных состояний случайной выборкой требует около N ln N извлечений',
    statement:
      'Collecting all N coupon types by uniform sampling with replacement takes N·H_N ≈ N ln N trials in expectation. A run shorter than that has not visited the space it claims to cover, whatever its length looks like.',
    statementRu:
      'Сбор всех N типов купонов равномерной выборкой с возвращением требует в среднем N·H_N ≈ N ln N испытаний. Более короткий прогон не посетил пространство, которое заявляет покрыть, независимо от того, какой длины он выглядит.',
    worked:
      '65,536 distinct bins need on the order of 765,000 uniform draws before all of them are expected to have been seen even once.',
    workedRu:
      'Для 65,536 различных корзин нужно порядка 765,000 равномерных извлечений, прежде чем ожидается, что каждая из них была замечена хотя бы раз.',
    citation: 'Motwani & Raghavan, Randomized Algorithms, CUP 1995, §3.6',
    doesNotClaim:
      'That N ln N draws are sufficient for real RTL. The bound assumes uniform reachability; hardware states reachable only through long, low-probability input sequences are not covered by it at any length.',
    doesNotClaimRu:
      'Что N ln N извлечений достаточны для реального RTL. Граница предполагает равномерную достижимость; состояния аппаратуры, достижимые только через длинные входные последовательности с малой вероятностью, не покрываются ею ни при какой длине.',
  },
  {
    id: 'T4',
    name: 'One random run is a high-variance measurement',
    nameRu: 'Один случайный прогон — измерение с высокой дисперсией',
    statement:
      'For a target hit with per-test probability θ, the number of tests to first hit is geometric with mean 1/θ and standard deviation of the same order. A single run’s result therefore carries a spread as large as its own value.',
    statementRu:
      'Для целевого попадания с вероятностью на тест θ число тестов до попадания имеет геометрическое распределение со средним 1/θ и стандартным отклонением того же порядка. Поэтому результат одного прогона имеет разброс такой же величины, как и его собственное значение.',
    citation: 'Arcuri, Iqbal & Briand, “Random Testing: Theoretical Results and Practical Implications”, IEEE TSE 38(2), 2012',
    url: 'https://doi.org/10.1109/TSE.2011.121',
    doesNotClaim:
      'That θ is knowable. For a real corner case θ is exactly the quantity nobody can compute, so this bounds the shape of the uncertainty, not its size.',
    doesNotClaimRu:
      'Что θ известно. Для реального граничного случая θ — именно та величина, которую никто не может вычислить, поэтому это ограничивает форму неопределённости, а не её размер.',
  },
  {
    id: 'T5',
    name: 'A coverage figure is not evidence of defect detection',
    nameRu: 'Показатель покрытия не является доказательством обнаружения дефектов',
    statement:
      'Across five large projects and 31,000 generated suites, statement, decision and modified-condition coverage correlated only low-to-moderately with mutation kill score once suite size was controlled for. The asymmetry survives: low coverage is informative, high coverage is not a quality claim.',
    statementRu:
      'В пяти крупных проектах и 31,000 сгенерированных наборах покрытие операторов, решений и модифицированных условий лишь слабо или умеренно коррелировало с оценкой уничтожения мутантов после контроля размера набора. Асимметрия сохраняется: низкое покрытие информативно, высокое покрытие не является утверждением о качестве.',
    citation: 'Inozemtseva & Holmes, “Coverage Is Not Strongly Correlated with Test Suite Effectiveness”, ICSE 2014',
    url: 'https://doi.org/10.1145/2568225.2568271',
    doesNotClaim:
      'That coverage is useless. The correlation is low-to-moderate, not zero — for one project it reached 0.85. What it forbids is quoting a coverage percentage as if it were a defect-detection rate.',
    doesNotClaimRu:
      'Что покрытие бесполезно. Корреляция низкая или умеренная, а не нулевая — в одном проекте она достигла 0.85. Запрещено лишь приводить процент покрытия так, как если бы это была частота обнаружения дефектов.',
  },
  {
    id: 'T6',
    name: 'The same holds in hardware, and the metric chosen decides which bugs are reachable at all',
    nameRu: 'То же верно для аппаратуры, а выбранная метрика определяет, какие ошибки вообще достижимы',
    statement:
      'Hardware coverage metrics — line, branch, expression, FSM state and transition, toggle — have no proven mathematical relationship to design-error detection, and in RTL fuzzing the metric driving the search determines which vulnerability classes can be found at all. A saturated metric proves the metric saturated.',
    statementRu:
      'Метрики покрытия аппаратуры — строк, ветвей, выражений, состояний и переходов FSM, переключений — не имеют доказанной математической связи с обнаружением ошибок проекта, а в RTL-фаззинге метрика, направляющая поиск, определяет, какие классы уязвимостей вообще могут быть найдены. Насыщенная метрика доказывает насыщение метрики.',
    citation:
      'Tasiran & Keutzer, “Coverage Metrics for Functional Validation of Hardware Designs”, IEEE Design & Test 18(4), 2001; Saravanan & Pudukotai Dinakarrao, GLSVLSI 2024',
    url: 'https://doi.org/10.1109/54.936247',
    doesNotClaim:
      'A numeric coverage-to-defect correlation for RTL. Neither source provides one; the first is a survey and the second a fuzzing-benchmark analysis.',
    doesNotClaimRu:
      'Численную корреляцию покрытия и дефектов для RTL. Ни один источник её не приводит; один является обзором, другой — анализом бенчмарка фаззинга.',
  },
  {
    id: 'T7',
    name: 'Mutation score measures observability, which coverage does not',
    nameRu: 'Мутационная оценка измеряет наблюдаемость, чего покрытие не измеряет',
    statement:
      'Mutation analysis injects a single syntactic change and asks whether the checking apparatus notices. Passing a mutant means the harness reached the code and could see the difference — reachability plus observability, where coverage measures only the first.',
    statementRu:
      'Мутационный анализ вносит одно синтаксическое изменение и спрашивает, замечает ли его аппарат проверки. Прохождение мутанта означает, что тестовая обвязка достигла кода и могла увидеть различие, — достижимость плюс наблюдаемость, тогда как покрытие измеряет только достижимость.',
    citation: 'DeMillo, Lipton & Sayward, “Hints on Test Data Selection”, IEEE Computer 11(4), 1978',
    url: 'https://doi.org/10.1109/C-M.1978.218136',
    doesNotClaim:
      'That a high mutation score implies few real defects. Its validity as a proxy rests entirely on the competent-programmer hypothesis and the coupling effect, both stated as hypotheses and neither proved.',
    doesNotClaimRu:
      'Что высокая мутационная оценка означает малое число реальных дефектов. Её состоятельность как прокси целиком опирается на гипотезу компетентного программиста и эффект связи; оба сформулированы как гипотезы и не доказаны.',
  },
  {
    id: 'T8',
    name: 'A gate is trusted only after it has been shown to fail',
    nameRu: 'Гейту доверяют только после того, как показано, что он отказывает',
    statement:
      'Each check is run against a fixture carrying exactly one planted defect of that check’s class, and against a clean fixture, in the same job. The check is applied to a customer’s design only if it went red on the planted defect and green on the clean one.',
    statementRu:
      'Каждая проверка запускается в одном задании как на фикстуре с ровно одним внедрённым дефектом класса этой проверки, так и на чистой фикстуре. Проверка применяется к проекту клиента только если она стала красной на внедрённом дефекте и зелёной на чистой фикстуре.',
    worked:
      'Applied to this service’s own tooling: the identifier validation added to the intake was accepted only after rejecting eleven injection strings and accepting six real module names, zero wrong either way.',
    workedRu:
      'Применено к собственному инструментарию сервиса: добавленная на входе проверка идентификаторов была принята только после отклонения одиннадцати строк инъекции и принятия шести настоящих имён модулей, без ошибок в обоих направлениях.',
    citation: 'Practice, not literature — the estate’s own selftest gate (t27/tools/wp18_selftest_gate.py)',
    doesNotClaim:
      'That the check catches every member of its class. Passing its own planted defect shows the check can go red, nothing more.',
    doesNotClaimRu:
      'Что проверка ловит каждый представитель своего класса. Успешное прохождение её собственного внедрённого дефекта показывает лишь, что проверка может стать красной.',
  },
  {
    id: 'T9',
    name: 'An oracle that shares the implementation’s assumption cannot detect a fault in that assumption',
    nameRu: 'Оракул, разделяющий предпосылку реализации, не может обнаружить отказ в этой предпосылке',
    statement:
      'Detection requires the oracle and the implementation to disagree. If both are derived from the same premise, then on every input where that premise is false they are wrong together and therefore agree — so the probability of detecting a fault in the shared premise is exactly zero, whatever the number of test cases. Independence of a checker is not a property of who wrote it; it is a property of what it was derived from.',
    statementRu:
      'Для обнаружения оракул и реализация должны расходиться. Если оба выведены из одной предпосылки, то на каждом входе, где эта предпосылка ложна, они ошибаются вместе и потому совпадают — следовательно, вероятность обнаружить отказ в общей предпосылке в точности равна нулю, независимо от числа тестовых случаев. Независимость проверяющего не является свойством того, кто его написал; это свойство того, из чего он выведен.',
    worked:
      'Measured here, twice in one hour. A parser counted flip-flops in the yosys cell histogram assuming the field order is count-then-name. Both fixtures it was checked against were typed out by hand in that same order, so pattern and fixture agreed and the suite was green — while on ubuntu-latest, where the histogram prints name-then-count, it returned 0 for every design in existence. Two real chips holding 17 and 66 flip-flops were reported “purely combinational” by a green pipeline. The fix was not a better pattern: it was throwing away the invented fixtures and capturing real output from both yosys versions.',
    workedRu:
      'Измерено здесь дважды за один час. Парсер считал триггеры в гистограмме ячеек yosys, предполагая порядок полей «количество, затем имя». Обе фикстуры для проверки были вручную набраны в том же порядке, поэтому шаблон и фикстура совпали, а набор стал зелёным; при этом на ubuntu-latest, где гистограмма выводит «имя, затем количество», он возвращал 0 для каждого существующего проекта. Два реальных экземпляра с 17 и 66 триггерами были названы зелёным конвейером «чисто комбинационными». Исправлением был не более удачный шаблон, а отказ от вымышленных фикстур и захват реального вывода обеих версий yosys.',
    citation: 'Knight & Leveson, “An Experimental Evaluation of the Assumption of Independence in Multiversion Programming”, IEEE TSE SE-12(1), 1986',
    url: 'https://doi.org/10.1109/TSE.1986.6312924',
    doesNotClaim:
      'That independently sourced oracles fail independently. Knight and Leveson’s result is the opposite: 27 separately written versions failed together far more often than independence predicts, because difficulty is a property of the input rather than of the author. Capturing real output removes one shared premise; it does not make an oracle independent in general.',
    doesNotClaimRu:
      'Что оракулы из независимых источников отказывают независимо. Результат Knight и Leveson противоположен: 27 отдельно написанных версий отказывали вместе значительно чаще, чем предсказывает независимость, потому что сложность является свойством входа, а не автора. Захват реального вывода устраняет одну общую предпосылку; в общем случае он не делает оракул независимым.',
  },
  {
    id: 'T10',
    name: 'Asserting a value detects faults that asserting a verdict cannot',
    nameRu: 'Проверка значения обнаруживает отказы, которые проверка вердикта обнаружить не может',
    statement:
      'Under the PIE model a fault is observed only if it is Executed, Infects the program state, and Propagates to an observed output. A test that observes only pass-or-fail has collapsed its output alphabet to a single bit, so every infection mapping to the same bit is absorbed and the propagation term falls with it. Asserting the value keeps the alphabet wide enough for the infection to reach the observer.',
    statementRu:
      'В модели PIE отказ наблюдается, только если он выполняется (Executed), заражает состояние программы (Infects) и распространяется на наблюдаемый выход (Propagates). Тест, наблюдающий только успех или отказ, свёл свой выходной алфавит к одному биту, поэтому каждое заражение, отображаемое в тот же бит, поглощается, и вместе с ним уменьшается член распространения. Проверка значения сохраняет алфавит достаточно широким, чтобы заражение дошло до наблюдателя.',
    worked:
      'The self-test for this service ran a clean design and a design with a planted latch, and asserted the verdict of each. A flip-flop counter returning 0 for every design on earth satisfied both assertions for weeks: zero flops is not a failure, it prints as “purely combinational”, and the job stayed green. The counter now asserts the number — the clean fixture is one 4-bit register, so the assertion is 4 — and a third job asserts a count deliberately wrong by one, so the assertion itself has been watched failing.',
    workedRu:
      'Самопроверка этого сервиса запускала чистый проект и проект с внедрённой защёлкой и проверяла вердикт каждого. Счётчик триггеров, возвращавший 0 для каждого существующего проекта, неделями удовлетворял обеим проверкам: ноль триггеров не является отказом, выводится как «чисто комбинационный», и задание оставалось зелёным. Теперь счётчик проверяет число: чистая фикстура содержит один 4-битный регистр, поэтому проверяется 4; третье задание проверяет число, намеренно ошибочное на единицу, так что сама проверка наблюдалась отказывающей.',
    citation: 'Voas & Miller, “Software Testability: The New Verification”, IEEE Software 12(3), 1995',
    url: 'https://doi.org/10.1109/52.382180',
    doesNotClaim:
      'That a value assertion makes a test adequate. It widens the observed output; it says nothing about whether the inputs ever execute the faulty path, which is the first of the three conditions and the one no assertion can supply.',
    doesNotClaimRu:
      'Что проверка значения делает тест достаточным. Она расширяет наблюдаемый выход; она ничего не говорит о том, выполняют ли входы когда-либо ошибочный путь, а это одно из трёх условий и то, которое никакая проверка предоставить не может.',
  },
  {
    id: 'T11',
    name: 'When the input space is small enough to enumerate, the bound disappears',
    nameRu: 'Когда входное пространство достаточно мало для перечисления, граница исчезает',
    statement:
      'T1 bounds a failure rate because a sample leaves the untested part of the space unaccounted for. If every element of the space is tested, there is no untested part: the failure rate over that space is measured at zero rather than bounded below some θ, and no confidence level applies. Goodenough and Gerhart call such a criterion reliable and valid — exhaustive enumeration is the one case where both hold trivially.',
    statementRu:
      'T1 ограничивает частоту отказов, поскольку выборка оставляет непроверенную часть пространства неучтённой. Если проверен каждый элемент пространства, непроверенной части нет: частота отказов в этом пространстве измерена как нулевая, а не ограничена снизу некоторым θ, и уровень доверия неприменим. Goodenough и Gerhart называют такой критерий надёжным и валидным — исчерпывающее перечисление является случаем, где оба свойства выполняются тривиально.',
    worked:
      'Seven number formats decoded from every code point they have: 16 for a 4-bit format, 64 for a 6-bit one, 256 for an 8-bit one, 65,536 for bfloat16 — 66,448 in total, against an implementation from the JAX project that was written by other people from the same specifications. Six formats agreed on every code point. The seventh disagreed on eight of sixty-four, and “eight of sixty-four” is a count of the whole format, not of a sample of it.',
    workedRu:
      'Семь числовых форматов были декодированы из каждой имеющейся у них кодовой точки: 16 для 4-битного формата, 64 для 6-битного, 256 для 8-битного, 65,536 для bfloat16 — всего 66,448; сравнение шло с реализацией проекта JAX, написанной другими людьми по тем же спецификациям. Шесть форматов совпали на каждой кодовой точке. Седьмой расходился на восьми из шестидесяти четырёх, и «восемь из шестидесяти четырёх» — это число по всему формату, а не по его выборке.',
    citation: 'Goodenough & Gerhart, “Toward a Theory of Test Data Selection”, IEEE TSE SE-1(2), 1975',
    url: 'https://doi.org/10.1109/TSE.1975.6312836',
    doesNotClaim:
      'Anything outside that space. Exhausting a decoder’s 256 inputs says nothing about the design that instantiates it, about sequences of inputs, about synthesis preserving the behaviour, or about the formats the reference implementation does not cover. It also does not scale: one more bit doubles the work, so this argument is available for a decoder and never for a datapath.',
    doesNotClaimRu:
      'Ничего вне этого пространства. Исчерпание 256 входов декодера ничего не говорит о проекте, который его инстанцирует, о последовательностях входов, о сохранении поведения синтезом или о форматах, которых не охватывает эталонная реализация. Это также не масштабируется: добавление одного бита удваивает работу, поэтому этот аргумент доступен для декодера и недоступен для тракта данных.',
  },
  {
    id: 'T12',
    name: 'A failure that always happens carries no information',
    nameRu: 'Отказ, происходящий всегда, не несёт информации',
    statement:
      'The self-information of an observed event is −log₂ P. A build that is red on every run has P(red) = 1, so each new red carries −log₂(1) = 0 bits: it cannot distinguish the state of the world before it from the state after. Detection and information are different quantities, and a verification programme measures only the first.',
    statementRu:
      'Собственная информация наблюдаемого события равна −log₂ P. Сборка, красная при каждом прогоне, имеет P(red) = 1, поэтому каждая новая красная несёт −log₂(1) = 0 бит: она не может различить состояние мира до неё и после неё. Обнаружение и информация — разные величины, и программа верификации измеряет только обнаружение.',
    worked:
      'Measured on my own chip. A decoder disagreed with the specification on 8 of 64 code points, and three separate tests in that repository reported it — two exhaustive, one against a reference not derived from the RTL — printing the same eight code points every time. Continuous integration ran all three. Continuous integration had been red for six weeks: four runs, four failures, so P(red) = 1 over the whole window and the fifth red was worth nothing. An outside tool found the defect in five minutes, and what it contributed was not a better oracle but a reader.',
    workedRu:
      'Измерено в собственной реализации. Декодер расходился со спецификацией на 8 из 64 кодовых точек, и три отдельные проверки в том репозитории сообщали об этом — две исчерпывающие, одна против эталона, не выведенного из RTL, — каждый раз выводя те же восемь кодовых точек. Непрерывная интеграция запускала все три. Непрерывная интеграция оставалась красной шесть недель: четыре прогона, четыре отказа, поэтому P(red) = 1 на всём окне, и пятая красная ничего не стоила. Внешний инструмент нашёл дефект за пять минут; его вкладом был не иной оракул, а читатель.',
    citation: 'Shannon, “A Mathematical Theory of Communication”, Bell System Technical Journal 27, 1948, §1',
    url: 'https://doi.org/10.1002/j.1538-7305.1948.tb01338.x',
    doesNotClaim:
      'That a red build should be silenced or that the tests were at fault — they were correct, exhaustive and independent, which is precisely what makes the case worth stating. Nor does it give a threshold: Shannon’s quantity goes to zero continuously, so there is no run count at which a signal officially stops meaning anything.',
    doesNotClaimRu:
      'Что красную сборку следует заглушить или что тесты были ошибочны — они были корректны, исчерпывающи и независимы, именно поэтому случай стоит изложить. Также это не задаёт порог: величина Shannon непрерывно стремится к нулю, поэтому нет числа прогонов, при котором сигнал официально перестаёт что-либо значить.',
  },
  {
    id: 'T13',
    name: 'A green earned by deleting the check is indistinguishable from a green earned by fixing the defect',
    nameRu: 'Зелёный результат, полученный удалением проверки, неотличим от зелёного результата, полученного исправлением дефекта',
    statement:
      'Make “the build is green” the target and it stops measuring what it measured, because two different actions satisfy it: repairing the code, or removing whatever was failing. The verdict is identical in both cases, so a pass carries evidence only when it is paired with an invariant on how much was checked — a floor on the number of gates that ran, a count of the code points enumerated, a list of the targets built. Without that floor, the cheapest way to a green is always deletion.',
    statementRu:
      'Если сделать целью «сборка зелёная», она перестаёт измерять то, что измеряла, поскольку её удовлетворяют два разных действия: исправление кода или удаление того, что отказывало. Вердикт в обоих случаях одинаков, поэтому успешный результат несёт свидетельство лишь вместе с инвариантом объёма проверенного: нижней границей числа запущенных гейтов, числом перечисленных кодовых точек, списком собранных целей. Без этой нижней границы самым дешёвым путём к зелёному результату всегда является удаление.',
    worked:
      'Faced tonight, on the repository this service is built in. Its build has failed for hundreds of consecutive runs, and three of the remaining causes are executables whose source files exist nowhere. Deleting those three targets would have let the build start — and their own comments say they are built for a Railway deployment, with another step depending on one of them. Fixing the measure would have removed the thing it measured, so they were left failing and named instead. The counter-example is in my own chip’s tooling, where the gate runner asserts a minimum discovered-gate count precisely so that a glob bug cannot quietly run fewer checks and report the same green.',
    workedRu:
      'Зафиксировано сегодня в репозитории, в котором собран этот сервис. Его сборка отказывает сотни последовательных прогонов, и три оставшиеся причины — исполняемые файлы, исходников которых нигде нет. Удаление этих трёх целей позволило бы запустить сборку; их собственные комментарии говорят, что они собираются для развёртывания Railway, а другой шаг зависит от одной из них. Исправление измерения удалило бы то, что оно измеряло, поэтому причины оставлены отказывающими и названы. Контрпример находится в инструментарии моей реализации: исполнитель гейтов проверяет минимальное число обнаруженных гейтов именно для того, чтобы ошибка glob не могла незаметно запустить меньше проверок и сообщить тот же зелёный результат.',
    citation: 'Campbell, “Assessing the Impact of Planned Social Change”, Evaluation and Program Planning 2(1), 1979; Goodhart 1975',
    url: 'https://doi.org/10.1016/0149-7189(79)90048-X',
    doesNotClaim:
      'That deleting a target is always wrong — dead code should go. It claims only that the build verdict cannot tell you which happened, so the justification has to be carried outside the metric. Nor does it supply the floor: choosing what must not decrease is a judgement about the project, and no theorem provides it.',
    doesNotClaimRu:
      'Что удалять цель всегда неправильно — мёртвый код следует удалять. Утверждается лишь, что вердикт сборки не может сказать, что именно произошло, поэтому обоснование должно находиться вне метрики. Также нижняя граница здесь не задаётся: выбор того, что не должно уменьшаться, является суждением о проекте, и ни одна теорема его не предоставляет.',
  },
  {
    id: 'T14',
    name: 'A check must gate on the change, not on the level',
    nameRu: 'Проверка должна гейтировать изменение, а не уровень',
    statement:
      'Shewhart’s separation of assignable from chance causes is what makes an alarm worth reacting to: a chart signals when a process departs from its own history, not when it is simply far from ideal. A check that fails on chronic pre-existing breakage cannot make that distinction — it reports the same red on the day somebody breaks something as on the thousand days before — so it is ignored, and by T12 it is right to ignore it. The gate belongs on the derivative: what is dangling that was not dangling yesterday.',
    statementRu:
      'Разделение Shewhart назначаемых и случайных причин делает тревогу достойной реакции: карта сигнализирует, когда процесс отклоняется от собственной истории, а не когда он просто далёк от идеала. Проверка, отказывающая на хронической предшествующей поломке, не может провести это различие: она сообщает ту же красную в день, когда кто-то что-то сломал, и в тысячу дней до этого, — поэтому её игнорируют, и по T12 игнорировать её правильно. Гейт должен стоять на производной: на том, что теперь висит без связи, хотя вчера не висело.',
    worked:
      'Written for this service’s own repository, whose build names five files that do not exist. Repairing them needs decisions about a deployment that are not mine to make, so a check failing on all five would have been furniture within a week. It fails instead only on paths outside a baseline that records those five with the reason each one is still there — and the baseline can only shrink: a path that has been repaired and left in the file fails too, or the record turns into a list of things that used to be wrong. Both directions were watched going red before it was turned on.',
    workedRu:
      'Написано для собственного репозитория сервиса, чья сборка называет пять несуществующих файлов. Их исправление требует решений о развёртывании, принимать которые не мне, поэтому проверка, отказывающая на всех пяти, за неделю стала бы фоном. Вместо этого она отказывает только на путях вне базовой линии, которая записывает эти пять и причину, по которой каждый пока существует; базовая линия может только сокращаться: исправленный путь, оставленный в файле, также вызывает отказ, иначе запись превратится в список того, что когда-то было неправильно. Оба направления наблюдались красными до включения проверки.',
    citation: 'Shewhart, Economic Control of Quality of Manufactured Product, Van Nostrand 1931; Deming’s common- and special-cause distinction',
    doesNotClaim:
      'That the chronic level is acceptable. A baseline is a record of debt, not a discharge of it, and this one is published with a paragraph per entry saying what decision each is waiting on. Nor does it apply to a check that has never been green: there is no history to depart from, and the first thing to establish is the level.',
    doesNotClaimRu:
      'Что хронический уровень приемлем. Базовая линия — запись долга, а не его погашение, и эта опубликована с абзацем для каждой записи, где указано, какого решения она ожидает. Это также неприменимо к проверке, которая ещё не была зелёной: нет истории, от которой можно отклониться, и установить следует уровень.',
  },
  {
    id: 'T15',
    name: 'A search that filters before it records can only measure survivors',
    nameRu: 'Поиск, который фильтрует до записи, может измерять только выживших',
    statement:
      'Wald was asked where to armour bombers, given the damage on the aircraft that came back. The answer is the places with no holes, because the planes hit there did not return to be examined — the sample had been filtered by the very event under study. Any detector has the same shape: if the step that discards unusable cases runs before the step that records a hit, the discarded class is unobservable, and the detector will report its absence with perfect confidence.',
    statementRu:
      'Wald спросили, где бронировать бомбардировщики, учитывая повреждения вернувшихся самолётов. Ответ — в местах без пробоин, поскольку самолёты, поражённые там, не вернулись для осмотра: выборка была отфильтрована самим изучаемым событием. Любой детектор имеет ту же форму: если шаг, отбрасывающий непригодные случаи, выполняется до шага, записывающего попадание, отброшенный класс ненаблюдаем, и детектор сообщит о его отсутствии с совершенной уверенностью.',
    worked:
      'Committed here, in a tool written to find files that are missing. It walked imports from every build root and skipped any file it could not open before recording that the file had been reached — so a missing file could never enter the visited set. It answered that nothing reached the module this repository lost, and the eleven files importing that module were written off as dead code. Continuous integration disagreed within the hour: six build roots reach it, one of them the library root. Moving the record above the filter is the entire fix, and five trees with known answers now assert it, including that exact shape.',
    workedRu:
      'Зафиксировано здесь в инструменте для поиска отсутствующих файлов. Он обходил импорты от каждого корня сборки и пропускал файл, который не мог открыть, до записи о достижении файла, поэтому отсутствующий файл никогда не мог попасть в множество посещённых. Он сообщил, что до потерянного этим репозиторием модуля ничего не доходит, а одиннадцать файлов, импортирующих этот модуль, были списаны как мёртвый код. Непрерывная интеграция возразила в течение часа: его достигают шесть корней сборки, один из них — корень библиотеки. Перемещение записи выше фильтра является всем исправлением, и теперь пять деревьев с известными ответами проверяют это, включая именно такую форму.',
    citation: 'Wald, “A Method of Estimating Plane Vulnerability Based on Damage of Survivors”, Statistical Research Group memoranda, Columbia University, 1943',
    doesNotClaim:
      'That every absence is an artefact. Sometimes the thing really is not there — the same corrected walk reports 58 missing files no build root reaches, and that number is as real as the six. What it forbids is reading an absence out of a pipeline that could not have represented the thing in the first place, which is a property of the pipeline and knowable before any data is collected.',
    doesNotClaimRu:
      'Что каждое отсутствие является артефактом. Иногда объекта действительно нет: тот же исправленный обход сообщает о 58 отсутствующих файлах, которых не достигает ни один корень сборки, и это число так же реально, как шесть. Запрещено лишь выводить отсутствие из конвейера, который не мог представить объект, с самого начала; это свойство конвейера и его можно узнать до сбора данных.',
  },
  {
    id: 'T16',
    name: 'An analysis must publish which way it is wrong',
    nameRu: 'Анализ должен публиковать направление своей ошибки',
    statement:
      'A static analysis that decides a non-trivial property of a program is either unsound or imprecise; abstract interpretation makes the choice deliberate by over-approximating, so that every real fault is reported and some reported faults are not real. The choice is respectable and the silence about it is not: a number printed without its direction is read as a count. Sound over-approximation obliges the tool to say “at most this many”, and an under-approximation to say “at least”.',
    statementRu:
      'Статический анализ, решающий нетривиальное свойство программы, либо некорректен, либо неточен; абстрактная интерпретация делает выбор намеренным через надприближение, при котором сообщается о каждом реальном отказе, а некоторые сообщённые отказы не реальны. Этот выбор заслуживает уважения, молчание о нём — нет: число, напечатанное без направления, читается как счёт. Корректное надприближение обязывает инструмент говорить «не более стольких», а недоприближение — «не менее».',
    worked:
      'The build-path checker here walks imports and reports which missing files a build root can reach. Pointed at a repository whose continuous integration is green, it reported two — and both were real imports of files that really are absent. Neither is a fault, because Zig analyses top-level declarations lazily: an import bound to a name nothing references is never loaded. The walk sees imports and cannot see references, so its figure is an upper bound and now prints as one. The same tool reports fourteen for the repository whose build is red, where six were confirmed by the compiler within the hour — the bound is useful precisely because it is labelled.',
    workedRu:
      'Проверяющий пути сборки здесь обходит импорты и сообщает, каких отсутствующих файлов может достичь корень сборки. На репозитории с зелёной непрерывной интеграцией он сообщил два; оба были реальными импортами действительно отсутствующих файлов. Ни один не является отказом, потому что Zig лениво анализирует объявления верхнего уровня: импорт, привязанный к имени, на которое никто не ссылается, никогда не загружается. Обход видит импорты и не видит ссылки, поэтому его число является верхней границей и теперь выводится как таковая. Тот же инструмент сообщает четырнадцать для репозитория с красной сборкой, где шесть были подтверждены компилятором в течение часа; граница полезна именно потому, что помечена.',
    citation: 'Cousot & Cousot, “Abstract Interpretation: A Unified Lattice Model…”, POPL 1977; Rice, Transactions of the AMS 74, 1953',
    url: 'https://doi.org/10.1145/512950.512973',
    doesNotClaim:
      'That an over-approximation is always the right choice. A checker meant to gate a merge can be intolerable at any false-positive rate, and the honest answer there is to narrow the question rather than the labelling. Nor does it make the bound tight: knowing the direction of the error says nothing about its size.',
    doesNotClaimRu:
      'Что надприближение всегда является верным выбором. Проверяющий, предназначенный для гейтирования слияния, может быть неприемлем при любой частоте ложных срабатываний, и честный ответ здесь — сузить вопрос, а не маркировку. Это также не делает границу тесной: знание направления ошибки ничего не говорит о её размере.',
  },
  {
    id: 'T17',
    name: 'A proxy is a measurement only if nothing but the thing itself can move it',
    nameRu: 'Прокси является измерением, только если ничто, кроме самого объекта, не может его изменить',
    statement:
      'Prentice’s condition for replacing an endpoint with a surrogate is that the effect on the real endpoint is captured entirely by the surrogate — anything else that moves the surrogate breaks the substitution, and no amount of correlation repairs it. The same applies to any check written against a symptom rather than the property: it is sound only while the confounds stay still, and it fails in the worst direction, by reporting a fault where the property holds.',
    statementRu:
      'Условие Prentice для замены конечной точки суррогатом состоит в том, что эффект на реальной конечной точке полностью захватывается суррогатом: всё остальное, что изменяет суррогат, нарушает замену, и никакая корреляция этого не исправляет. То же относится к любой проверке, написанной против симптома, а не свойства: она корректна, только пока смешивающие факторы неподвижны, и отказывает в худшем направлении, сообщая об отказе там, где свойство выполняется.',
    worked:
      'The publication gate here refused to let this site go out, on the grounds that every URL in the sitemap carried the same date, therefore the field was not being derived from anything. The field was being derived correctly. This site was published fifteen times in one day, so every file’s last commit genuinely was that day and every date genuinely was identical — a confound moved the proxy without touching the property, and the gate sent me to argue with a correct number. It now asks the repository when each sampled file last changed and requires the sitemap to agree, which is the property it was always about; a fabricated date fails it immediately, and a genuine same-day spread passes because it is genuine.',
    workedRu:
      'Гейт публикации здесь не позволял выпустить сайт, поскольку каждый URL в sitemap имел одну дату, а значит, поле якобы не выводилось ни из чего. Поле выводилось корректно. Этот сайт был опубликован пятнадцать раз за один день, поэтому последний коммит каждого файла действительно был в тот день и каждая дата действительно совпадала: смешивающий фактор изменил прокси, не затронув свойства, и гейт заставил спорить с корректным числом. Теперь он спрашивает репозиторий, когда менялся каждый выбранный файл, и требует совпадения с sitemap, то есть проверяет свойство, о котором всегда шла речь; поддельная дата немедленно вызывает отказ, а настоящий разброс в пределах дня проходит, потому что он настоящий.',
    citation: 'Prentice, “Surrogate Endpoints in Clinical Trials: Definition and Operational Criteria”, Statistics in Medicine 8(4), 1989',
    url: 'https://doi.org/10.1002/sim.4780080407',
    doesNotClaim:
      'That proxies are never worth using. The direct test costs a subprocess per sampled page and the proxy cost one comparison, which is why the proxy was written first and why it survived until a confound arrived. What the theorem forbids is treating the two as interchangeable once the confound is known — and the moment to look for confounds is when the check disagrees with something you can verify by hand.',
    doesNotClaimRu:
      'Что прокси никогда не стоят применения. Прямая проверка требует подпроцесс на каждую выбранную страницу, а прокси — одного сравнения, поэтому прокси написали раньше и он сохранялся до появления смешивающего фактора. Теорема запрещает считать их взаимозаменяемыми, когда смешивающий фактор известен; искать такие факторы следует, когда проверка расходится с тем, что можно проверить вручную.',
  },
  {
    id: 'T18',
    name: 'A repair reaches only the copy it lands in',
    nameRu: 'Исправление достигает только той копии, в которую оно внесено',
    statement:
      'Parnas’s criterion for decomposing a system is that each design decision should have exactly one home, because changeability is what the decomposition is for. The corollary is arithmetic rather than stylistic: a decision living in n places must be repaired n times, the repairs do not propagate, and no instrument inside either copy reports the omission — each one compiles, or fails, entirely on its own. Divergence is therefore not a risk that duplication carries; it is what duplication is.',
    statementRu:
      'Критерий Parnas для декомпозиции системы состоит в том, что каждое проектное решение должно иметь ровно одно место, поскольку изменяемость — цель декомпозиции. Следствие арифметическое, а не стилистическое: решение, существующее в n местах, необходимо исправлять n раз, исправления не распространяются, и ни один инструмент внутри любой копии не сообщает о пропуске — каждая полностью самостоятельно компилируется или отказывает. Расхождение поэтому не является риском, который несёт дублирование; оно и есть дублирование.',
    worked:
      'Sixteen defects were repaired in one package and the consumer that depends on it did not improve by a single error. Not a caching artefact — pinning the exact merge commit produced the same hash the CDN had already served. Both repositories carried their own src/vsa/core.zig, common.zig, concurrency.zig, 10k_vsa.zig, hrr.zig and fpga_bind.zig, edited independently since the migration that separated them, so the fixes went into different files with the same names. Comparing the two public surfaces symbol by symbol showed them identical, one constant apart, which is what made the choice arithmetic instead of a matter of taste: nothing was lost by keeping one. Replacing the duplicates with re-exports of the repaired implementation took the consumer from five errors to green.',
    workedRu:
      'Шестнадцать дефектов были исправлены в одном пакете, а потребитель, зависящий от него, не улучшился ни на одну ошибку. Это не артефакт кэширования: закрепление точного коммита слияния дало тот же хеш, который CDN уже отдал. Оба репозитория содержали собственные src/vsa/core.zig, common.zig, concurrency.zig, 10k_vsa.zig, hrr.zig и fpga_bind.zig, независимо редактируемые после миграции, которая их разделила, поэтому исправления попали в разные файлы с одинаковыми именами. Сравнение двух публичных поверхностей посимвольно показало их идентичность с разницей в одну константу, что сделало выбор арифметическим, а не вопросом вкуса: при сохранении одной ничего не терялось. Замена дублей реэкспортами исправленной реализации перевела потребителя от пяти ошибок к зелёному результату.',
    citation: 'Parnas, “On the Criteria To Be Used in Decomposing Systems into Modules”, CACM 15(12), 1972',
    url: 'https://doi.org/10.1145/361598.361623',
    doesNotClaim:
      'That vendoring is always wrong. A pinned copy is a deliberate trade — insulation from an upstream you do not control, paid for in repairs you now owe twice — and it is defensible when it is chosen and written down. What has no defence is duplication nobody decided on, which is the state a migration leaves behind when it copies rather than moves. Nor does a re-export make the boundary free: names must now be listed one by one, and a symbol added upstream does not appear downstream until somebody adds it.',
    doesNotClaimRu:
      'Что вендоринг всегда неправилен. Закреплённая копия — осознанный обмен: изоляция от вышестоящего источника, который вы не контролируете, оплаченная исправлениями, которые теперь нужно делать дважды; он оправдан, когда выбран и записан. Не имеет оправдания дублирование, о котором никто не решал: это состояние, которое миграция оставляет после копирования вместо перемещения. Реэкспорт также не делает границу бесплатной: имена теперь нужно перечислять по одному, а символ, добавленный выше, не появится ниже, пока кто-то его не добавит.',
  },
  {
    id: 'T19',
    name: 'A check that never executes reports success',
    nameRu: 'Проверка, которая никогда не выполняется, сообщает об успехе',
    statement:
      'A verification result is vacuous when the property holds for a reason unrelated to what it was written to establish — classically, when no witness to the antecedent is ever produced. A vacuous pass and a real pass are identical in the verdict and differ only in an observable the verdict does not carry. Detecting one therefore requires a second measurement: how much was actually exercised.',
    statementRu:
      'Результат верификации пуст, когда свойство выполняется по причине, не связанной с тем, что он должен был установить; классически — когда никогда не порождается свидетель посылки. Пустое успешное прохождение и реальное успешное прохождение идентичны в вердикте и различаются только наблюдаемой величиной, которой вердикт не несёт. Поэтому для обнаружения требуется второе измерение: сколько было фактически выполнено.',
    worked:
      'A package here declared 640 test blocks across 87 files. `zig build test` exited 0. The suite ran zero of them, because every `pub const x = @import("x.zig")` was unreferenced and so never analysed. The exit code was correct and meant nothing. The count — “All 0 tests passed” — is the independent observable; after one reference per import, 254 tests ran and one failed.',
    workedRu:
      'Пакет здесь объявлял 640 блоков тестов в 87 файлах. `zig build test` завершился с 0. Набор выполнил ноль из них, потому что каждый `pub const x = @import("x.zig")` не имел ссылок и поэтому никогда не анализировался. Код завершения был корректен и ничего не значил. Счётчик — «All 0 tests passed» — является независимой наблюдаемой величиной; после добавления по одной ссылки на импорт выполнились 254 теста, и один отказал.',
    citation:
      'Beer, Ben-David, Eisner & Rodeh, “Efficient Detection of Vacuity in ACTL Formulas”, Formal Methods in System Design 18(2), 2001; Kupferman & Vardi, “Vacuity detection in temporal model checking”, STTT 4(2), 2003',
    url: 'https://doi.org/10.1023/A:1008779610539',
    doesNotClaim:
      'That a non-zero test count is sufficient. A suite that runs 254 tests can still be vacuous in the same sense if the assertions never discriminate. The count rules out one specific failure mode — the emptiest one — and no others.',
    doesNotClaimRu:
      'Что ненулевое число тестов достаточно. Набор, выполняющий 254 теста, всё ещё может быть пустым в том же смысле, если проверки никогда не различают случаи. Счётчик исключает один конкретный режим отказа — самый пустой — и никакие другие.',
  },
  {
    id: 'T20',
    name: 'What a build checks is what it can reach, not what is present',
    nameRu: 'Сборка проверяет то, чего может достичь, а не то, что присутствует',
    statement:
      'Under lazy (on-demand) semantic analysis, a top-level declaration is analysed only when something references it. So for any build: checked ⊆ reachable ⊆ present. Code that nothing imports is not weakly checked — it is not checked at all, and errors inside it are indistinguishable from its absence. A consequence that runs against intuition: adding an export is itself an act of verification, because it moves code from “present” to “reachable”.',
    statementRu:
      'При ленивом семантическом анализе по запросу объявление верхнего уровня анализируется только когда на него что-то ссылается. Поэтому для любой сборки: проверенное ⊆ достижимое ⊆ присутствующее. Код, который ничто не импортирует, проверяется не слабо — он не проверяется вовсе, а ошибки внутри него неотличимы от его отсутствия. Следствие, противоречащее интуиции: добавление экспорта само является актом верификации, поскольку перемещает код из «присутствующего» в «достижимое».',
    worked:
      'An unresolvable import — `@import("../../jit_arm64.zig")`, a path that escapes the module root and could not resolve on any machine — sat in a repository whose CI was green for weeks. Nothing exported the file that contained it. Adding one `pub const` made the compiler look, and it failed immediately. The file it wanted was in the same directory.',
    workedRu:
      'Неразрешимый импорт — `@import("../../jit_arm64.zig")`, путь, выходящий за корень модуля и неразрешимый ни на какой машине, — находился в репозитории с зелёным CI неделями. Ничто не экспортировало файл, который его содержал. Добавление одного `pub const` заставило компилятор посмотреть, и он немедленно отказал. Нужный ему файл находился в том же каталоге.',
    citation:
      'Zig Language Reference (0.15.2), lazy analysis of unreferenced declarations; cf. Horwitz, Reps & Sagiv, “Demand interprocedural dataflow analysis”, FSE 1995',
    url: 'https://doi.org/10.1145/222124.222146',
    doesNotClaim:
      'That reachability implies correctness, or that this is a defect in lazy analysis — it is what makes conditional compilation work. It bounds what a green build entitles you to say, nothing more.',
    doesNotClaimRu:
      'Что достижимость означает корректность или что это дефект ленивого анализа: именно это делает условную компиляцию работоспособной. Это ограничивает, что зелёная сборка позволяет утверждать, и ничего больше.',
  },
  {
    id: 'T21',
    name: 'Among divergent copies, the one that compiles is not thereby the authoritative one',
    nameRu: 'Среди расходящихся копий та, что компилируется, от этого не становится авторитетной',
    statement:
      'When a file exists in k copies and each is edited against its own dependencies, “it builds” selects for agreement with the dependency version sitting beside it — not for recency, not for correctness. A stale copy beside an equally stale dependency compiles cleanly; the current copy beside a dependency it has outgrown does not. Authority must be established by provenance, not by exit code.',
    statementRu:
      'Когда файл существует в k копиях и каждая редактируется относительно собственных зависимостей, «он собирается» отбирает согласованность с версией зависимости, лежащей рядом, — не новизну и не корректность. Устаревшая копия рядом со столь же устаревшей зависимостью компилируется чисто; текущая копия рядом с зависимостью, которую она переросла, — нет. Авторитетность должна устанавливаться происхождением, а не кодом завершения.',
    worked:
      'One file existed five times across three repositories. The copy that compiled called a two-argument `dotProduct`; the copy that failed called the three-argument form and unwrapped an optional field. The failing copy was the newer one. Deciding by “which builds” would have propagated the older API in the direction of the newer code.',
    workedRu:
      'Один файл существовал пять раз в трёх репозиториях. Компилирующаяся копия вызывала двухаргументный `dotProduct`; отказывающая копия вызывала трёхаргументную форму и разворачивала необязательное поле. Отказывающая копия была новее. Решение по признаку «что собирается» распространило бы старый API в направлении нового кода.',
    citation:
      'Juergens, Deissenboeck, Hummel & Wagner, “Do code clones matter?”, ICSE 2009',
    url: 'https://doi.org/10.1109/ICSE.2009.5070547',
    doesNotClaim:
      'That the newer copy is right either. Recency is a second bad proxy. The point is only that the build result carries no information about which copy should win, and it is routinely read as if it did.',
    doesNotClaimRu:
      'Что более новая копия также верна. Новизна — другой плохой прокси. Суть лишь в том, что результат сборки не несёт информации о том, какая копия должна победить, хотя его обычно читают так, как если бы нес.',
  },
  {
    id: 'T22',
    name: 'If the reachable range misses the admissible one, no test is needed to refute it',
    nameRu: 'Если достижимый диапазон не пересекается с допустимым, для его опровержения тест не нужен',
    statement:
      'For a function whose image over all admissible inputs can be computed, comparing that image with the specified range is a refutation stronger than any finite test suite: if the two are disjoint, no input passes, and the failure is proved rather than sampled. Where the input domain is a finite structured set the image is often a small finite set, and the check costs no execution at all.',
    statementRu:
      'Для функции, образ которой на всех допустимых входах можно вычислить, сравнение этого образа с заданным диапазоном является опровержением сильнее любого конечного набора тестов: если они не пересекаются, ни один вход не проходит, и отказ доказан, а не выбран по выборке. Когда домен входов является конечным структурированным множеством, образ часто представляет собой малое конечное множество, и проверка не требует выполнения вовсе.',
    worked:
      'A Barbero–Immirzi parameter was computed as |c₄| + |c₅| times φ⁻¹ over the E8 root system. Every E8 root is a permutation of (±1, ±1, 0⁶) or (±½)⁸, so that sum is 0, 1 or 2 and the image is exactly {0.436992, 0.618034, 1.236068}. The physical target is 0.2375. The only value inside the asserted range is the fallback taken when the projection has no input — so the answer is admissible precisely when nothing was projected.',
    workedRu:
      'Параметр Barbero–Immirzi был вычислен как |c₄| + |c₅|, умноженное на φ⁻¹, над корневой системой E8. Каждый корень E8 является перестановкой (±1, ±1, 0⁶) или (±½)⁸, поэтому сумма равна 0, 1 или 2, а образ в точности равен {0.436992, 0.618034, 1.236068}. Физическая цель равна 0.2375. Внутри заявленного диапазона находится лишь запасное значение, взятое, когда проекция не имеет входа; следовательно, ответ допустим именно тогда, когда ничего не проецировалось.',
    citation:
      'Moore, Kearfott & Cloud, “Introduction to Interval Analysis”, SIAM, 2009',
    url: 'https://doi.org/10.1137/1.9780898717716',
    doesNotClaim:
      'That an intersecting range is evidence of anything. Non-emptiness is necessary and nowhere near sufficient: it says a passing input could exist, not that the formula is right.',
    doesNotClaimRu:
      'Что пересекающийся диапазон является свидетельством чего-либо. Непустота необходима и далека от достаточности: она говорит, что успешный вход мог бы существовать, а не что формула верна.',
  },
  {
    id: 'T23',
    name: 'An instrument of the wrong version reports both false alarms and false assurance',
    nameRu: 'Инструмент неподходящей версии сообщает и ложные тревоги, и ложную уверенность',
    statement:
      'A measurement is only interpretable against a stated instrument. When the toolchain used to check differs from the toolchain the artefact targets, the disagreement is not noise around the truth: it is bidirectional. Removed interfaces produce failures that do not exist for the target, and platform defaults produce passes that will not hold for it. Neither direction announces itself.',
    statementRu:
      'Измерение можно интерпретировать только относительно указанного инструмента. Когда цепочка инструментов проверки отличается от цепочки, на которую нацелен артефакт, расхождение не является шумом вокруг истины: оно двунаправленно. Удалённые интерфейсы создают отказы, которых для цели нет, а платформенные значения по умолчанию создают успешные прохождения, не сохраняющиеся для неё. Ни одно направление себя не объявляет.',
    worked:
      'Three times in one session, on the same tree. A local 0.16 toolchain reported failures on `testing.refAllDeclsRecursive` and `std.time.timestamp` — both present in the 0.15.2 the packages target, both removed later. In the other direction, a local macOS run passed code that reaches for the C allocator, which the Linux target rejects with “C allocator is only available when linking against libc”. Two false alarms and one false assurance, from one ruler.',
    workedRu:
      'Трижды за одну сессию на одном дереве. Локальная цепочка инструментов 0.16 сообщала об отказах на `testing.refAllDeclsRecursive` и `std.time.timestamp`; оба присутствуют в 0.15.2, на который нацелены пакеты, и оба были удалены позже. В другом направлении локальный запуск macOS успешно прошёл код, обращающийся к аллокатору C, который Linux-цель отвергает с «C allocator is only available when linking against libc». Две ложные тревоги и одна ложная уверенность от одной линейки.',
    citation:
      'JCGM 100:2008, “Evaluation of measurement data — Guide to the expression of uncertainty in measurement” (GUM), §3.3 on metrological traceability',
    url: 'https://www.bipm.org/documents/20126/2071204/JCGM_100_2008_E.pdf',
    doesNotClaim:
      'That the target toolchain is the truth. It is the stated reference, which is a different and weaker thing: it makes results comparable, not correct.',
    doesNotClaimRu:
      'Что целевая цепочка инструментов является истиной. Это указанная точка отсчёта, а это другое и более слабое утверждение: оно делает результаты сопоставимыми, а не корректными.',
  },
  {
    id: 'T24',
    name: 'A pin that names a moving target and asserts its content is a scheduled failure',
    nameRu: 'Пин, указывающий на движущуюся цель и утверждающий её содержимое, — запланированный отказ',
    statement:
      'A dependency declaration that combines a mutable reference with a content hash is not a pin. The reference keeps moving, the hash keeps asserting, and the two disagree the moment anything is merged upstream. The failure lands at fetch — before a compiler reads a line — so it presents as an unbuildable package rather than as an out-of-date dependency, and nothing downstream can run to report which.',
    statementRu:
      'Объявление зависимости, сочетающее изменяемую ссылку с хешем содержимого, не является пином. Ссылка продолжает двигаться, хеш продолжает утверждать, и они расходятся в момент слияния чего-либо выше. Отказ происходит при получении — до того, как компилятор прочитает строку, — поэтому он выглядит как несобираемый пакет, а не устаревшая зависимость, и ничто ниже не может запуститься и сообщить, что именно.',
    worked:
      'A manifest here declared `archive/refs/heads/main.tar.gz` with `golden_float-0.2.0-h7LKhdEX…` while upstream had reached 2.1.0. It had been broken since the first merge after it was written. I re-pinned it, merged one commit upstream, and broke it again within the hour — which is the proof, not an anecdote. Pinning to a commit tarball ends it.',
    workedRu:
      'Манифест здесь объявлял `archive/refs/heads/main.tar.gz` с `golden_float-0.2.0-h7LKhdEX…`, тогда как вышестоящий источник уже достиг 2.1.0. Он был сломан с начального слияния после записи. Я перепривязал его, слил один коммит выше и снова сломал в течение часа — это доказательство, а не анекдот. Привязка к tarball коммита завершает проблему.',
    citation:
      'Dolstra, “The Purely Functional Software Deployment Model”, PhD thesis, Utrecht, 2006 — content-addressed deployment',
    url: 'https://edolstra.github.io/pubs/phd-thesis.pdf',
    doesNotClaim:
      'That a commit pin is current. It is immutable, which is a different property and the one that makes the build reproducible; staying up to date is a separate job for a separate tool.',
    doesNotClaimRu:
      'Что пин коммита актуален. Он неизменяем, а это другое свойство, именно оно делает сборку воспроизводимой; поддержание актуальности — отдельная работа для отдельного инструмента.',
  },
  {
    id: 'T25',
    name: 'A guard must exercise the same path as the thing it guards',
    nameRu: 'Защитная проверка должна проходить тем же путём, что и объект, который она защищает',
    statement:
      'When a check re-derives its input by a route the build does not take, it stops measuring the artefact and starts measuring its own derivation. The two agree until a configuration difference separates them, and then the guard reports on itself with the confidence it would have had about the subject.',
    statementRu:
      'Когда проверка повторно выводит свой вход маршрутом, которым сборка не идёт, она перестаёт измерять артефакт и начинает измерять собственный вывод. Они совпадают, пока различие конфигурации не разделит их, а затем защитная проверка сообщает о себе с той уверенностью, которую имела бы относительно объекта.',
    worked:
      'A step written to refuse a test suite that runs nothing invoked `zig test src/root.zig` directly, bypassing the `link_libc` the build sets. On Linux that produced “C allocator is only available when linking against libc”, so no count was parsed and the guard declared the suite empty — while the step directly above it had just run the suite green. One invocation, read twice, is the fix.',
    workedRu:
      'Шаг, написанный для отказа от набора тестов, который ничего не запускает, напрямую вызывал `zig test src/root.zig`, обходя `link_libc`, заданный сборкой. В Linux это выдало «C allocator is only available when linking against libc», поэтому число не было разобрано и защитная проверка объявила набор пустым, тогда как шаг прямо над ней только что успешно запустил набор. Одно выполнение, прочитанное дважды, — всё исправление.',
    citation:
      'Beizer, “Software Testing Techniques”, 2nd ed., 1990 — on the test harness as part of the system under test',
    doesNotClaim:
      'That sharing the path makes a guard correct. It removes one failure mode: disagreement between the guard\u2019s environment and the build\u2019s. Everything the guard asserts is still only as good as the assertion.',
    doesNotClaimRu:
      'Что общий путь делает защитную проверку корректной. Он устраняет один режим отказа: расхождение между окружением защитной проверки и окружением сборки. Всё, что утверждает защитная проверка, остаётся верным лишь настолько, насколько верно утверждение.',
  },
  {
    id: 'T26',
    name: 'Success returned by a buffered write is a claim about the buffer',
    nameRu: 'Успех, возвращённый буферизованной записью, является утверждением о буфере',
    statement:
      'A write call that returns without error has committed data to whatever layer accepted it, not necessarily to the medium. Where the interface buffers by default, the last unflushed segment exists only in memory, and the operation that reports success and the operation that loses the data are the same one. The reader is the first component in a position to notice.',
    statementRu:
      'Вызов записи, вернувшийся без ошибки, зафиксировал данные на уровне, который их принял, но не обязательно на носителе. Когда интерфейс по умолчанию буферизует, последний несброшенный сегмент существует только в памяти, и операция, сообщающая об успехе, и операция, теряющая данные, являются одной операцией. Читатель — компонент, который может это заметить.',
    worked:
      'Zig 0.15 made `File.writer` take a buffer. A save routine written against the unbuffered interface still compiled after the type changed and still returned success, but the tail of every file stayed in memory — so `save()` reported writing a graph that `load()` could not read. An explicit flush before close is the whole fix, and nothing in the type system asked for it.',
    workedRu:
      'Zig 0.15 сделал так, что `File.writer` принимает буфер. Процедура сохранения, написанная для неб уферизованного интерфейса, продолжила компилироваться после изменения типа и продолжила возвращать успех, но хвост каждого файла оставался в памяти, поэтому `save()` сообщала о записи графа, который `load()` не мог прочитать. Явный сброс перед закрытием — всё исправление, и система типов этого не потребовала.',
    citation:
      'Pillai, Chidambaram, Alagappan, Al-Kiswany, Arpaci-Dusseau & Arpaci-Dusseau, “All File Systems Are Not Created Equal: On the Complexity of Crafting Crash-Consistent Applications”, OSDI 2014',
    url: 'https://www.usenix.org/conference/osdi14/technical-sessions/presentation/pillai',
    doesNotClaim:
      'That flushing makes a write durable. Flush moves data out of the process; durability against power loss is a further step, and this theorem is only about the gap between “returned success” and “a reader can see it”.',
    doesNotClaimRu:
      'Что сброс делает запись долговечной. Сброс перемещает данные из процесса; устойчивость к потере питания требует следующего шага, а эта теорема говорит только о разрыве между «вернулся успех» и «читатель может это увидеть».',
  },
  {
    id: 'T27',
    name: 'A fault that disables its own detector stays dormant indefinitely',
    nameRu: 'Ошибка, отключающая собственный детектор, остаётся неактивной неограниченно долго',
    statement:
      'Faults differ in whether the mechanism that would report them survives their presence. Where a fault prevents the artefact from being built or run at all, every instrument that operates on the built artefact is disabled by the very condition it exists to detect. Such a fault is not found late because it is subtle; it is not found at all, because nothing that could observe it can start.',
    statementRu:
      'Ошибки различаются тем, сохраняется ли в их присутствии механизм, который должен о них сообщить. Когда ошибка не даёт артефакту собраться или запуститься вовсе, каждый инструмент, работающий с собранным артефактом, отключён тем самым условием, которое он существует, чтобы обнаружить. Такая ошибка не находится поздно потому, что она тонка; она не находится вовсе, потому что ничто способное её наблюдать не может запуститься.',
    worked:
      'One directory was split across two repositories and each half kept flat relative imports of the other. `packed_vsa.zig` in one imported `knowledge_graph.zig`, which is in the other; that file imported `packed_vsa.zig` right back. Neither half compiled — and being uncompilable is exactly what stopped either from reporting the other missing. The dormancy ended only when an unrelated export forced a compiler to look.',
    workedRu:
      'Один каталог был разделён между двумя репозиториями, и каждая половина сохранила плоские относительные импорты другой. `packed_vsa.zig` в одном импортировал `knowledge_graph.zig`, который находится в другом; этот файл импортировал `packed_vsa.zig` обратно. Ни одна половина не компилировалась, и именно несобираемость не позволяла ни одной сообщить об отсутствии другой. Неактивность закончилась, только когда несвязанный экспорт заставил компилятор посмотреть.',
    citation:
      'Avižienis, Laprie, Randell & Landwehr, “Basic Concepts and Taxonomy of Dependable and Secure Computing”, IEEE TDSC 1(1), 2004 — fault dormancy and activation',
    url: 'https://doi.org/10.1109/TDSC.2004.2',
    doesNotClaim:
      'That an external instrument would necessarily have caught it either. It says only that no internal one could, which is why the first check on a repository has to be one that runs before anything in it does.',
    doesNotClaimRu:
      'Что внешний инструмент также непременно поймал бы это. Утверждается лишь, что никакой внутренний инструмент не мог, поэтому проверка репозитория должна начинаться с той, которая запускается до того, как запускается что-либо в нём.',
  },
]

export const SCIENCE_INTRO_EN =
  'Every claim in a report is bounded by something, and the bound is worth more than the claim. These are the statements the checks rest on, each with its source and each with what it refuses to say.'

export const SCIENCE_INTRO_RU =
  'Каждое утверждение в отчёте чем-то ограничено, и граница стоит больше самого утверждения. Здесь — то, на чём стоят проверки: с источником и с тем, чего каждая не говорит.'
