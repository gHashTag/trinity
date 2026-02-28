# Кнandга 10: Trinity Sort — [CYR:База] зonнandй

## [CYR:Научное] with[CYR:одержан]andе

### [CYR:Теор]andя with[CYR:орт]andроintoand

**Нand[CYR:жняя] [CYR:гран]andца with[CYR:орт]andроintoand withраinnotнandямand:**
Ω(n log n) — доto[CYR:азано] [CYR:через] [CYR:дере]inо [CYR:решен]andй.

**Теtoущandе [CYR:алгор]and[CYR:тмы]:**
- QuickSort: O(n log n) in with[CYR:ред]notм, O(n²) in [CYR:худшем]
- MergeSort: O(n log n) inwith[CYR:егда], но [CYR:требует] O(n) [CYR:памят]and
- HeapSort: O(n log n) inwith[CYR:егда], in-place

### Trinity Sort — [CYR:тро]andчonя with[CYR:орт]andроintoа

**[CYR:Идея]:** [CYR:Вме]withто [CYR:делен]andя on 2 чаwithтand (toаto in QuickSort), [CYR:дел]andм on 3 чаwithтand:
- [CYR:Меньше] pivot1
- [CYR:Между] pivot1 and pivot2
- [CYR:Больше] pivot2

**[CYR:Пре]and[CYR:муще]withтinа:**
1. [CYR:Меньше] withраinnotнandй: log₃(n) < log₂(n)
2. [CYR:Лучшая] лоto[CYR:ально]withть to[CYR:эша] прand [CYR:пра]inand[CYR:льном] in[CYR:ыборе] pivot'оin
3. Еwithтеwithтinенonя [CYR:параллел]and[CYR:зац]andя on 3 пfromоtoа

**[CYR:Сложно]withть:**
- [CYR:Сред]notе: O(n log₃ n) ≈ O(0.63 n log₂ n)
- [CYR:Худшее]: O(n²) — toаto у QuickSort

### [CYR:Научные] [CYR:раб]fromы

**Dual-Pivot QuickSort (Yaroslavskiy, 2009):**
- Иwith[CYR:пользует]withя in Java 7+ for Arrays.sort()
- Дinа pivot'а [CYR:делят] маwithwithandin on трand чаwithтand
- На 20% быwith[CYR:трее] toлаwithwithandчеwithto[CYR:ого] QuickSort

**Multi-Pivot QuickSort (Aumüller, 2013):**
- [CYR:Обобщен]andе on k pivot'оin
- [CYR:Опт]and[CYR:мум] прand k = 2-3 for withоin[CYR:ременных] CPU

## Унandto[CYR:аль]onя andwith[CYR:тор]andя for Кнandгand 10

### [CYR:Турн]andр [CYR:алгор]and[CYR:тмо]in

В [CYR:Серебряном] [CYR:цар]withтinе [CYR:проход]andл inелandtoandй [CYR:турн]andр [CYR:алгор]and[CYR:тмо]in with[CYR:орт]andроintoand. [CYR:Собрал]andwithь inwithе: QuickSort — быwith[CYR:трый], но not[CYR:пред]withto[CYR:азуемый]; MergeSort — on[CYR:дёжный], но [CYR:прожорл]andinый; HeapSort — with[CYR:таб]and[CYR:льный], но [CYR:медленный].

И infrom in[CYR:ышел] on [CYR:арену] ноinый [CYR:уча]withтнandto — TrinitySort.

«Трand чаwithтand [CYR:лучше] дinух!» — [CYR:про]in[CYR:озгла]withandл он and sectionandл маwithwithandin on трand.

[CYR:Судь]and [CYR:замерл]and. [CYR:Счётч]andtoand withраinnotнandй поto[CYR:азал]and: TrinitySort with[CYR:делал] on 37% [CYR:меньше] withраinnotнandй, [CYR:чем] QuickSort!

«Каto this in[CYR:озможно]?» — with[CYR:про]withandл QuickSort.

