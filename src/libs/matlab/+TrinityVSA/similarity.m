function s = similarity(a, b)
%SIMILARITY Cosine similarity
%   s = TrinityVSA.similarity(a, b) returns similarity in [-1, 1]
    assert(length(a) == length(b), 'Dimension mismatch');
    d = double(a)' * double(b);
    norm_a = sqrt(double(a)' * double(a));
    norm_b = sqrt(double(b)' * double(b));
    if norm_a == 0 || norm_b == 0
        s = 0;
    else
        s = d / (norm_a * norm_b);
    end
end
