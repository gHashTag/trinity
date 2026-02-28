#include "postgres.h"
#include "fmgr.h"
PG_MODULE_MAGIC;
PG_FUNCTION_INFO_V1(pg_trinity_bind);
Datum pg_trinity_bind(PG_FUNCTION_ARGS) {
    bytea *a = PG_GETARG_BYTEA_P(0);
    bytea *b = PG_GETARG_BYTEA_P(1);
    int32 len = VARSIZE(a) - VARHDRSZ;
    bytea *result = (bytea *) palloc(VARSIZE(a));
    SET_VARSIZE(result, VARSIZE(a));
    for (int i = 0; i < len; i++) *VARDATA(result) = *VARDATA(a) ^ *VARDATA(b);
    PG_RETURN_BYTEA_P(result);
}
PG_FUNCTION_INFO_V1(pg_trinity_unbind);
Datum pg_trinity_unbind(PG_FUNCTION_ARGS) { return pg_trinity_bind(fcinfo); }
PG_FUNCTION_INFO_V1(pg_trinity_bundle);
Datum pg_trinity_bundle(PG_FUNCTION_ARGS) {
    bytea *a = PG_GETARG_BYTEA_P(0);
    bytea *b = PG_GETARG_BYTEA_P(1);
    int32 len = VARSIZE(a) - VARHDRSZ;
    bytea *result = (bytea *) palloc(VARSIZE(a));
    SET_VARSIZE(result, VARSIZE(a));
    for (int i = 0; i < len; i++) *VARDATA(result) = *VARDATA(a) | *VARDATA(b);
    PG_RETURN_BYTEA_P(result);
}
