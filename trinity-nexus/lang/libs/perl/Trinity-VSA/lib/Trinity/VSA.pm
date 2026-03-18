package Trinity::VSA;
use strict;
use warnings;
use List::Util qw(sum);
use POSIX qw(floor);

our $VERSION = '0.01';

sub zeros {
    my ($dim) = @_;
    return [(0) x $dim];
}

sub random {
    my ($dim, $seed) = @_;
    srand($seed) if defined $seed;
    return [map { int(rand(3)) - 1 } 1..$dim];
}

sub bind {
    my ($a, $b) = @_;
    die "Dimension mismatch" unless @$a == @$b;
    return [map { $a->[$_] * $b->[$_] } 0..$#$a];
}

sub unbind {
    my ($a, $b) = @_;
    return bind($a, $b);
}

sub bundle {
    my ($vectors) = @_;
    die "Empty vector list" unless @$vectors;
    my $dim = @{$vectors->[0]};
    my @result;
    for my $i (0..$dim-1) {
        my $s = sum(map { $_->[$i] } @$vectors);
        push @result, $s > 0 ? 1 : ($s < 0 ? -1 : 0);
    }
    return \@result;
}

sub permute {
    my ($v, $shift) = @_;
    my $dim = @$v;
    my @result = (0) x $dim;
    for my $i (0..$dim-1) {
        my $new_idx = ($i + $shift) % $dim;
        $result[$new_idx] = $v->[$i];
    }
    return \@result;
}

sub dot {
    my ($a, $b) = @_;
    die "Dimension mismatch" unless @$a == @$b;
    return sum(map { $a->[$_] * $b->[$_] } 0..$#$a);
}

sub similarity {
    my ($a, $b) = @_;
    my $d = dot($a, $b);
    my $norm_a = sqrt(dot($a, $a));
    my $norm_b = sqrt(dot($b, $b));
    return 0 if $norm_a == 0 || $norm_b == 0;
    return $d / ($norm_a * $norm_b);
}

sub hamming_distance {
    my ($a, $b) = @_;
    die "Dimension mismatch" unless @$a == @$b;
    return scalar grep { $a->[$_] != $b->[$_] } 0..$#$a;
}

1;

__END__

=head1 NAME

Trinity::VSA - Vector Symbolic Architecture with balanced ternary arithmetic

=head1 SYNOPSIS

    use Trinity::VSA;
    
    my $apple = Trinity::VSA::random(10000, 42);
    my $red = Trinity::VSA::random(10000, 123);
    my $red_apple = Trinity::VSA::bind($apple, $red);
    print "Similarity: ", Trinity::VSA::similarity($red_apple, $apple), "\n";

=head1 LICENSE

MIT License

=cut
