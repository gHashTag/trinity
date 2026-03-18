"""
Native ctypes binding to libtrinity-vsa (Zig/SIMD backend).

Uses the real SIMD-accelerated Zig core via C FFI.
~20x faster than the pure-Python numpy implementation.

Usage:
    from trinity_vsa.native import NativeVSA

    vsa = NativeVSA()  # auto-detects library path
    v1 = vsa.encode_text("machine learning")
    v2 = vsa.encode_text("deep learning")
    print(vsa.similarity(v1, v2))
    vsa.free(v1)
    vsa.free(v2)

Or use the Vector wrapper for automatic memory management:
    from trinity_vsa.native import NativeVSA, Vector

    vsa = NativeVSA()
    v1 = Vector(vsa, text="machine learning")
    v2 = Vector(vsa, text="deep learning")
    print(v1.similarity(v2))
    # Vectors freed automatically when garbage collected
"""

import ctypes
import ctypes.util
import os
import platform
from pathlib import Path
from typing import List, Optional, Tuple


class NativeVSA:
    """Wrapper around libtrinity-vsa shared library.

    All vector operations return opaque handles (int).
    Call free() on every vector when done, or use the Vector class.
    """

    def __init__(self, lib_path: Optional[str] = None):
        """Load the native library.

        Args:
            lib_path: Explicit path to libtrinity-vsa.dylib/.so.
                      If None, searches common locations.
        """
        self._lib = self._load(lib_path)
        self._setup_prototypes()

    @staticmethod
    def _load(lib_path: Optional[str] = None) -> ctypes.CDLL:
        """Find and load the shared library."""
        if lib_path and os.path.exists(lib_path):
            return ctypes.CDLL(lib_path)

        system = platform.system()
        if system == "Darwin":
            lib_name = "libtrinity-vsa.dylib"
        elif system == "Linux":
            lib_name = "libtrinity-vsa.so"
        elif system == "Windows":
            lib_name = "trinity-vsa.dll"
        else:
            raise RuntimeError(f"Unsupported platform: {system}")

        # Search paths (project-relative and system)
        search_paths = [
            # Relative to this file (installed alongside)
            Path(__file__).parent / lib_name,
            # Project build output
            Path(__file__).parents[5] / "zig-out" / "lib" / lib_name,
            # Common install locations
            Path("/usr/local/lib") / lib_name,
            Path("/usr/lib") / lib_name,
        ]

        # Also check LD_LIBRARY_PATH / DYLD_LIBRARY_PATH
        env_paths = os.environ.get(
            "DYLD_LIBRARY_PATH" if system == "Darwin" else "LD_LIBRARY_PATH", ""
        )
        for p in env_paths.split(":"):
            if p:
                search_paths.append(Path(p) / lib_name)

        for path in search_paths:
            if path.exists():
                return ctypes.CDLL(str(path))

        # Last resort: let the OS find it
        found = ctypes.util.find_library("trinity-vsa")
        if found:
            return ctypes.CDLL(found)

        raise FileNotFoundError(
            f"Cannot find {lib_name}. Build with 'zig build libvsa' or set lib_path."
        )

    def _setup_prototypes(self):
        """Declare C function signatures for type safety."""
        L = self._lib
        c_void_p = ctypes.c_void_p
        c_size_t = ctypes.c_size_t
        c_uint64 = ctypes.c_uint64
        c_double = ctypes.c_double
        c_int64 = ctypes.c_int64
        c_int8 = ctypes.c_int8
        c_char_p = ctypes.c_char_p

        # -- Info --
        L.trinity_vsa_version.restype = c_char_p
        L.trinity_vsa_version.argtypes = []

        L.trinity_vsa_max_dim.restype = c_size_t
        L.trinity_vsa_max_dim.argtypes = []

        # -- Lifecycle --
        L.trinity_vsa_vector_zeros.restype = c_void_p
        L.trinity_vsa_vector_zeros.argtypes = [c_size_t]

        L.trinity_vsa_vector_random.restype = c_void_p
        L.trinity_vsa_vector_random.argtypes = [c_size_t, c_uint64]

        L.trinity_vsa_from_array.restype = c_void_p
        L.trinity_vsa_from_array.argtypes = [ctypes.POINTER(c_int8), c_size_t]

        L.trinity_vsa_vector_clone.restype = c_void_p
        L.trinity_vsa_vector_clone.argtypes = [c_void_p]

        L.trinity_vsa_vector_free.restype = None
        L.trinity_vsa_vector_free.argtypes = [c_void_p]

        # -- VSA Operations --
        L.trinity_vsa_bind.restype = c_void_p
        L.trinity_vsa_bind.argtypes = [c_void_p, c_void_p]

        L.trinity_vsa_unbind.restype = c_void_p
        L.trinity_vsa_unbind.argtypes = [c_void_p, c_void_p]

        L.trinity_vsa_bundle2.restype = c_void_p
        L.trinity_vsa_bundle2.argtypes = [c_void_p, c_void_p]

        L.trinity_vsa_bundle3.restype = c_void_p
        L.trinity_vsa_bundle3.argtypes = [c_void_p, c_void_p, c_void_p]

        L.trinity_vsa_permute.restype = c_void_p
        L.trinity_vsa_permute.argtypes = [c_void_p, c_size_t]

        # -- Similarity --
        L.trinity_vsa_cosine_similarity.restype = c_double
        L.trinity_vsa_cosine_similarity.argtypes = [c_void_p, c_void_p]

        L.trinity_vsa_hamming_distance.restype = c_size_t
        L.trinity_vsa_hamming_distance.argtypes = [c_void_p, c_void_p]

        L.trinity_vsa_dot_product.restype = c_int64
        L.trinity_vsa_dot_product.argtypes = [c_void_p, c_void_p]

        # -- Text Encoding --
        L.trinity_vsa_encode_text.restype = c_void_p
        L.trinity_vsa_encode_text.argtypes = [c_char_p, c_size_t]

        L.trinity_vsa_encode_text_words.restype = c_void_p
        L.trinity_vsa_encode_text_words.argtypes = [c_char_p, c_size_t]

        L.trinity_vsa_decode_text.restype = c_size_t
        L.trinity_vsa_decode_text.argtypes = [c_void_p, ctypes.c_char_p, c_size_t]

        # -- Vector Access --
        L.trinity_vsa_get_dim.restype = c_size_t
        L.trinity_vsa_get_dim.argtypes = [c_void_p]

        L.trinity_vsa_get_trit.restype = c_int8
        L.trinity_vsa_get_trit.argtypes = [c_void_p, c_size_t]

        L.trinity_vsa_set_trit.restype = None
        L.trinity_vsa_set_trit.argtypes = [c_void_p, c_size_t, c_int8]

        L.trinity_vsa_to_array.restype = c_size_t
        L.trinity_vsa_to_array.argtypes = [c_void_p, ctypes.POINTER(c_int8), c_size_t]

    # ── Info ─────────────────────────────────────────────────────────────

    def version(self) -> str:
        """Library version string."""
        return self._lib.trinity_vsa_version().decode("utf-8")

    def max_dim(self) -> int:
        """Maximum vector dimension (59049)."""
        return self._lib.trinity_vsa_max_dim()

    # ── Vector Creation ──────────────────────────────────────────────────

    def zeros(self, dim: int) -> int:
        """Create zero vector. Returns handle (must free)."""
        h = self._lib.trinity_vsa_vector_zeros(dim)
        if not h:
            raise MemoryError("Failed to allocate vector")
        return h

    def random(self, dim: int, seed: int = 42) -> int:
        """Create random hypervector. Returns handle (must free)."""
        h = self._lib.trinity_vsa_vector_random(dim, seed)
        if not h:
            raise MemoryError("Failed to allocate vector")
        return h

    def from_array(self, data: list) -> int:
        """Create vector from list of int8 values [-1, 0, +1]. Returns handle."""
        arr = (ctypes.c_int8 * len(data))(*data)
        h = self._lib.trinity_vsa_from_array(arr, len(data))
        if not h:
            raise MemoryError("Failed to allocate vector")
        return h

    def clone(self, v: int) -> int:
        """Deep copy a vector. Returns new handle (must free)."""
        h = self._lib.trinity_vsa_vector_clone(v)
        if not h:
            raise MemoryError("Failed to clone vector")
        return h

    def free(self, v: int) -> None:
        """Free a vector handle. Safe to call with None/0."""
        self._lib.trinity_vsa_vector_free(v)

    # ── VSA Operations ───────────────────────────────────────────────────

    def bind(self, a: int, b: int) -> int:
        """Bind two vectors (element-wise multiply). Returns new handle."""
        h = self._lib.trinity_vsa_bind(a, b)
        if not h:
            raise MemoryError("bind failed")
        return h

    def unbind(self, bound: int, key: int) -> int:
        """Unbind (inverse of bind). Returns new handle."""
        h = self._lib.trinity_vsa_unbind(bound, key)
        if not h:
            raise MemoryError("unbind failed")
        return h

    def bundle2(self, a: int, b: int) -> int:
        """Bundle 2 vectors (majority vote). Returns new handle."""
        h = self._lib.trinity_vsa_bundle2(a, b)
        if not h:
            raise MemoryError("bundle2 failed")
        return h

    def bundle3(self, a: int, b: int, c: int) -> int:
        """Bundle 3 vectors (majority vote). Returns new handle."""
        h = self._lib.trinity_vsa_bundle3(a, b, c)
        if not h:
            raise MemoryError("bundle3 failed")
        return h

    def permute(self, v: int, shift: int) -> int:
        """Cyclic permutation. Returns new handle."""
        h = self._lib.trinity_vsa_permute(v, shift)
        if not h:
            raise MemoryError("permute failed")
        return h

    # ── Similarity ───────────────────────────────────────────────────────

    def similarity(self, a: int, b: int) -> float:
        """Cosine similarity in [-1.0, 1.0]."""
        return self._lib.trinity_vsa_cosine_similarity(a, b)

    def hamming(self, a: int, b: int) -> int:
        """Hamming distance (differing trits)."""
        return self._lib.trinity_vsa_hamming_distance(a, b)

    def dot(self, a: int, b: int) -> int:
        """Dot product."""
        return self._lib.trinity_vsa_dot_product(a, b)

    # ── Text Encoding ────────────────────────────────────────────────────

    def encode_text(self, text: str) -> int:
        """Encode text (character-level positional). Returns handle."""
        b = text.encode("utf-8")
        h = self._lib.trinity_vsa_encode_text(b, len(b))
        if not h:
            raise MemoryError("encode_text failed")
        return h

    def encode_text_words(self, text: str) -> int:
        """Encode text (word-level bag-of-words). Better for search. Returns handle."""
        b = text.encode("utf-8")
        h = self._lib.trinity_vsa_encode_text_words(b, len(b))
        if not h:
            raise MemoryError("encode_text_words failed")
        return h

    def decode_text(self, v: int, max_len: int = 64) -> str:
        """Decode hypervector back to text (character-level)."""
        buf = ctypes.create_string_buffer(max_len)
        n = self._lib.trinity_vsa_decode_text(v, buf, max_len)
        return buf.raw[:n].decode("utf-8", errors="replace")

    # ── Vector Access ────────────────────────────────────────────────────

    def dim(self, v: int) -> int:
        """Get vector dimension."""
        return self._lib.trinity_vsa_get_dim(v)

    def get_trit(self, v: int, index: int) -> int:
        """Get trit value at index (-1, 0, +1)."""
        return self._lib.trinity_vsa_get_trit(v, index)

    def set_trit(self, v: int, index: int, value: int) -> None:
        """Set trit value at index (clamped to {-1, 0, +1})."""
        self._lib.trinity_vsa_set_trit(v, index, value)

    def to_list(self, v: int) -> list:
        """Export vector to list of int8 values."""
        d = self.dim(v)
        arr = (ctypes.c_int8 * d)()
        n = self._lib.trinity_vsa_to_array(v, arr, d)
        return list(arr[:n])

    # ── Search ───────────────────────────────────────────────────────────

    def search(
        self, query: str, corpus: List[str], top_n: int = 10
    ) -> List[Tuple[float, int, str]]:
        """Search corpus for most similar texts.

        Args:
            query: Query text
            corpus: List of text strings
            top_n: Number of results to return

        Returns:
            List of (similarity, index, text) tuples, sorted by similarity descending.
        """
        q = self.encode_text_words(query)
        results = []
        handles = []

        for i, text in enumerate(corpus):
            h = self.encode_text_words(text)
            sim = self.similarity(q, h)
            results.append((sim, i, text))
            handles.append(h)

        # Cleanup
        self.free(q)
        for h in handles:
            self.free(h)

        results.sort(key=lambda x: x[0], reverse=True)
        return results[:top_n]


