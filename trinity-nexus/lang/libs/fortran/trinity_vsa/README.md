# Trinity VSA for Fortran

Vector Symbolic Architecture with balanced ternary arithmetic.

## Compilation

```bash
gfortran -c src/trinity_vsa.f90 -o trinity_vsa.o
ar rcs libtrinityvsa.a trinity_vsa.o
```

## Quick Start

```fortran
program example
    use trinity_vsa
    implicit none
    
    integer, parameter :: dim = 10000
    integer(1) :: apple(dim), red(dim), red_apple(dim), recovered(dim)
    real(8) :: sim, recovery
    
    call trit_random(apple, dim, 42)
    call trit_random(red, dim, 123)
    
    call trit_bind(red_apple, apple, red, dim)
    sim = trit_similarity(red_apple, apple, dim)
    print '(A,F6.3)', 'Similarity: ', sim
    
    call trit_unbind(recovered, red_apple, red, dim)
    recovery = trit_similarity(recovered, apple, dim)
    print '(A,F6.3)', 'Recovery: ', recovery
end program
```

## API

| Subroutine/Function | Description |
|---------------------|-------------|
| `trit_zeros(v, dim)` | Create zero vector |
| `trit_random(v, dim, seed)` | Create random vector |
| `trit_bind(c, a, b, dim)` | Bind two vectors |
| `trit_unbind(c, a, b, dim)` | Unbind |
| `trit_bundle(c, vectors, nvec, dim)` | Bundle |
| `trit_permute(c, v, dim, shift)` | Circular shift |
| `trit_dot(a, b, dim)` | Dot product |
| `trit_similarity(a, b, dim)` | Cosine similarity |

## License

MIT License
