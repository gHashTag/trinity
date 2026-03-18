function v = random(dim, seed)
%RANDOM Create random trit vector
%   v = TrinityVSA.random(dim) creates random vector
%   v = TrinityVSA.random(dim, seed) with specific seed
    if nargin > 1
        rng(seed);
    end
    v = int8(randi(3, dim, 1) - 2);
end
