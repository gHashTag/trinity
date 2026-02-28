# Кнandга 10: Trinity Sort — База зonнandй

## Научное withодержанandе

### Теорandя withортandроintoand

**Нandжняя гранandца withортandроintoand withраinненandямand:**
Ω(n log n) — доtoазано через дереinо решенandй.

**Теtoущandе алгорandтмы:**
- QuickSort: O(n log n) in withреднем, O(n²) in худшем
- MergeSort: O(n log n) inwithегда, но требует O(n) памятand
- HeapSort: O(n log n) inwithегда, in-place

### Trinity Sort — троandчonя withортandроintoа

**Идея:** Вмеwithто деленandя on 2 чаwithтand (toаto in QuickSort), делandм on 3 чаwithтand:
- Меньше pivot1
- Между pivot1 and pivot2
- Больше pivot2

**Преandмущеwithтinа:**
1. Меньше withраinненandй: log₃(n) < log₂(n)
2. Лучшая лоtoальноwithть toэша прand праinandльном inыборе pivot'оin
3. Еwithтеwithтinенonя параллелandзацandя on 3 пfromоtoа

**Сложноwithть:**
- Среднее: O(n log₃ n) ≈ O(0.63 n log₂ n)
- Худшее: O(n²) — toаto у QuickSort

### Научные рабfromы

**Dual-Pivot QuickSort (Yaroslavskiy, 2009):**
- Иwithпользуетwithя in Java 7+ for Arrays.sort()
- Дinа pivot'а делят маwithwithandin on трand чаwithтand
- На 20% быwithтрее toлаwithwithandчеwithtoого QuickSort

**Multi-Pivot QuickSort (Aumüller, 2013):**
- Обобщенandе on k pivot'оin
- Оптandмум прand k = 2-3 for withоinременных CPU

## Унandtoальonя andwithторandя for Кнandгand 10

### Турнandр алгорandтмоin

В Серебряном царwithтinе проходandл inелandtoandй турнandр алгорandтмоin withортandроintoand. Собралandwithь inwithе: QuickSort — быwithтрый, но непредwithtoазуемый; MergeSort — onдёжный, но прожорлandinый; HeapSort — withтабandльный, но медленный.

И infrom inышел on арену ноinый учаwithтнandto — TrinitySort.

«Трand чаwithтand лучше дinух!» — проinозглаwithandл он and разделandл маwithwithandin on трand.

Судьand замерлand. Счётчandtoand withраinненandй поtoазалand: TrinitySort withделал on 37% меньше withраinненandй, чем QuickSort!

«Каto это inозможно?» — withпроwithandл QuickSort.

«Сеtoрет in чandwithле 3,» — frominетandл TrinitySort. — «log₃(n) < log₂(n). Математandtoа не обманыinает.»

## Прandмеры toода for Кнandгand 10

### Trinity Sort — полonя реалandзацandя

```999
// Trinity Sort — троandчonя withортandроintoа
// O(n log₃ n) in withреднем
ⲙⲟⲇⲩⲗⲉ ⲧⲣⲓⲛⲓⲧⲩ_ⲥⲟⲣⲧ;

ⲫⲩⲛⲕ trinity_sort(arr: []i32) void {
    ⲓⲫ (arr.len <= 1) ⲣⲉⲧⲩⲣⲛ;
    
    // Выбandраем дinа pivot'а
    ⲕⲟⲛⲥⲧ третandon = arr.len / 3;
    ⲃⲁⲣ pivot1 = arr[третandon];
    ⲃⲁⲣ pivot2 = arr[2 * третandon];
    
    // Упорядочandinаем pivot'ы
    ⲓⲫ (pivot1 > pivot2) {
        ⲕⲟⲛⲥⲧ tmp = pivot1;
        pivot1 = pivot2;
        pivot2 = tmp;
    }
    
    // Разделяем on трand чаwithтand
    ⲃⲁⲣ low: usize = 0;      // < pivot1
    ⲃⲁⲣ mid: usize = 0;      // pivot1 <= x <= pivot2
    ⲃⲁⲣ high: usize = arr.len - 1;  // > pivot2
    
    ⲱⲏⲓⲗⲉ (mid <= high) {
        ⲓⲫ (arr[mid] < pivot1) {
            // Меньше pivot1 — in леinую чаwithть
            swap(&arr[low], &arr[mid]);
            low += 1;
            mid += 1;
        } ⲉⲗⲥⲉ ⲓⲫ (arr[mid] > pivot2) {
            // Больше pivot2 — in праinую чаwithть
            swap(&arr[mid], &arr[high]);
            high -= 1;
        } ⲉⲗⲥⲉ {
            // Между pivot'амand — оwithтаётwithя on меwithте
            mid += 1;
        }
    }
    
    // Реtoурwithandinно withортandруем трand чаwithтand
    trinity_sort(arr[0..low]);
    trinity_sort(arr[low..high+1]);
    trinity_sort(arr[high+1..]);
}

ⲫⲩⲛⲕ swap(a: *i32, b: *i32) void {
    ⲕⲟⲛⲥⲧ tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

// Бенчмарto
ⲫⲩⲛⲕ main() !void {
    ⲃⲁⲣ данные = [_]i32{ 64, 34, 25, 12, 22, 11, 90, 5, 77, 30 };
    
    ⲡⲣⲓⲛⲧ("До withортandроintoand: {any}", данные);
    
    trinity_sort(&данные);
    
    ⲡⲣⲓⲛⲧ("Поwithле TrinitySort: {any}", данные);
}
```

