# Trinity VSA for Ada

Vector Symbolic Architecture with balanced ternary arithmetic.

## Quick Start

```ada
with Trinity_VSA; use Trinity_VSA;
with Ada.Text_IO; use Ada.Text_IO;

procedure Example is
   Apple : Trit_Vector := Random_Vector (10000, 42);
   Red : Trit_Vector := Random_Vector (10000, 123);
   Red_Apple : Trit_Vector := Bind (Apple, Red);
begin
   Put_Line ("Similarity: " & Long_Float'Image (Similarity (Red_Apple, Apple)));
end Example;
```

## License

MIT License
