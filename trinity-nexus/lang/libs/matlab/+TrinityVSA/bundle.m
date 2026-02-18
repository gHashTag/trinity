function c = bundle(vectors)
%BUNDLE Bundle vectors via majority voting
%   c = TrinityVSA.bundle(vectors) where vectors is a cell array
    n = length(vectors);
    dim = length(vectors{1});
    c = int8(zeros(dim, 1));
    
    for i = 1:dim
        s = 0;
        for j = 1:n
            s = s + double(vectors{j}(i));
        end
        if s > 0
            c(i) = 1;
        elseif s < 0
            c(i) = -1;
        end
    end
end
