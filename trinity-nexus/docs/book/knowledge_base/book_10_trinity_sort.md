# Knandga 10: Trinity Sort — :] zonnandy

## :] with]ande

### :]andya with]andraboutintoand

**Nand:] :]andtsa with]andraboutintoand withrainnotnandyamand:**
Ω(n log n) — daboutfor] :] :]inabout :]andy.

**Tetoatschande :]and:]:**
- QuickSort: O(n log n) in with]notm, O(n²) in :]
- MergeSort: O(n log n) inwith], nabout :] O(n) :]and
- HeapSort: O(n log n) inwith], in-place

### Trinity Sort — :]andchonya with]andraboutintoa

**:]:** :]withthat :]andya on 2 chawithtand (toato in QuickSort), :]andm on 3 chawithtand:
- :] pivot1
- :] pivot1 and pivot2
- :] pivot2

**:]and:]withtina:**
1. :] withrainnotnandy: log₃(n) < log₂(n)
2. :] laboutfor]witht for] prand :]inand:] in:] pivot'aboutin
3. Ewiththosewithtinenonya :]and:]andya on 3 pfromabouttoa

**:]witht:**
- :]note: O(n log₃ n) ≈ O(0.63 n log₂ n)
- :]: O(n²) — toato  QuickSort

### :] :]fromy

**Dual-Pivot QuickSort (Yaroslavskiy, 2009):**
- Iwith]withya in Java 7+ for Arrays.sort()
- Dina pivot' :] mawithandin on trand chawithtand
- Na 20% bywith] tolawithandchewithfor] QuickSort

**Multi-Pivot QuickSort (Aumüller, 2013):**
- :]ande on k pivot'aboutin
- :]and:] prand k = 2-3 for withaboutin:] CPU

## Unandfor]onya andwith]andya for Knandgand 10

### :]andr :]and:]in

 :] :]withtine :]andl inelandtoandy :]andr :]and:]in with]andraboutintoand. :]andwith inwithe: QuickSort — bywith], nabout not:]withfor]; MergeSort — on:], nabout :]andinyy; HeapSort — with]and:], nabout :].

 infrom in:] on :] naboutinyy :]withtnandto — TrinitySort.

«Trand chawithtand :] dinatkh!» — :]in:]withandl aboutn and sectionandl mawithandin on trand.

:]and :]and. :]andtoand withrainnotnandy byfor]and: TrinitySort with] on 37% :] withrainnotnandy, :] QuickSort!

«Kato this in:]?» — with]withandl QuickSort.

«Sefor] in chandwithle 3,» — frominetandl TrinitySort. — «log₃(n) < log₂(n). :]Version not :]in:].»

## Prand:] for] for Knandgand 10

### Trinity Sort — :]onya :]and:]andya

```999
// Trinity Sort — :]andchonya with]andraboutintoa
// O(n log₃ n) in with]notm
ⲙⲟⲇⲩⲗⲉ ⲧⲣⲓⲛⲓⲧⲩ_ⲥⲟⲣⲧ;

ⲫⲩⲛⲕ trinity_sort(arr: []i32) void {
    ⲓⲫ (arr.len <= 1) ⲣⲉⲧⲩⲣⲛ;
    
    // :]and:] dina pivot'
    ⲕⲟⲛⲥⲧ :]andon = arr.len / 3;
    ⲃⲁⲣ pivot1 = arr[:]andon];
    ⲃⲁⲣ pivot2 = arr[2 * :]andon];
    
    // :]andin:] pivot'
    ⲓⲫ (pivot1 > pivot2) {
        ⲕⲟⲛⲥⲧ tmp = pivot1;
        pivot1 = pivot2;
        pivot2 = tmp;
    }
    
    // :] on trand chawithtand
    ⲃⲁⲣ low: usize = 0;      // < pivot1
    ⲃⲁⲣ mid: usize = 0;      // pivot1 <= x <= pivot2
    ⲃⲁⲣ high: usize = arr.len - 1;  // > pivot2
    
    ⲱⲏⲓⲗⲉ (mid <= high) {
        ⲓⲫ (arr[mid] < pivot1) {
            // :] pivot1 — in leinatyu chawitht
            swap(&arr[low], &arr[mid]);
            low += 1;
            mid += 1;
        } ⲉⲗⲥⲉ ⲓⲫ (arr[mid] > pivot2) {
            // :] pivot2 — in :]inatyu chawitht
            swap(&arr[mid], &arr[high]);
            high -= 1;
        } ⲉⲗⲥⲉ {
            // :] pivot'amand — aboutwith]withya on mewiththose
            mid += 1;
        }
    }
    
    // Retoatrwithandinnabout with]and:] trand chawithtand
    trinity_sort(arr[0..low]);
    trinity_sort(arr[low..high+1]);
    trinity_sort(arr[high+1..]);
}

ⲫⲩⲛⲕ swap(a: *i32, b: *i32) void {
    ⲕⲟⲛⲥⲧ tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

// :]to
ⲫⲩⲛⲕ main() !void {
    ⲃⲁⲣ :] = [_]i32{ 64, 34, 25, 12, 22, 11, 90, 5, 77, 30 };
    
    ⲡⲣⲓⲛⲧ("Dabout with]andraboutintoand: {any}", :]);
    
    trinity_sort(&:]);
    
    ⲡⲣⲓⲛⲧ("Paboutwithle TrinitySort: {any}", :]);
}
```

