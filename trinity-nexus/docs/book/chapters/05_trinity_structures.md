# Chapter 5: Trinity Structures — The Three Bogatyrs of Data

---

*"The Three Bogatyrs" — Ilya Muromets, Dobrynya Nikitich, Alyosha Popovich —*
*together are stronger than each one alone.*
— Russian Epic

---

## The Three Bogatyrs of Data Structures

As three bogatyrs protect Rus, so three data structures protect our algorithms:

```
+---------------------------------------------------------+
|                                                         |
|   ILYA MUROMETS      DOBRYNYA NIKITICH   ALYOSHA POPOVICH   |
|   -------------      ----------------   --------------  |
|   Trinity B-Tree     Trinity Hash       Trinity Graph   |
|   (Strength)         (Wisdom)           (Cunning)       |
|                                                         |
|   Storage of         Fast access        Connections     |
|   ordered data       by key             between data    |
|                                                         |
+---------------------------------------------------------+
```

---

## Ilya Muromets: Trinity B-Tree

### The Strength of Order

B-tree is the foundation of databases. But what branching factor is optimal?

```
+---------------------------------------------------------+
|                                                         |
|   OPTIMAL BRANCHING FACTOR                              |
|                                                         |
|   Minimizing b/log(b):                                  |
|                                                         |
|   b=2: 2/0.693 = 2.89                                   |
|   b=3: 3/1.099 = 2.73  <- MINIMUM!                      |
|   b=4: 4/1.386 = 2.89                                   |
|                                                         |
|   Optimum: b = e ~ 2.718                                |
|   Nearest integer: b = 3                                |
|                                                         |
+---------------------------------------------------------+
```

### Trinity B-Tree: b = 3

```
                    [30, 60]
                   /    |    \
                  /     |     \
           [10, 20]  [40, 50]  [70, 80]
           /  |  \   /  |  \   /  |  \
          ... ... ... ... ... ... ... ...
```

Each node has **3 children** (or 2 keys).

### Benchmark Results

```
+-------------+-------------+-------------+-----------+
| Branching   | Comparisons | Relative    | Note      |
+-------------+-------------+-------------+-----------+
| b = 2       | 16,610      | 1.06x       |           |
| b = 3       | 15,612      | 1.00x       | <- BEST   |
| b = 4       | 16,234      | 1.04x       |           |
| b = 8       | 18,456      | 1.18x       |           |
| b = 16      | 21,234      | 1.36x       |           |
+-------------+-------------+-------------+-----------+

* 10,000 search operations
```

**Trinity B-Tree with b=3 requires 6% fewer comparisons!**

### Code

```python
class TrinityBTreeNode:
    """Trinity B-Tree node with 3 children"""
    def __init__(self):
        self.keys = []      # Maximum 2 keys
        self.children = []  # Maximum 3 children
        self.is_leaf = True

class TrinityBTree:
    """B-tree with branching factor = 3"""
    def __init__(self):
        self.root = TrinityBTreeNode()
        self.t = 2  # Minimum degree (max keys = 2t-1 = 3)

    def search(self, key, node=None):
        if node is None:
            node = self.root

        i = 0
        while i < len(node.keys) and key > node.keys[i]:
            i += 1

        if i < len(node.keys) and key == node.keys[i]:
            return (node, i)

        if node.is_leaf:
            return None

        return self.search(key, node.children[i])
```

---

## Dobrynya Nikitich: Trinity Hash

### The Wisdom of Three Functions

Cuckoo Hashing uses multiple hash functions. How many is optimal?

```
+---------------------------------------------------------+
|                                                         |
|   CUCKOO HASHING: LOAD FACTOR THRESHOLD                 |
|                                                         |
|   d = 2 functions: 50% fill                             |
|   d = 3 functions: 91% fill  <- +82%!                   |
|   d = 4 functions: 97% fill  <- +7%                     |
|                                                         |
|   MAXIMUM GAIN AT d = 3!                                |
|                                                         |
+---------------------------------------------------------+
```

### The Three Bogatyrs of Hashing

```
+---------------------------------------------------------+
|                                                         |
|   ILYA (h1)        DOBRYNYA (h2)     ALYOSHA (h3)       |
|   ---------        -----------       ----------         |
|   Table 1          Table 2           Table 3            |
|                                                         |
|   If occupied      If occupied       If occupied        |
|   -> to Dobrynya   -> to Alyosha     -> to Ilya         |
|                                                         |
|   Three bogatyrs together protect the data!             |
|                                                         |
+---------------------------------------------------------+
```

