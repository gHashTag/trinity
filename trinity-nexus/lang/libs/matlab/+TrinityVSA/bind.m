function c = bind(a, b)
%BIND Bind two trit vectors (element-wise multiplication)
%   c = TrinityVSA.bind(a, b) returns element-wise product
    assert(length(a) == length(b), 'Dimension mismatch');
    c = int8(a .* b);
end
