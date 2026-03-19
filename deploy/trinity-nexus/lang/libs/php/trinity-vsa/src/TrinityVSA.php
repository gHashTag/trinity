<?php
declare(strict_types=1);

namespace Trinity\VSA;

class TrinityVSA
{
    public static function zeros(int $dim): array
    {
        return array_fill(0, $dim, 0);
    }

    public static function random(int $dim, ?int $seed = null): array
    {
        if ($seed !== null) {
            mt_srand($seed);
        }
        $result = [];
        for ($i = 0; $i < $dim; $i++) {
            $result[] = mt_rand(0, 2) - 1;
        }
        return $result;
    }

    public static function bind(array $a, array $b): array
    {
        if (count($a) !== count($b)) {
            throw new \InvalidArgumentException('Dimension mismatch');
        }
        return array_map(fn($x, $y) => $x * $y, $a, $b);
    }

    public static function unbind(array $a, array $b): array
    {
        return self::bind($a, $b);
    }

    public static function bundle(array $vectors): array
    {
        if (empty($vectors)) {
            throw new \InvalidArgumentException('Empty vector list');
        }
        $dim = count($vectors[0]);
        $result = [];
        for ($i = 0; $i < $dim; $i++) {
            $sum = array_sum(array_column($vectors, $i));
            $result[] = $sum > 0 ? 1 : ($sum < 0 ? -1 : 0);
        }
        return $result;
    }

    public static function permute(array $v, int $shift): array
    {
        $dim = count($v);
        $result = array_fill(0, $dim, 0);
        for ($i = 0; $i < $dim; $i++) {
            $newIdx = (($i + $shift) % $dim + $dim) % $dim;
            $result[$newIdx] = $v[$i];
        }
        return $result;
    }

    public static function dot(array $a, array $b): int
    {
        if (count($a) !== count($b)) {
            throw new \InvalidArgumentException('Dimension mismatch');
        }
        return array_sum(array_map(fn($x, $y) => $x * $y, $a, $b));
    }

    public static function similarity(array $a, array $b): float
    {
        $d = self::dot($a, $b);
        $normA = sqrt(self::dot($a, $a));
        $normB = sqrt(self::dot($b, $b));
        if ($normA == 0 || $normB == 0) {
            return 0.0;
        }
        return $d / ($normA * $normB);
    }

    public static function hammingDistance(array $a, array $b): int
    {
        if (count($a) !== count($b)) {
            throw new \InvalidArgumentException('Dimension mismatch');
        }
        return count(array_filter(
            array_map(fn($x, $y) => $x !== $y, $a, $b)
        ));
    }
}