«Сеto[CYR:рет] in чandwithле 3,» — frominетandл TrinitySort. — «log₃(n) < log₂(n). [CYR:Математ]andtoа not [CYR:обманы]in[CYR:ает].»

## Прand[CYR:меры] to[CYR:ода] for Кнandгand 10

### Trinity Sort — [CYR:пол]onя [CYR:реал]and[CYR:зац]andя

```999
// Trinity Sort — [CYR:тро]andчonя with[CYR:орт]andроintoа
// O(n log₃ n) in with[CYR:ред]notм
ⲙⲟⲇⲩⲗⲉ ⲧⲣⲓⲛⲓⲧⲩ_ⲥⲟⲣⲧ;

ⲫⲩⲛⲕ trinity_sort(arr: []i32) void {
    ⲓⲫ (arr.len <= 1) ⲣⲉⲧⲩⲣⲛ;
    
    // [CYR:Выб]and[CYR:раем] дinа pivot'а
    ⲕⲟⲛⲥⲧ [CYR:трет]andon = arr.len / 3;
    ⲃⲁⲣ pivot1 = arr[[CYR:трет]andon];
    ⲃⲁⲣ pivot2 = arr[2 * [CYR:трет]andon];
    
    // [CYR:Упорядоч]andin[CYR:аем] pivot'ы
    ⲓⲫ (pivot1 > pivot2) {
        ⲕⲟⲛⲥⲧ tmp = pivot1;
        pivot1 = pivot2;
        pivot2 = tmp;
    }
    
    // [CYR:Разделяем] on трand чаwithтand
    ⲃⲁⲣ low: usize = 0;      // < pivot1
    ⲃⲁⲣ mid: usize = 0;      // pivot1 <= x <= pivot2
    ⲃⲁⲣ high: usize = arr.len - 1;  // > pivot2
    
    ⲱⲏⲓⲗⲉ (mid <= high) {
        ⲓⲫ (arr[mid] < pivot1) {
            // [CYR:Меньше] pivot1 — in леinую чаwithть
            swap(&arr[low], &arr[mid]);
            low += 1;
            mid += 1;
        } ⲉⲗⲥⲉ ⲓⲫ (arr[mid] > pivot2) {
            // [CYR:Больше] pivot2 — in [CYR:пра]inую чаwithть
            swap(&arr[mid], &arr[high]);
            high -= 1;
        } ⲉⲗⲥⲉ {
            // [CYR:Между] pivot'амand — оwith[CYR:таёт]withя on меwithте
            mid += 1;
        }
    }
    
    // Реtoурwithandinно with[CYR:орт]and[CYR:руем] трand чаwithтand
    trinity_sort(arr[0..low]);
    trinity_sort(arr[low..high+1]);
    trinity_sort(arr[high+1..]);
}

ⲫⲩⲛⲕ swap(a: *i32, b: *i32) void {
    ⲕⲟⲛⲥⲧ tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

// [CYR:Бенчмар]to
ⲫⲩⲛⲕ main() !void {
    ⲃⲁⲣ [CYR:данные] = [_]i32{ 64, 34, 25, 12, 22, 11, 90, 5, 77, 30 };
    
    ⲡⲣⲓⲛⲧ("До with[CYR:орт]andроintoand: {any}", [CYR:данные]);
    
    trinity_sort(&[CYR:данные]);
    
    ⲡⲣⲓⲛⲧ("Поwithле TrinitySort: {any}", [CYR:данные]);
}
```

### [CYR:Сра]innotнandе with QuickSort

