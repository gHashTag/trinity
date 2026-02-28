# Кнandга 10: Trinity Sort — [CYR:[TRANSLATED]] зonнandй

## [CYR:[TRANSLATED]] with[TRANSLATED]]andе

### [CYR:[TRANSLATED]]andя with[TRANSLATED]]andроintoand

**Нand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andца with[TRANSLATED]]andроintoand withраinnotнandямand:**
Ω(n log n) — доfor[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inо [CYR:[TRANSLATED]]andй.

**Теtoущandе [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]:**
- QuickSort: O(n log n) in with[TRANSLATED]]notм, O(n²) in [CYR:[TRANSLATED]]
- MergeSort: O(n log n) inwith[TRANSLATED]], но [CYR:[TRANSLATED]] O(n) [CYR:[TRANSLATED]]and
- HeapSort: O(n log n) inwith[TRANSLATED]], in-place

### Trinity Sort — [CYR:[TRANSLATED]]andчonя with[TRANSLATED]]andроintoа

**[CYR:[TRANSLATED]]:** [CYR:[TRANSLATED]]withто [CYR:[TRANSLATED]]andя on 2 чаwithтand (toаto in QuickSort), [CYR:[TRANSLATED]]andм on 3 чаwithтand:
- [CYR:[TRANSLATED]] pivot1
- [CYR:[TRANSLATED]] pivot1 and pivot2
- [CYR:[TRANSLATED]] pivot2

**[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]withтinа:**
1. [CYR:[TRANSLATED]] withраinnotнandй: log₃(n) < log₂(n)
2. [CYR:[TRANSLATED]] лоfor[TRANSLATED]]withть for[TRANSLATED]] прand [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] in[CYR:[TRANSLATED]] pivot'оin
3. Еwithтеwithтinенonя [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя on 3 пfromоtoа

**[CYR:[TRANSLATED]]withть:**
- [CYR:[TRANSLATED]]notе: O(n log₃ n) ≈ O(0.63 n log₂ n)
- [CYR:[TRANSLATED]]: O(n²) — toаto  QuickSort

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromы

**Dual-Pivot QuickSort (Yaroslavskiy, 2009):**
- Иwith[TRANSLATED]]withя in Java 7+ for Arrays.sort()
- Дinа pivot' [CYR:[TRANSLATED]] маwithandin on трand чаwithтand
- На 20% быwith[TRANSLATED]] toлаwithandчеwithfor[TRANSLATED]] QuickSort

**Multi-Pivot QuickSort (Aumüller, 2013):**
- [CYR:[TRANSLATED]]andе on k pivot'оin
- [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] прand k = 2-3 for withоin[CYR:[TRANSLATED]] CPU

## Унandfor[TRANSLATED]]onя andwith[TRANSLATED]]andя for Кнandгand 10

### [CYR:[TRANSLATED]]andр [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]in

 [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]withтinе [CYR:[TRANSLATED]]andл inелandtoandй [CYR:[TRANSLATED]]andр [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]in with[TRANSLATED]]andроintoand. [CYR:[TRANSLATED]]andwithь inwithе: QuickSort — быwith[TRANSLATED]], но not[CYR:[TRANSLATED]]withfor[TRANSLATED]]; MergeSort — on[CYR:[TRANSLATED]], но [CYR:[TRANSLATED]]andinый; HeapSort — with[TRANSLATED]]and[CYR:[TRANSLATED]], но [CYR:[TRANSLATED]].

 infrom in[CYR:[TRANSLATED]] on [CYR:[TRANSLATED]] ноinый [CYR:[TRANSLATED]]withтнandto — TrinitySort.

«Трand чаwithтand [CYR:[TRANSLATED]] дinух!» — [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]withandл он and sectionandл маwithandin on трand.

[CYR:[TRANSLATED]]and [CYR:[TRANSLATED]]and. [CYR:[TRANSLATED]]andtoand withраinnotнandй поfor[TRANSLATED]]and: TrinitySort with[TRANSLATED]] on 37% [CYR:[TRANSLATED]] withраinnotнandй, [CYR:[TRANSLATED]] QuickSort!

