---
sidebar_position: 10
sidebar_label: 'Sacred Geometry'
---

# Sacred Geometry and Fractals

Trinity implements a comprehensive geometry and fractal library in `src/sacred/geometry.zig` (507 lines). This page documents Platonic and Archimedean solids, fractal dimensions, phyllotaxis, and their connections to the golden ratio and ternary architecture.

**Source**: `src/sacred/geometry.zig`, `src/sacred/const.zig`

---

## Platonic Solids

The five Platonic solids are the only convex regular polyhedra. Each has identical regular polygonal faces, equal edge lengths, and the same number of faces meeting at each vertex.

### Euler's Formula

<div class="formula">

**V - E + F = 2**

</div>

All Platonic solids satisfy Euler's polyhedron formula. This topological invariant connects to the Euler characteristic of the 2-sphere S^2 -- the same sphere that appears in the Poincare conjecture (Theorem 7).

### The Five Solids

| Solid | F | V | E | Face Type | Symmetry | Volume (a=1) | Dihedral Angle |
|-------|---|---|---|-----------|----------|-------------|----------------|
| **Tetrahedron** | 4 | 4 | 6 | Triangle | Td | 0.1179 | 70.53 |
| **Cube** | 6 | 8 | 12 | Square | Oh | 1.0000 | 90.00 |
| **Octahedron** | 8 | 6 | 12 | Triangle | Oh | 0.4714 | 109.47 |
| **Dodecahedron** | 12 | 20 | 30 | Pentagon | Ih | 7.6631 | 116.57 |
| **Icosahedron** | 20 | 12 | 30 | Triangle | Ih | 2.5362 | 138.19 |

### Golden Ratio in the Dodecahedron and Icosahedron

The dodecahedron and icosahedron are deeply connected to phi:

```
Dodecahedron circumradius = sqrt(3) * phi / 2 = 1.401
Dodecahedron midradius    = phi^2 / 2 = 1.309
Icosahedron midradius     = phi / 2 = 0.809
```

Both share the **icosahedral symmetry group Ih**, which has order 120 and is the largest symmetry group of any Platonic solid. The 20 vertices of a dodecahedron can be placed at the corners of three mutually orthogonal golden rectangles -- rectangles with aspect ratio phi.

**Reference**: Coxeter, H. S. M. *Regular Polytopes*. Dover Publications, 3rd edition, 1973. See Chapter 3 for the complete classification and the role of phi in icosahedral geometry.

---

## Archimedean Solids

The 13 Archimedean solids are semi-regular convex polyhedra: their faces are regular polygons of two or more types, and the same arrangement of faces occurs at each vertex. Trinity implements all 13:

| # | Solid | F | V | E | Face Types |
|---|-------|---|---|---|------------|
| 1 | Truncated Tetrahedron | 8 | 12 | 18 | 3, 6 |
| 2 | Cuboctahedron | 14 | 12 | 24 | 3, 4 |
| 3 | Truncated Cube | 14 | 24 | 36 | 3, 8 |
| 4 | Truncated Octahedron | 14 | 24 | 36 | 4, 6 |
| 5 | Rhombicuboctahedron | 26 | 24 | 48 | 3, 4 |
| 6 | Truncated Cuboctahedron | 26 | 48 | 72 | 4, 6, 8 |
| 7 | Snub Cube | 38 | 24 | 60 | 3, 4 |
| 8 | Icosidodecahedron | 32 | 30 | 60 | 3, 5 |
| 9 | Truncated Dodecahedron | 32 | 60 | 90 | 3, 10 |
| 10 | Truncated Icosahedron | 32 | 60 | 90 | 5, 6 |
| 11 | Rhombicosidodecahedron | 62 | 60 | 120 | 3, 4, 5 |
| 12 | Truncated Icosidodecahedron | 62 | 120 | 180 | 4, 6, 10 |
| 13 | Snub Dodecahedron | 92 | 60 | 150 | 3, 5 |

