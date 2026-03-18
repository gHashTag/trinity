-- Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
package Trinity_VSA is

   type Trit is range -1 .. 1;
   type Trit_Vector is array (Positive range <>) of Trit;

   function Zeros (Dim : Positive) return Trit_Vector;
   function Random_Vector (Dim : Positive; Seed : Integer) return Trit_Vector;
   
   function Bind (A, B : Trit_Vector) return Trit_Vector;
   function Unbind (A, B : Trit_Vector) return Trit_Vector;
   
   function Dot (A, B : Trit_Vector) return Long_Integer;
   function Similarity (A, B : Trit_Vector) return Long_Float;
   function Hamming_Distance (A, B : Trit_Vector) return Natural;

end Trinity_VSA;
