# Trinity::VSA

Vector Symbolic Architecture with balanced ternary arithmetic for Perl.

## Installation

```
cpanm Trinity::VSA
```

## Quick Start

```perl
use Trinity::VSA;

my $apple = Trinity::VSA::random(10000, 42);
my $red = Trinity::VSA::random(10000, 123);

my $red_apple = Trinity::VSA::bind($apple, $red);
print "Similarity: ", Trinity::VSA::similarity($red_apple, $apple), "\n";

my $recovered = Trinity::VSA::unbind($red_apple, $red);
print "Recovery: ", Trinity::VSA::similarity($recovered, $apple), "\n";
```

## License

MIT License