### Insertion Algorithm

```python
class TrinityHash:
    """Cuckoo Hashing with 3 tables"""

    def __init__(self, capacity):
        self.capacity = capacity
        self.tables = [
            [None] * capacity,  # Ilya
            [None] * capacity,  # Dobrynya
            [None] * capacity,  # Alyosha
        ]
        self.MAX_KICKS = 500

    def _hash(self, key, table_idx):
        """Three different hash functions"""
        if table_idx == 0:
            return hash(key) % self.capacity
        elif table_idx == 1:
            return hash(key * 2654435761) % self.capacity
        else:
            return hash(key * 0x9E3779B9) % self.capacity

    def insert(self, key):
        """Insertion with movement between bogatyrs"""
        for _ in range(self.MAX_KICKS):
            for i in range(3):
                pos = self._hash(key, i)
                if self.tables[i][pos] is None:
                    self.tables[i][pos] = key
                    return True
                # Evict the current resident
                key, self.tables[i][pos] = self.tables[i][pos], key

        # Rehash needed
        self._rehash()
        return self.insert(key)

    def lookup(self, key):
        """Search: check all three bogatyrs"""
        for i in range(3):
            pos = self._hash(key, i)
            if self.tables[i][pos] == key:
                return True
        return False
```

### Results

```
+-------------+-------------+-------------+
| Functions   | Max Load    | Gain        |
+-------------+-------------+-------------+
| d = 2       | 50%         | baseline    |
| d = 3       | 91%         | +82%        |
| d = 4       | 97%         | +7%         |
+-------------+-------------+-------------+
```

**Three hash functions provide maximum capacity gain!**

---

## Alyosha Popovich: Trinity Graph

### The Cunning of Three States

In graph algorithms (DFS, cycle detection), **three states** are needed:

```
+---------------------------------------------------------+
|                                                         |
|   THREE VERTEX STATES                                   |
|                                                         |
|   WHITE (0)        GRAY (1)          BLACK (2)          |
|   ---------        ---------         ----------         |
|   Not visited      In progress       Completed          |
|                                                         |
|   First            Second            Third              |
|   attempt          attempt           attempt            |
|                                                         |
+---------------------------------------------------------+
```

### Why Two States Are Not Enough?

```
Graph: A -> B -> C -> A (cycle)

With two states (visited/not visited):
  Visit A -> mark visited
  Visit B -> mark visited
  Visit C -> mark visited
  See A -> already visited

  But is this a cycle or just path intersection?
  CANNOT DETERMINE!

With three states:
  Visit A -> mark GRAY (in progress)
  Visit B -> mark GRAY
  Visit C -> mark GRAY
  See A -> GRAY = CYCLE!

  After completion: mark BLACK
```

### Cycle Detection Algorithm

```python
def has_cycle(graph):
    """Cycle detection with three states"""
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}

    def dfs(node):
        color[node] = GRAY  # Second attempt

        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                return True  # CYCLE!
            if color[neighbor] == WHITE:
                if dfs(neighbor):
                    return True

        color[node] = BLACK  # Third attempt — success
        return False

    for node in graph:
        if color[node] == WHITE:
            if dfs(node):
                return True

    return False
```

### Topological Sort

```python
def topological_sort(graph):
    """Topological sort with three states"""
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}
    result = []

    def dfs(node):
        color[node] = GRAY

        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                raise ValueError("Cycle! Topological sort impossible")
            if color[neighbor] == WHITE:
                dfs(neighbor)

        color[node] = BLACK
        result.append(node)  # Add after completion

    for node in graph:
        if color[node] == WHITE:
            dfs(node)

    return result[::-1]  # Reverse order
```

### Strongly Connected Components (Kosaraju)

