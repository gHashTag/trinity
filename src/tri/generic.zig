//! tri/generic — Generic type utilities
//! Selector file for generated code

const generated = @import("gen_generic.zig");

pub const SizeOf = generated.SizeOf;
pub const AlignOf = generated.AlignOf;
pub const isInt = generated.isInt;
pub const isFloat = generated.isFloat;
pub const isNumber = generated.isNumber;
pub const isOptional = generated.isOptional;
pub const isErrorUnion = generated.isErrorUnion;
pub const isSlice = generated.isSlice;
pub const isPointer = generated.isPointer;
pub const isArray = generated.isArray;
pub const ElemType = generated.ElemType;
pub const Len = generated.Len;
pub const Identity = generated.Identity;
pub const Const = generated.Const;
pub const Mut = generated.Mut;
pub const Slice = generated.Slice;
pub const Optional = generated.Optional;
pub const Max = generated.Max;
pub const Min = generated.Min;
pub const Clamp = generated.Clamp;
pub const Swap = generated.Swap;