«Каto this in[CYR:[TRANSLATED]]?» — with[TRANSLATED]]withandл QuickSort.

«Сеfor[TRANSLATED]] in чandwithле 3,» — frominетandл TrinitySort. — «log₃(n) < log₂(n). [CYR:[TRANSLATED]]andtoа not [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]].»

## Прand[CYR:[TRANSLATED]] for[TRANSLATED]] for Кнandгand 10

### Trinity Sort — [CYR:[TRANSLATED]]onя [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя

```999
// Trinity Sort — [CYR:[TRANSLATED]]andчonя with[TRANSLATED]]andроintoа
// O(n log₃ n) in with[TRANSLATED]]notм
ⲙⲟⲇⲩⲗⲉ ⲧⲣⲓⲛⲓⲧⲩ_ⲥⲟⲣⲧ;

ⲫⲩⲛⲕ trinity_sort(arr: []i32) void {
    ⲓⲫ (arr.len <= 1) ⲣⲉⲧⲩⲣⲛ;
    
    // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] дinа pivot'
    ⲕⲟⲛⲥⲧ [CYR:[TRANSLATED]]andon = arr.len / 3;
    ⲃⲁⲣ pivot1 = arr[[CYR:[TRANSLATED]]andon];
    ⲃⲁⲣ pivot2 = arr[2 * [CYR:[TRANSLATED]]andon];
    
    // [CYR:[TRANSLATED]]andin[CYR:[TRANSLATED]] pivot'
    ⲓⲫ (pivot1 > pivot2) {
        ⲕⲟⲛⲥⲧ tmp = pivot1;
        pivot1 = pivot2;
        pivot2 = tmp;
    }
    
    // [CYR:[TRANSLATED]] on трand чаwithтand
    ⲃⲁⲣ low: usize = 0;      // < pivot1
    ⲃⲁⲣ mid: usize = 0;      // pivot1 <= x <= pivot2
    ⲃⲁⲣ high: usize = arr.len - 1;  // > pivot2
    
    ⲱⲏⲓⲗⲉ (mid <= high) {
        ⲓⲫ (arr[mid] < pivot1) {
            // [CYR:[TRANSLATED]] pivot1 — in леinую чаwithть
            swap(&arr[low], &arr[mid]);
            low += 1;
            mid += 1;
        } ⲉⲗⲥⲉ ⲓⲫ (arr[mid] > pivot2) {
            // [CYR:[TRANSLATED]] pivot2 — in [CYR:[TRANSLATED]]inую чаwithть
            swap(&arr[mid], &arr[high]);
            high -= 1;
        } ⲉⲗⲥⲉ {
            // [CYR:[TRANSLATED]] pivot'амand — оwith[TRANSLATED]]withя on меwithте
            mid += 1;
        }
    }
    
    // Реtoурwithandinно with[TRANSLATED]]and[CYR:[TRANSLATED]] трand чаwithтand
    trinity_sort(arr[0..low]);
    trinity_sort(arr[low..high+1]);
    trinity_sort(arr[high+1..]);
}

ⲫⲩⲛⲕ swap(a: *i32, b: *i32) void {
    ⲕⲟⲛⲥⲧ tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

// [CYR:[TRANSLATED]]to
ⲫⲩⲛⲕ main() !void {
    ⲃⲁⲣ [CYR:[TRANSLATED]] = [_]i32{ 64, 34, 25, 12, 22, 11, 90, 5, 77, 30 };
    
    ⲡⲣⲓⲛⲧ("До with[TRANSLATED]]andроintoand: {any}", [CYR:[TRANSLATED]]);
    
    trinity_sort(&[CYR:[TRANSLATED]]);
    
    ⲡⲣⲓⲛⲧ("Поwithле TrinitySort: {any}", [CYR:[TRANSLATED]]);
}
```

### [CYR:[TRANSLATED]]innotнandе with QuickSort

