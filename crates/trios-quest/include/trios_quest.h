#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum number of results per query
 */
#define MAX_RESULTS 128

/**
 * Maximum query string length
 */
#define MAX_QUERY_LEN 512

/**
 * Maximum node name length
 */
#define MAX_NODE_NAME_LEN 256

/**
 * Maximum path length (nodes in a path)
 */
#define MAX_PATH_LEN 64

/**
 * Maximum depth for graph traversal
 */
#define MAX_TRAVERSAL_DEPTH 16

/**
 * Node type in the Trinity graph
 */
typedef enum NodeType {
  /**
   * Specification file (.t27, .tri)
   */
  Spec = 0,
  /**
   * Source code (.zig, .rs)
   */
  Source = 1,
  /**
   * Conformance vector (.json)
   */
  Conformance = 2,
  /**
   * Documentation (.md)
   */
  Documentation = 3,
  /**
   * Build artifact
   */
  Build = 4,
  /**
   * Test file
   */
  Test = 5,
  /**
   * Configuration
   */
  Config = 6,
  /**
   * Agent module
   */
  Agent = 7,
} NodeType;

/**
 * Query type
 */
typedef enum QuestType {
  /**
   * Exact string match
   */
  Exact = 0,
  /**
   * Case-insensitive substring match
   */
  Fuzzy = 1,
  /**
   * Numeric range query
   */
  Range = 2,
  /**
   * Regular expression match
   */
  Regex = 3,
  /**
   * Graph traversal (BFS/DFS)
   */
  GraphTraversal = 4,
  /**
   * Topological sort
   */
  Topological = 5,
  /**
   * Dependency/impact analysis
   */
  Impact = 6,
  /**
   * Shortest path
   */
  ShortestPath = 7,
} QuestType;

/**
 * Sort order for results
 */
typedef enum SortOrder {
  /**
   * Ascending (A→Z, 0→9)
   */
  Ascending = 0,
  /**
   * Descending (Z→A, 9→0)
   */
  Descending = 1,
  /**
   * By relevance score (highest first)
   */
  Relevance = 2,
  /**
   * By distance in graph (closest first)
   */
  Distance = 3,
} SortOrder;

/**
 * Traversal algorithm
 */
typedef enum TraversalAlgo {
  /**
   * Breadth-first search
   */
  Bfs = 0,
  /**
   * Depth-first search
   */
  Dfs = 1,
  /**
   * Topological sort (DAG only)
   */
  TopologicalSort = 2,
  /**
   * Dijkstra shortest path
   */
  Dijkstra = 3,
} TraversalAlgo;

/**
 * Quest query definition
 */
typedef struct QuestQuery {
  /**
   * Query type
   */
  enum QuestType quest_type;
  /**
   * Query string (null-terminated)
   */
  char query[MAX_QUERY_LEN];
  /**
   * Node type filter (0xFF = any)
   */
  uint8_t filter_type;
  /**
   * Domain filter (null-terminated, empty = any)
   */
  char filter_domain[64];
  /**
   * Maximum results to return
   */
  uintptr_t max_results;
  /**
   * Sort order
   */
  enum SortOrder sort_order;
  /**
   * Traversal algorithm (for graph queries)
   */
  enum TraversalAlgo traversal;
  /**
   * Maximum traversal depth
   */
  uintptr_t max_depth;
  /**
   * Start node index (for graph queries)
   */
  uintptr_t start_node;
} QuestQuery;

/**
 * Graph node identifier
 */
typedef struct NodeId {
  /**
   * Node index in the graph
   */
  uintptr_t index;
  /**
   * Node name (null-terminated)
   */
  char name[MAX_NODE_NAME_LEN];
  /**
   * Node type
   */
  enum NodeType node_type;
  /**
   * Domain tag (null-terminated)
   */
  char domain[64];
} NodeId;

/**
 * Single quest result entry
 */
typedef struct QuestResultEntry {
  /**
   * Matched node
   */
  struct NodeId node;
  /**
   * Relevance score [0.0, 1.0]
   */
  double score;
  /**
   * Distance from start node (for graph queries)
   */
  uintptr_t distance;
  /**
   * Path from start node (node indices)
   */
  uintptr_t path[MAX_PATH_LEN];
  /**
   * Path length
   */
  uintptr_t path_len;
  /**
   * Whether this is an exact match
   */
  bool exact;
} QuestResultEntry;

/**
 * Quest result set
 */
typedef struct QuestResultSet {
  /**
   * Results array
   */
  struct QuestResultEntry entries[MAX_RESULTS];
  /**
   * Number of results
   */
  uintptr_t count;
  /**
   * Total matches found (may exceed MAX_RESULTS)
   */
  uintptr_t total_matches;
  /**
   * Query that produced these results
   */
  struct QuestQuery query;
  /**
   * Execution time in microseconds
   */
  long elapsed_us;
  /**
   * Whether the query succeeded
   */
  bool success;
} QuestResultSet;

/**
 * Impact analysis result
 */
typedef struct ImpactResult {
  /**
   * Source node (the changed node)
   */
  struct NodeId source;
  /**
   * Directly affected nodes
   */
  struct NodeId direct[MAX_RESULTS];
  /**
   * Number of directly affected nodes
   */
  uintptr_t direct_count;
  /**
   * Transitively affected nodes
   */
  struct NodeId transitive[MAX_RESULTS];
  /**
   * Number of transitively affected nodes
   */
  uintptr_t transitive_count;
  /**
   * Maximum impact depth
   */
  uintptr_t max_depth;
  /**
   * Impact severity [0.0, 1.0]
   */
  double severity;
  /**
   * Whether any sacred edges are affected
   */
  bool sacred_impact;
} ImpactResult;

/**
 * Create a new exact-match query
 */
struct QuestQuery trios_quest_exact_query(const char *pattern, uintptr_t max_results);

/**
 * Create a new fuzzy search query
 */
struct QuestQuery trios_quest_fuzzy_query(const char *pattern, uintptr_t max_results);

/**
 * Create a graph traversal query
 */
struct QuestQuery trios_quest_traversal_query(uintptr_t start_node,
                                              enum TraversalAlgo algo,
                                              uintptr_t max_depth);

/**
 * Create an impact analysis query
 */
struct QuestQuery trios_quest_impact_query(uintptr_t source_node, uintptr_t max_depth);

/**
 * Create an empty result set
 */
struct QuestResultSet trios_quest_result_set_new(struct QuestQuery query);

/**
 * Add a result entry to the result set
 */
bool trios_quest_result_set_add(struct QuestResultSet *rs, struct QuestResultEntry entry);

/**
 * Create a node identifier
 */
struct NodeId trios_quest_node_new(uintptr_t index,
                                   const char *name,
                                   enum NodeType node_type,
                                   const char *domain);

/**
 * Check if a node name matches a query (exact or fuzzy)
 */
double trios_quest_match(const char *node_name, const char *pattern, enum QuestType quest_type);

/**
 * Compute fuzzy relevance score between two strings
 */
double trios_quest_relevance_score(const char *node_name, const char *pattern);

/**
 * Create a new impact result
 */
struct ImpactResult trios_quest_impact_result_new(struct NodeId source);

/**
 * Add a directly affected node to the impact result
 */
bool trios_quest_impact_add_direct(struct ImpactResult *result, struct NodeId node);

/**
 * Add a transitively affected node to the impact result
 */
bool trios_quest_impact_add_transitive(struct ImpactResult *result,
                                       struct NodeId node,
                                       uintptr_t depth);

/**
 * Compute impact severity based on counts and sacred edges
 */
double trios_quest_impact_severity(struct ImpactResult *result);