class Vector:
    """RAII wrapper around a native vector handle.

    Automatically frees the vector when garbage collected.

    Usage:
        vsa = NativeVSA()
        v = Vector(vsa, random=(1000, 42))
        w = Vector(vsa, text="hello world")
        print(v.similarity(w))
    """

    def __init__(
        self,
        vsa: NativeVSA,
        *,
        handle: Optional[int] = None,
        zeros: Optional[int] = None,
        random: Optional[Tuple[int, int]] = None,
        text: Optional[str] = None,
        text_words: Optional[str] = None,
        data: Optional[list] = None,
    ):
        self._vsa = vsa
        if handle is not None:
            self._handle = handle
        elif zeros is not None:
            self._handle = vsa.zeros(zeros)
        elif random is not None:
            dim, seed = random
            self._handle = vsa.random(dim, seed)
        elif text is not None:
            self._handle = vsa.encode_text(text)
        elif text_words is not None:
            self._handle = vsa.encode_text_words(text_words)
        elif data is not None:
            self._handle = vsa.from_array(data)
        else:
            raise ValueError("Provide one of: handle, zeros, random, text, text_words, data")

    @property
    def handle(self) -> int:
        return self._handle

    @property
    def dim(self) -> int:
        return self._vsa.dim(self._handle)

    def similarity(self, other: "Vector") -> float:
        return self._vsa.similarity(self._handle, other._handle)

    def hamming(self, other: "Vector") -> int:
        return self._vsa.hamming(self._handle, other._handle)

    def dot(self, other: "Vector") -> int:
        return self._vsa.dot(self._handle, other._handle)

    def bind(self, other: "Vector") -> "Vector":
        h = self._vsa.bind(self._handle, other._handle)
        return Vector(self._vsa, handle=h)

    def unbind(self, key: "Vector") -> "Vector":
        h = self._vsa.unbind(self._handle, key._handle)
        return Vector(self._vsa, handle=h)

    def bundle(self, other: "Vector") -> "Vector":
        h = self._vsa.bundle2(self._handle, other._handle)
        return Vector(self._vsa, handle=h)

    def permute(self, shift: int) -> "Vector":
        h = self._vsa.permute(self._handle, shift)
        return Vector(self._vsa, handle=h)

    def clone(self) -> "Vector":
        h = self._vsa.clone(self._handle)
        return Vector(self._vsa, handle=h)

    def to_list(self) -> list:
        return self._vsa.to_list(self._handle)

    def __del__(self):
        if hasattr(self, "_handle") and self._handle:
            self._vsa.free(self._handle)
            self._handle = None

    def __repr__(self):
        return f"Vector(dim={self.dim})"