The **truncated icosahedron** (soccer ball / C60 fullerene) is notable: 12 pentagons + 20 hexagons = 32 faces, 60 vertices, 90 edges. Its structure encodes phi through the pentagon's diagonal/side ratio.

All 13 solids satisfy Euler's formula V - E + F = 2.

**Reference**: Cromwell, P. R. *Polyhedra*. Cambridge University Press, 1997.

---

## Golden Angle and Phyllotaxis

<div class="theorem-card">
<h4>Golden Angle</h4>

**theta = 360 / phi^2 = 137.508 degrees**

</div>

The golden angle divides a circle in the ratio phi : 1. Because phi is the most poorly approximable irrational number (all continued fraction coefficients are 1), successive points placed at the golden angle achieve **maximal angular separation** -- no two points ever align.

### Phyllotaxis Coordinates

Trinity computes leaf/seed placement on a spiral:

```
r(n) = c * sqrt(n)
theta(n) = n * golden_angle_rad
```

where c is a scaling constant. This produces the sunflower-like pattern seen in:
- Sunflower seed heads (Fibonacci spirals: 34 clockwise, 55 counterclockwise)
- Pine cone scales (8 and 13 spirals)
- Pineapple fruitlets (8, 13, 21 spirals)
- Artichoke bracts

The number of visible spirals in each direction are always **consecutive Fibonacci numbers** -- a consequence of the golden angle's connection to the Fibonacci limit (Theorem 5).

**Reference**: Jean, R. V. *Phyllotaxis: A Systemic Study in Plant Morphogenesis*. Cambridge University Press, 1994.

---

## Fractal Dimensions

<div class="theorem-card">
<h4>Hausdorff Dimension</h4>

The Hausdorff dimension of a self-similar fractal with N copies scaled by factor s is:

**d = ln(N) / ln(1/s)**

</div>

### Fractal Constants in Trinity

| Fractal | N | Scale | Dimension | Formula | OEIS |
|---------|---|-------|-----------|---------|------|
| **Sierpinski Triangle** | 3 | 1/2 | **1.585** | ln(3)/ln(2) | - |
| **Koch Snowflake** | 4 | 1/3 | **1.262** | ln(4)/ln(3) | - |
| **Menger Sponge** | 20 | 1/3 | **2.727** | ln(20)/ln(3) | - |
| **Cantor Set** | 2 | 1/3 | **0.631** | ln(2)/ln(3) | - |
| **Mandelbrot Boundary** | - | - | **2.000** | (exact) | - |

### The Sierpinski-Ternary Connection

The Sierpinski triangle dimension is especially significant for Trinity:

```
dim(Sierpinski) = ln(3) / ln(2) = 1.58496...
```

This is exactly **log2(3)** -- the information content of a single trit (Theorem 3). The Sierpinski triangle is the geometric embodiment of ternary information density.

The Menger sponge also involves base 3:

```
dim(Menger) = ln(20) / ln(3) = 2.72683...
```

Close to e = 2.71828..., the base of the optimal radix economy (Theorem 2).

### ASCII Fractal Generators

Trinity implements interactive fractal visualizations:

- **`sierpinskiDepth(n)`** -- Sierpinski triangle using the bitwise rule: draw at (x,y) if `(x AND y) == 0`
- **`mandelbrotASCII(cx, cy, zoom)`** -- Mandelbrot set with configurable center and zoom
- **`juliaASCII(c_re, c_im)`** -- Julia set for arbitrary complex parameter c
- **`barnsleyFern(iterations)`** -- Barnsley fern via iterated function system (IFS)

**Reference**: Mandelbrot, B. B. *The Fractal Geometry of Nature*. W. H. Freeman, 1982.

---

## Vesica Piscis

<div class="theorem-card">
<h4>Vesica Piscis</h4>

The lens-shaped region formed by the intersection of two circles of radius r whose centers are separated by distance r:

**width = r**

**height = r * sqrt(3)**

**area = (2*pi/3 - sqrt(3)/2) * r^2**

