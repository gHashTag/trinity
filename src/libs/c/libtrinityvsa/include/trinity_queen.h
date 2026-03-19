/**
 * @file trinity_queen.h
 * @brief Trinity Queen API — Dashboard data for SwiftUI
 *
 * Buffer-based JSON API. Each function writes JSON into a provided buffer
 * and returns the number of bytes written. Zero means error/empty.
 *
 * @version 1.0.0
 * @license MIT
 */

#ifndef TRINITY_QUEEN_H
#define TRINITY_QUEEN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Library version string */
const char* trinity_queen_version(void);

/** Sacred mathematical constants (phi, 3^k, predictions) */
size_t trinity_queen_sacred_constants(char* buf, size_t len);

/** Ouroboros cycle state */
size_t trinity_queen_ouroboros_state(char* buf, size_t len);

/** Faculty agent snapshot (heartbeats, status) */
size_t trinity_queen_faculty_snapshot(char* buf, size_t len);

/** Last N farm events from events.jsonl */
size_t trinity_queen_farm_events(char* buf, size_t len, size_t last_n);

/** Swarm state */
size_t trinity_queen_swarm_state(char* buf, size_t len);

/** Build status (binaries, test results) */
size_t trinity_queen_build_status(char* buf, size_t len);

/** Patent filing status */
size_t trinity_queen_patent_status(char* buf, size_t len);

/** Technology dependency tree */
size_t trinity_queen_tech_tree(char* buf, size_t len);

/** Arena leaderboard (ELO rankings) */
size_t trinity_queen_arena_leaderboard(char* buf, size_t len);

/** Recent experience episodes */
size_t trinity_queen_experience_recent(char* buf, size_t len, size_t n);

/** Queen v4 senses snapshot (.trinity/queen/senses.json) */
size_t trinity_queen_senses(char* buf, size_t len);

/** Queen daemon state (.trinity/queen_state.json) */
size_t trinity_queen_queen_state(char* buf, size_t len);

/** All 29 actions with levels and rate limits (.trinity/queen/actions.json) */
size_t trinity_queen_actions_list(char* buf, size_t len);

/** Last N audit entries from audit.jsonl */
size_t trinity_queen_audit_recent(size_t n, char* buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* TRINITY_QUEEN_H */
