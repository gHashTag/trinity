function c = permute(v, shift)
%PERMUTE Circular permutation
%   c = TrinityVSA.permute(v, shift) shifts vector circularly
    c = circshift(v, shift);
end