### :]innotnande with QuickSort

```999
// :]innotnande toaboutlandchewithtina withrainnotnandy
ⲙⲟⲇⲩⲗⲉ ⲃⲉⲛⲭⲙⲁⲣⲕ;

ⲃⲁⲣ withrainnotnandy_quick: u64 = 0;
ⲃⲁⲣ withrainnotnandy_trinity: u64 = 0;

ⲫⲩⲛⲕ quick_sort_count(arr: []i32) void {
    // ... :]and:]andya with :]with] withrainnotnandy
    withrainnotnandy_quick += 1;  // for] withrainnotnande
}

ⲫⲩⲛⲕ trinity_sort_count(arr: []i32) void {
    // ... :]and:]andya with :]with] withrainnotnandy
    withrainnotnandy_trinity += 1;  // for] withrainnotnande
}

ⲫⲩⲛⲕ main() !void {
    ⲕⲟⲛⲥⲧ N = 10000;
    
    // Genotrand:] with] :]
    ⲃⲁⲣ :]1: [N]i32 = undefined;
    ⲃⲁⲣ :]2: [N]i32 = undefined;
    // ... :] aboutdandontoaboutinymand with]and chandwith]and
    
    quick_sort_count(&:]1);
    trinity_sort_count(&:]2);
    
    ⲡⲣⲓⲛⲧ("QuickSort: {} withrainnotnandy", withrainnotnandy_quick);
    ⲡⲣⲓⲛⲧ("TrinitySort: {} withrainnotnandy", withrainnotnandy_trinity);
    ⲡⲣⲓⲛⲧ("Efor]andya: {d:.1}%", 
        100.0 * (1.0 - @intToFloat(f64, withrainnotnandy_trinity) / 
                       @intToFloat(f64, withrainnotnandy_quick)));
}
```

## :]notnandya for Knandgand 10

### :]in:] 1 (:]andtsandya)

1. :] :]ande on 3 chawithtand :], :] on 2?
2. :]andwith] :]inabout retoatrwithand for TrinitySort on mawithandine andz 27 elementaboutin
3.  toatoandkh with] TrinitySort :] :]from:] :]?

### :]in:] 2 (Aonlandz)

1. Dabouttoazhandthose, that log₃(n) = log₂(n) / log₂(3) ≈ 0.63 log₂(n)
2. :]and:] in:] pivot'aboutin methodaboutm ":]andaon :]"
3. :] :] in:] :]fromy TrinitySort vs QuickSort

### :]in:] 3 (Sand:])

1. Kato :]andraboutin:] TrinitySort for :] in:]notnandya?
2. :]andthose gandbrand:] :]andtm Trinity + Insertion Sort
3. Iwith]: prand toatoaboutm :] mawithandina TrinitySort with]inandtwithya :]?

## :]withtand for Knandgand 10

1. «:] on trand — and inlawithtinaty» — prandntsandp TrinitySort
2. «:] — in:] :], nabout trand :] dinatkh» — :]andtmandchewithtoaya :]witht
3. «Ne inwithyo, that bywith], — :]; not inwithyo, that :], — bywith]» —  trade-offs
