with Ada.Numerics.Float_Random;
with Ada.Numerics.Elementary_Functions;

package body Trinity_VSA is

   function Zeros (Dim : Positive) return Trit_Vector is
      Result : Trit_Vector (1 .. Dim) := (others => 0);
   begin
      return Result;
   end Zeros;

   function Random_Vector (Dim : Positive; Seed : Integer) return Trit_Vector is
      Gen : Ada.Numerics.Float_Random.Generator;
      Result : Trit_Vector (1 .. Dim);
   begin
      Ada.Numerics.Float_Random.Reset (Gen, Seed);
      for I in Result'Range loop
         Result (I) := Trit (Integer (Ada.Numerics.Float_Random.Random (Gen) * 3.0) - 1);
      end loop;
      return Result;
   end Random_Vector;

   function Bind (A, B : Trit_Vector) return Trit_Vector is
      Result : Trit_Vector (A'Range);
   begin
      for I in A'Range loop
         Result (I) := A (I) * B (I);
      end loop;
      return Result;
   end Bind;

   function Unbind (A, B : Trit_Vector) return Trit_Vector is
   begin
      return Bind (A, B);
   end Unbind;

   function Dot (A, B : Trit_Vector) return Long_Integer is
      Sum : Long_Integer := 0;
   begin
      for I in A'Range loop
         Sum := Sum + Long_Integer (A (I)) * Long_Integer (B (I));
      end loop;
      return Sum;
   end Dot;

   function Similarity (A, B : Trit_Vector) return Long_Float is
      use Ada.Numerics.Elementary_Functions;
      D : Long_Float := Long_Float (Dot (A, B));
      Norm_A : Long_Float := Sqrt (Long_Float (Dot (A, A)));
      Norm_B : Long_Float := Sqrt (Long_Float (Dot (B, B)));
   begin
      if Norm_A = 0.0 or Norm_B = 0.0 then
         return 0.0;
      end if;
      return D / (Norm_A * Norm_B);
   end Similarity;

   function Hamming_Distance (A, B : Trit_Vector) return Natural is
      Count : Natural := 0;
   begin
      for I in A'Range loop
         if A (I) /= B (I) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Hamming_Distance;

end Trinity_VSA;