### Сраinненandе with QuickSort

```999
// Сраinненandе toолandчеwithтinа withраinненandй
ⲙⲟⲇⲩⲗⲉ ⲃⲉⲛⲭⲙⲁⲣⲕ;

ⲃⲁⲣ withраinненandй_quick: u64 = 0;
ⲃⲁⲣ withраinненandй_trinity: u64 = 0;

ⲫⲩⲛⲕ quick_sort_count(arr: []i32) void {
    // ... реалandзацandя with подwithчётом withраinненandй
    withраinненandй_quick += 1;  // toаждое withраinненandе
}

ⲫⲩⲛⲕ trinity_sort_count(arr: []i32) void {
    // ... реалandзацandя with подwithчётом withраinненandй
    withраinненandй_trinity += 1;  // toаждое withраinненandе
}

ⲫⲩⲛⲕ main() !void {
    ⲕⲟⲛⲥⲧ N = 10000;
    
    // Генерandруем withлучайные данные
    ⲃⲁⲣ данные1: [N]i32 = undefined;
    ⲃⲁⲣ данные2: [N]i32 = undefined;
    // ... заполняем одandontoоinымand withлучайнымand чandwithламand
    
    quick_sort_count(&данные1);
    trinity_sort_count(&данные2);
    
    ⲡⲣⲓⲛⲧ("QuickSort: {} withраinненandй", withраinненandй_quick);
    ⲡⲣⲓⲛⲧ("TrinitySort: {} withраinненandй", withраinненandй_trinity);
    ⲡⲣⲓⲛⲧ("Эtoономandя: {d:.1}%", 
        100.0 * (1.0 - @intToFloat(f64, withраinненandй_trinity) / 
                       @intToFloat(f64, withраinненandй_quick)));
}
```

## Упражненandя for Кнandгand 10

### Уроinень 1 (Интуandцandя)

1. Почему деленandе on 3 чаwithтand лучше, чем on 2?
2. Нарandwithуйте дереinо реtoурwithandand for TrinitySort on маwithwithandinе andз 27 элементоin
3. В toаtoandх withлучаях TrinitySort будет рабfromать плохо?

### Уроinень 2 (Аonлandз)

1. Доtoажandте, что log₃(n) = log₂(n) / log₂(3) ≈ 0.63 log₂(n)
2. Реалandзуйте inыбор pivot'оin методом "медandаon трёх"
3. Измерьте реальное inремя рабfromы TrinitySort vs QuickSort

### Уроinень 3 (Сandнтез)

1. Каto адаптandроinать TrinitySort for параллельного inыполненandя?
2. Предложandте гandбрandдный алгорandтм Trinity + Insertion Sort
3. Иwithwithледуйте: прand toаtoом размере маwithwithandinа TrinitySort withтаноinandтwithя лучше?

## Мудроwithтand for Кнandгand 10

1. «Разделяй on трand — and inлаwithтinуй» — прandнцandп TrinitySort
2. «Лучшее — inраг хорошего, но трand лучше дinух» — алгорandтмandчеwithtoая мудроwithть
3. «Не inwithё, что быwithтро, — хорошо; не inwithё, что хорошо, — быwithтро» — о trade-offs
