!> Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
module trinity_vsa
    implicit none
    private
    
    public :: trit_zeros, trit_random, trit_bind, trit_unbind
    public :: trit_bundle, trit_permute, trit_dot, trit_similarity
    public :: trit_hamming, trit_nnz, trit_sparsity
    
contains

    !> Create zero trit vector
    subroutine trit_zeros(v, dim)
        integer, intent(in) :: dim
        integer(1), intent(out) :: v(dim)
        v = 0
    end subroutine

    !> Create random trit vector
    subroutine trit_random(v, dim, seed)
        integer, intent(in) :: dim
        integer, intent(in), optional :: seed
        integer(1), intent(out) :: v(dim)
        real :: r
        integer :: i
        
        if (present(seed)) call random_seed(put=[seed])
        
        do i = 1, dim
            call random_number(r)
            v(i) = int(r * 3.0, 1) - 1
        end do
    end subroutine

    !> Bind two vectors (element-wise multiplication)
    subroutine trit_bind(c, a, b, dim)
        integer, intent(in) :: dim
        integer(1), intent(in) :: a(dim), b(dim)
        integer(1), intent(out) :: c(dim)
        c = a * b
    end subroutine

    !> Unbind (inverse of bind)
    subroutine trit_unbind(c, a, b, dim)
        integer, intent(in) :: dim
        integer(1), intent(in) :: a(dim), b(dim)
        integer(1), intent(out) :: c(dim)
        call trit_bind(c, a, b, dim)
    end subroutine

    !> Bundle vectors via majority voting
    subroutine trit_bundle(c, vectors, nvec, dim)
        integer, intent(in) :: nvec, dim
        integer(1), intent(in) :: vectors(dim, nvec)
        integer(1), intent(out) :: c(dim)
        integer :: i, j, s
        
        do i = 1, dim
            s = 0
            do j = 1, nvec
                s = s + vectors(i, j)
            end do
            if (s > 0) then
                c(i) = 1
            else if (s < 0) then
                c(i) = -1
            else
                c(i) = 0
            end if
        end do
    end subroutine

    !> Circular permutation
    subroutine trit_permute(c, v, dim, shift)
        integer, intent(in) :: dim, shift
        integer(1), intent(in) :: v(dim)
        integer(1), intent(out) :: c(dim)
        integer :: i, new_idx
        
        do i = 1, dim
            new_idx = mod(i - 1 + shift, dim) + 1
            if (new_idx < 1) new_idx = new_idx + dim
            c(new_idx) = v(i)
        end do
    end subroutine

    !> Dot product
    function trit_dot(a, b, dim) result(d)
        integer, intent(in) :: dim
        integer(1), intent(in) :: a(dim), b(dim)
        integer(8) :: d
        d = sum(int(a, 8) * int(b, 8))
    end function

    !> Cosine similarity
    function trit_similarity(a, b, dim) result(s)
        integer, intent(in) :: dim
        integer(1), intent(in) :: a(dim), b(dim)
        real(8) :: s, d, norm_a, norm_b
        
        d = real(trit_dot(a, b, dim), 8)
        norm_a = sqrt(real(trit_dot(a, a, dim), 8))
        norm_b = sqrt(real(trit_dot(b, b, dim), 8))
        
        if (norm_a == 0.0d0 .or. norm_b == 0.0d0) then
            s = 0.0d0
        else
            s = d / (norm_a * norm_b)
        end if
    end function

    !> Hamming distance
    function trit_hamming(a, b, dim) result(h)
        integer, intent(in) :: dim
        integer(1), intent(in) :: a(dim), b(dim)
        integer :: h
        h = count(a /= b)
    end function

    !> Number of non-zero elements
    function trit_nnz(v, dim) result(n)
        integer, intent(in) :: dim
        integer(1), intent(in) :: v(dim)
        integer :: n
        n = count(v /= 0)
    end function

    !> Sparsity (fraction of zeros)
    function trit_sparsity(v, dim) result(s)
        integer, intent(in) :: dim
        integer(1), intent(in) :: v(dim)
        real(8) :: s
        s = 1.0d0 - real(trit_nnz(v, dim), 8) / real(dim, 8)
    end function

end module trinity_vsa
