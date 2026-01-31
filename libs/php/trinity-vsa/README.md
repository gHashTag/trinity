# Trinity VSA for PHP

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```
composer require trinity/vsa
```

## Quick Start

```php
<?php
use Trinity\VSA\TrinityVSA;

$apple = TrinityVSA::random(10000, 42);
$red = TrinityVSA::random(10000, 123);

$redApple = TrinityVSA::bind($apple, $red);
echo "Similarity: " . TrinityVSA::similarity($redApple, $apple) . "\n";

$recovered = TrinityVSA::unbind($redApple, $red);
echo "Recovery: " . TrinityVSA::similarity($recovered, $apple) . "\n";
```

## License

MIT License
