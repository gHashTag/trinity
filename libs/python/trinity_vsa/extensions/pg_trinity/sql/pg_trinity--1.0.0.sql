-- pg_trinity: Trinity Vector Symbolic Architecture for PostgreSQL

-- Load the shared library
LOAD 'pg_trinity';

-- Create trinity_vector type (stored as bytea)
CREATE TYPE trinity_vector;

-- Create function for binding two vectors
CREATE FUNCTION pg_trinity_bind(a trinity_vector, b trinity_vector)
RETURNS trinity_vector
AS 'MODULE_PATHNAME', 'pg_trinity_bind'
LANGUAGE C IMMUTABLE STRICT;

-- Create function for unbinding
CREATE FUNCTION pg_trinity_unbind(bound trinity_vector, key trinity_vector)
RETURNS trinity_vector
AS 'MODULE_PATHNAME', 'pg_trinity_unbind'
LANGUAGE C IMMUTABLE STRICT;

-- Create function for bundling (majority vote)
CREATE FUNCTION pg_trinity_bundle(a trinity_vector, b trinity_vector)
RETURNS trinity_vector
AS 'MODULE_PATHNAME', 'pg_trinity_bundle'
LANGUAGE C IMMUTABLE STRICT;

-- Create operator for cosine similarity
CREATE FUNCTION trinity_cosine_similarity(a trinity_vector, b trinity_vector)
RETURNS float8
AS 'MODULE_PATHNAME', 'trinity_cosine_similarity'
LANGUAGE C IMMUTABLE STRICT;

-- Create operator for Hamming distance
CREATE FUNCTION trinity_hamming_distance(a trinity_vector, b trinity_vector)
RETURNS int4
AS 'MODULE_PATHNAME', 'trinity_hamming_distance'
LANGUAGE C IMMUTABLE STRICT;

-- Create operators
CREATE OPERATOR %% (
    PROCEDURE = trinity_cosine_similarity,
    LEFTARG = trinity_vector,
    RIGHTARG = trinity_vector,
    COMMUTATOR = %%
);

CREATE OPERATOR #@ (
    PROCEDURE = trinity_hamming_distance,
    LEFTARG = trinity_vector,
    RIGHTARG = trinity_vector,
    COMMUTATOR = #@
);