```999
// [CYR:[TRANSLATED]]innotнandе toолandчеwithтinа withраinnotнandй
ⲙⲟⲇⲩⲗⲉ ⲃⲉⲛⲭⲙⲁⲣⲕ;

ⲃⲁⲣ withраinnotнandй_quick: u64 = 0;
ⲃⲁⲣ withраinnotнandй_trinity: u64 = 0;

ⲫⲩⲛⲕ quick_sort_count(arr: []i32) void {
    // ... [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя with [CYR:[TRANSLATED]]with[TRANSLATED]] withраinnotнandй
    withраinnotнandй_quick += 1;  // for[TRANSLATED]] withраinnotнandе
}

ⲫⲩⲛⲕ trinity_sort_count(arr: []i32) void {
    // ... [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя with [CYR:[TRANSLATED]]with[TRANSLATED]] withраinnotнandй
    withраinnotнandй_trinity += 1;  // for[TRANSLATED]] withраinnotнandе
}

ⲫⲩⲛⲕ main() !void {
    ⲕⲟⲛⲥⲧ N = 10000;
    
    // Геnotрand[CYR:[TRANSLATED]] with[TRANSLATED]] [CYR:[TRANSLATED]]
    ⲃⲁⲣ [CYR:[TRANSLATED]]1: [N]i32 = undefined;
    ⲃⲁⲣ [CYR:[TRANSLATED]]2: [N]i32 = undefined;
    // ... [CYR:[TRANSLATED]] одandontoоinымand with[TRANSLATED]]and чandwith[TRANSLATED]]and
    
    quick_sort_count(&[CYR:[TRANSLATED]]1);
    trinity_sort_count(&[CYR:[TRANSLATED]]2);
    
    ⲡⲣⲓⲛⲧ("QuickSort: {} withраinnotнandй", withраinnotнandй_quick);
    ⲡⲣⲓⲛⲧ("TrinitySort: {} withраinnotнandй", withраinnotнandй_trinity);
    ⲡⲣⲓⲛⲧ("Эfor[TRANSLATED]]andя: {d:.1}%", 
        100.0 * (1.0 - @intToFloat(f64, withраinnotнandй_trinity) / 
                       @intToFloat(f64, withраinnotнandй_quick)));
}
```

## [CYR:[TRANSLATED]]notнandя for Кнandгand 10

### [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] 1 ([CYR:[TRANSLATED]]andцandя)

1. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andе on 3 чаwithтand [CYR:[TRANSLATED]], [CYR:[TRANSLATED]] on 2?
2. [CYR:[TRANSLATED]]andwith[TRANSLATED]] [CYR:[TRANSLATED]]inо реtoурwithand for TrinitySort on маwithandinе andз 27 elementоin
3.  toаtoandх with[TRANSLATED]] TrinitySort [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]?

### [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] 2 (Аonлandз)

1. Доtoажandте, that log₃(n) = log₂(n) / log₂(3) ≈ 0.63 log₂(n)
2. [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] in[CYR:[TRANSLATED]] pivot'оin methodом "[CYR:[TRANSLATED]]andаon [CYR:[TRANSLATED]]"
3. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromы TrinitySort vs QuickSort

### [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] 3 (Сand[CYR:[TRANSLATED]])

1. Каto [CYR:[TRANSLATED]]andроin[CYR:[TRANSLATED]] TrinitySort for [CYR:[TRANSLATED]] in[CYR:[TRANSLATED]]notнandя?
2. [CYR:[TRANSLATED]]andте гandбрand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andтм Trinity + Insertion Sort
3. Иwith[TRANSLATED]]: прand toаtoом [CYR:[TRANSLATED]] маwithandinа TrinitySort with[TRANSLATED]]inandтwithя [CYR:[TRANSLATED]]?

## [CYR:[TRANSLATED]]withтand for Кнandгand 10

1. «[CYR:[TRANSLATED]] on трand — and inлаwithтinуй» — прandнцandп TrinitySort
2. «[CYR:[TRANSLATED]] — in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]], но трand [CYR:[TRANSLATED]] дinух» — [CYR:[TRANSLATED]]andтмandчеwithtoая [CYR:[TRANSLATED]]withть
3. «Не inwithё, that быwith[TRANSLATED]], — [CYR:[TRANSLATED]]; not inwithё, that [CYR:[TRANSLATED]], — быwith[TRANSLATED]]» —  trade-offs