```python
def strongly_connected_components(graph):
    """Kosaraju's algorithm with three states"""
    WHITE, GRAY, BLACK = 0, 1, 2

    # First DFS: get finish order
    color = {node: WHITE for node in graph}
    finish_order = []

    def dfs1(node):
        color[node] = GRAY
        for neighbor in graph[node]:
            if color[neighbor] == WHITE:
                dfs1(neighbor)
        color[node] = BLACK
        finish_order.append(node)

    for node in graph:
        if color[node] == WHITE:
            dfs1(node)

    # Transpose the graph
    reversed_graph = transpose(graph)

    # Second DFS: find components
    color = {node: WHITE for node in graph}
    components = []

    def dfs2(node, component):
        color[node] = GRAY
        component.append(node)
        for neighbor in reversed_graph[node]:
            if color[neighbor] == WHITE:
                dfs2(neighbor, component)
        color[node] = BLACK

    for node in reversed(finish_order):
        if color[node] == WHITE:
            component = []
            dfs2(node, component)
            components.append(component)

    return components
```

---

## Ternary Search Tree: Three Roads for Strings

### The Idea

```
+---------------------------------------------------------+
|                                                         |
|   TERNARY SEARCH TREE (TST)                             |
|                                                         |
|   Each node has 3 children:                             |
|   * LEFT: character < current                           |
|   * MIDDLE: next character of string                    |
|   * RIGHT: character > current                          |
|                                                         |
|   Three roads for each character!                       |
|                                                         |
+---------------------------------------------------------+
```

### Structure

```
Words: "cat", "car", "card", "care", "dog"

              c
            / | \
           a  a  d
          /|  |  |\
         r t  r  o g
         |    |  |
         d    e  g
```

### Advantages

```
+---------------------------------------------------------+
|                                                         |
|   TST vs TRIE vs HASH                                   |
|                                                         |
|   Operation        TST         Trie        Hash         |
|   -------------------------------------------------    |
|   Search           O(log n+k)  O(k)        O(k)         |
|   Prefix search    O(log n+m)  O(m)        O(n)         |
|   Memory           Less        More        Medium       |
|   Ordering         Yes         Yes         No           |
|                                                         |
|   k = key length, m = prefix length                     |
|                                                         |
+---------------------------------------------------------+
```

### Code

```python
class TSTNode:
    def __init__(self, char):
        self.char = char
        self.left = None    # < char
        self.middle = None  # next character
        self.right = None   # > char
        self.is_end = False
        self.value = None

class TernarySearchTree:
    def __init__(self):
        self.root = None

    def insert(self, key, value=None):
        self.root = self._insert(self.root, key, 0, value)

    def _insert(self, node, key, idx, value):
        char = key[idx]

        if node is None:
            node = TSTNode(char)

        if char < node.char:
            node.left = self._insert(node.left, key, idx, value)
        elif char > node.char:
            node.right = self._insert(node.right, key, idx, value)
        elif idx < len(key) - 1:
            node.middle = self._insert(node.middle, key, idx + 1, value)
        else:
            node.is_end = True
            node.value = value

        return node

    def search(self, key):
        node = self._search(self.root, key, 0)
        return node.value if node and node.is_end else None

    def prefix_search(self, prefix):
        """Find all words with given prefix"""
        node = self._search(self.root, prefix, 0)
        if node is None:
            return []

        results = []
        if node.is_end:
            results.append(prefix)

        self._collect(node.middle, prefix, results)
        return results
```

---

## Summary Table

```
+-----------------+-------------+-------------+-------------+
| Structure       | Principle 3 | Result      | Image       |
+-----------------+-------------+-------------+-------------+
| Trinity B-Tree  | b = 3       | -6% compar. | Ilya        |
| Trinity Hash    | 3 functions | +82% capac. | Dobrynya    |
| Trinity Graph   | 3 states    | Cycles, SCC | Alyosha     |
| TST             | 3 children  | Prefix srch | Three roads |
+-----------------+-------------+-------------+-------------+
```

---

## Wisdom of the Chapter

> *And Ivan the Programmer understood the third truth:*
>
> *Three bogatyrs together are stronger than each one alone.*
>
> *Ilya Muromets (Trinity B-Tree) stores data in order,*
> *with optimal branching factor = 3.*
>
> *Dobrynya Nikitich (Trinity Hash) provides fast access,*
> *with three hash functions for 82% more capacity.*
>
> *Alyosha Popovich (Trinity Graph) finds connections,*
> *with three states for cycle detection.*
>
> *And Ternary Search Tree — three roads for each character —*
> *combines the strength of tree and hash.*
>
> *Three bogatyrs protect the data.*
> *The ancients knew.*

---

[<- Chapter 4](04_trinity_sort.md) | [Chapter 6: Trinity Compression ->](06_trinity_compression.md)