</div>

The aspect ratio of the Vesica Piscis is sqrt(3) = 1.732..., connecting it to the equilateral triangle and the hexagonal close-packing of circles.

---

## Golden Rectangle

<div class="theorem-card">
<h4>Golden Rectangle</h4>

A rectangle with sides a and a*phi:

**diagonal = a * sqrt(1 + phi^2) = a * sqrt(phi + 2)**

**area = a^2 * phi**

</div>

Removing a square from a golden rectangle yields a smaller golden rectangle -- self-similarity at the geometric level. This connects to the self-similarity property phi^2 = phi + 1 (Theorem 1).

---

## Penrose Tilings and Quasicrystals

Penrose tilings are aperiodic tilings of the plane using two tile shapes (kite and dart, or thick and thin rhombi). Their key properties:

- **No translational symmetry** -- the pattern never repeats
- **Five-fold rotational symmetry** -- forbidden in periodic crystals
- **phi ratios** -- kite diagonal/side = phi, dart diagonal/side = 1/phi
- **Deflation/inflation** -- each tile can be subdivided into smaller tiles of the same shapes, with frequencies in the ratio phi

The discovery of quasicrystals (Shechtman, 1982; Nobel Prize in Chemistry, 2011) showed that Penrose-like patterns exist in nature. The diffraction patterns of quasicrystals exhibit sharp Bragg peaks with five-fold symmetry, directly related to phi.

**Reference**: Penrose, R. "The Role of Aesthetics in Pure and Applied Mathematical Research." *Bulletin of the Institute of Mathematics and its Applications* 10, pp. 266--271, 1974.

---

## Connection to Trinity

### Ternary Structure in Geometry

| Geometric Object | Ternary Connection |
|-----------------|-------------------|
| Sierpinski triangle | dim = log2(3) = information per trit |
| Tetrahedron | Simplest 3D solid, 4 triangular faces |
| Euler's formula | V - E + F = **2** (characteristic of S^2) |
| Three spatial dimensions | 3 = phi^2 + 1/phi^2 = TRINITY |
| Icosahedral symmetry | Order 120 = 4! * 5, uses phi throughout |

### VSA and Geometry

The ternary hypervector space V_n = \{-1, 0, +1\}^n has geometric properties analogous to the solids documented here:

- **Concentration of measure** (Theorem 11): Random vectors cluster on a thin shell of radius sqrt(2n/3), analogous to how surface area dominates volume in high-dimensional spheres
- **Quasi-orthogonality** (Theorem 13): Random ternary vectors are nearly orthogonal with exponentially high probability, analogous to the vertex distribution on the icosahedron

---

## Try It with TRI CLI

```bash
tri math fractal         # Fractal dimensions + ASCII Sierpinski triangle
tri spiral 8             # 8 points on golden phi-spiral
tri math visual          # Sacred geometry visualizations
tri constants            # Golden angle, phi, sqrt constants
```

---

## References

1. Coxeter, H. S. M. *Regular Polytopes*. Dover Publications, 3rd edition, 1973.
2. Cromwell, P. R. *Polyhedra*. Cambridge University Press, 1997.
3. Mandelbrot, B. B. *The Fractal Geometry of Nature*. W. H. Freeman, 1982.
4. Penrose, R. "The Role of Aesthetics in Pure and Applied Mathematical Research." *Bulletin of the Institute of Mathematics and its Applications* 10, pp. 266--271, 1974.
5. Jean, R. V. *Phyllotaxis: A Systemic Study in Plant Morphogenesis*. Cambridge University Press, 1994.
6. Shechtman, D. et al. "Metallic Phase with Long-Range Orientational Order and No Translational Symmetry." *Physical Review Letters* 53(20), pp. 1951--1953, 1984.
7. Conway, J. H. and Sloane, N. J. A. *Sphere Packings, Lattices and Groups*. Springer-Verlag, 3rd edition, 1999.

---

**phi^2 + 1/phi^2 = 3 = TRINITY**