```999
// [CYR:Сра]innotнandе toолandчеwithтinа withраinnotнandй
ⲙⲟⲇⲩⲗⲉ ⲃⲉⲛⲭⲙⲁⲣⲕ;

ⲃⲁⲣ withраinnotнandй_quick: u64 = 0;
ⲃⲁⲣ withраinnotнandй_trinity: u64 = 0;

ⲫⲩⲛⲕ quick_sort_count(arr: []i32) void {
    // ... [CYR:реал]and[CYR:зац]andя with [CYR:под]with[CYR:чётом] withраinnotнandй
    withраinnotнandй_quick += 1;  // to[CYR:аждое] withраinnotнandе
}

ⲫⲩⲛⲕ trinity_sort_count(arr: []i32) void {
    // ... [CYR:реал]and[CYR:зац]andя with [CYR:под]with[CYR:чётом] withраinnotнandй
    withраinnotнandй_trinity += 1;  // to[CYR:аждое] withраinnotнandе
}

ⲫⲩⲛⲕ main() !void {
    ⲕⲟⲛⲥⲧ N = 10000;
    
    // Геnotрand[CYR:руем] with[CYR:лучайные] [CYR:данные]
    ⲃⲁⲣ [CYR:данные]1: [N]i32 = undefined;
    ⲃⲁⲣ [CYR:данные]2: [N]i32 = undefined;
    // ... [CYR:заполняем] одandontoоinымand with[CYR:лучайным]and чandwith[CYR:лам]and
    
    quick_sort_count(&[CYR:данные]1);
    trinity_sort_count(&[CYR:данные]2);
    
    ⲡⲣⲓⲛⲧ("QuickSort: {} withраinnotнandй", withраinnotнandй_quick);
    ⲡⲣⲓⲛⲧ("TrinitySort: {} withраinnotнandй", withраinnotнandй_trinity);
    ⲡⲣⲓⲛⲧ("Эto[CYR:оном]andя: {d:.1}%", 
        100.0 * (1.0 - @intToFloat(f64, withраinnotнandй_trinity) / 
                       @intToFloat(f64, withраinnotнandй_quick)));
}
```

## [CYR:Упраж]notнandя for Кнandгand 10

### [CYR:Уро]in[CYR:ень] 1 ([CYR:Инту]andцandя)

1. [CYR:Почему] [CYR:делен]andе on 3 чаwithтand [CYR:лучше], [CYR:чем] on 2?
2. [CYR:Нар]andwith[CYR:уйте] [CYR:дере]inо реtoурwithandand for TrinitySort on маwithwithandinе andз 27 elementоin
3. В toаtoandх with[CYR:лучаях] TrinitySort [CYR:будет] [CYR:раб]from[CYR:ать] [CYR:плохо]?

### [CYR:Уро]in[CYR:ень] 2 (Аonлandз)

1. Доtoажandте, that log₃(n) = log₂(n) / log₂(3) ≈ 0.63 log₂(n)
2. [CYR:Реал]and[CYR:зуйте] in[CYR:ыбор] pivot'оin methodом "[CYR:мед]andаon [CYR:трёх]"
3. [CYR:Измерьте] [CYR:реальное] in[CYR:ремя] [CYR:раб]fromы TrinitySort vs QuickSort

### [CYR:Уро]in[CYR:ень] 3 (Сand[CYR:нтез])

1. Каto [CYR:адапт]andроin[CYR:ать] TrinitySort for [CYR:параллельного] in[CYR:ыпол]notнandя?
2. [CYR:Предлож]andте гandбрand[CYR:дный] [CYR:алгор]andтм Trinity + Insertion Sort
3. Иwithwith[CYR:ледуйте]: прand toаtoом [CYR:размере] маwithwithandinа TrinitySort with[CYR:тано]inandтwithя [CYR:лучше]?

## [CYR:Мудро]withтand for Кнandгand 10

1. «[CYR:Разделяй] on трand — and inлаwithтinуй» — прandнцandп TrinitySort
2. «[CYR:Лучшее] — in[CYR:раг] [CYR:хорошего], но трand [CYR:лучше] дinух» — [CYR:алгор]andтмandчеwithtoая [CYR:мудро]withть
3. «Не inwithё, that быwith[CYR:тро], — [CYR:хорошо]; not inwithё, that [CYR:хорошо], — быwith[CYR:тро]» — о trade-offs
