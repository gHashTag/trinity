{-# LANGUAGE BangPatterns #-}
-- | Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
module TrinityVSA
  ( Trit(..)
  , TritVector
  , zeros
  , random
  , bind
  , unbind
  , bundle
  , permute
  , dot
  , similarity
  , hammingDistance
  ) where

import qualified Data.Vector.Unboxed as V
import System.Random (mkStdGen, randomRs)

-- | Balanced ternary value: -1, 0, or +1
type Trit = Int

-- | Dense vector of trits
type TritVector = V.Vector Trit

-- | Create zero vector
zeros :: Int -> TritVector
zeros dim = V.replicate dim 0

-- | Create random vector
random :: Int -> Int -> TritVector
random dim seed = V.fromList $ take dim $ map (\x -> x `mod` 3 - 1) $ randomRs (0, 2) (mkStdGen seed)

-- | Bind two vectors (element-wise multiplication)
bind :: TritVector -> TritVector -> TritVector
bind = V.zipWith (*)

-- | Unbind (inverse of bind)
unbind :: TritVector -> TritVector -> TritVector
unbind = bind

-- | Bundle vectors via majority voting
bundle :: [TritVector] -> TritVector
bundle [] = error "Empty vector list"
bundle vs = V.generate dim $ \i ->
  let s = sum [v V.! i | v <- vs]
  in if s > 0 then 1 else if s < 0 then -1 else 0
  where dim = V.length (head vs)

-- | Circular permutation
permute :: TritVector -> Int -> TritVector
permute v shift = V.generate dim $ \i ->
  v V.! ((i - shift) `mod` dim)
  where dim = V.length v

-- | Dot product
dot :: TritVector -> TritVector -> Int
dot a b = V.sum $ V.zipWith (*) a b

-- | Cosine similarity
similarity :: TritVector -> TritVector -> Double
similarity a b
  | normA == 0 || normB == 0 = 0
  | otherwise = fromIntegral (dot a b) / (normA * normB)
  where
    normA = sqrt $ fromIntegral $ dot a a
    normB = sqrt $ fromIntegral $ dot b b

-- | Hamming distance
hammingDistance :: TritVector -> TritVector -> Int
hammingDistance a b = V.length $ V.filter id $ V.zipWith (/=) a b
