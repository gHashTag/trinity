//! TRIOS Quest — Query and Discovery System FFI for Trinity Graph
//!
//! This crate provides FFI bindings for TRIOS quest (query/discovery) operations
//! including graph traversal, node search, dependency resolution, and
//! topological analysis for the Trinity module graph.
//!
//! ## Features
//!
//! - **Query Types**: Exact, fuzzy, range, regex, graph traversal
//! - **Node Search**: Find nodes by name, type, domain, or custom criteria
//! - **Graph Traversal**: BFS, DFS, topological sort, shortest path
//! - **Dependency Resolution**: Impact analysis, transitive closure
//! - **Result Ranking**: Score and sort results by relevance
//!
//! ## Symbol: `🔍`

use std::os::raw::{c_char, c_double, c_long};

// ─── Constants ────────────────────────────────────────────────────────

/// Maximum number of results per query
pub const MAX_RESULTS: usize = 128;

/// Maximum query string length
pub const MAX_QUERY_LEN: usize = 512;

/// Maximum node name length
pub const MAX_NODE_NAME_LEN: usize = 256;

/// Maximum path length (nodes in a path)
pub const MAX_PATH_LEN: usize = 64;

/// Maximum depth for graph traversal
pub const MAX_TRAVERSAL_DEPTH: usize = 16;

// ─── Enums ────────────────────────────────────────────────────────────

/// Query type
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QuestType {
    /// Exact string match
    Exact = 0,
    /// Case-insensitive substring match
    Fuzzy = 1,
    /// Numeric range query
    Range = 2,
    /// Regular expression match
    Regex = 3,
    /// Graph traversal (BFS/DFS)
    GraphTraversal = 4,
    /// Topological sort
    Topological = 5,
    /// Dependency/impact analysis
    Impact = 6,
    /// Shortest path
    ShortestPath = 7,
}

/// Sort order for results
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SortOrder {
    /// Ascending (A→Z, 0→9)
    Ascending = 0,
    /// Descending (Z→A, 9→0)
    Descending = 1,
    /// By relevance score (highest first)
    Relevance = 2,
    /// By distance in graph (closest first)
    Distance = 3,
}

/// Traversal algorithm
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TraversalAlgo {
    /// Breadth-first search
    Bfs = 0,
    /// Depth-first search
    Dfs = 1,
    /// Topological sort (DAG only)
    TopologicalSort = 2,
    /// Dijkstra shortest path
    Dijkstra = 3,
}

/// Node type in the Trinity graph
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NodeType {
    /// Specification file (.t27, .tri)
    Spec = 0,
    /// Source code (.zig, .rs)
    Source = 1,
    /// Conformance vector (.json)
    Conformance = 2,
    /// Documentation (.md)
    Documentation = 3,
    /// Build artifact
    Build = 4,
    /// Test file
    Test = 5,
    /// Configuration
    Config = 6,
    /// Agent module
    Agent = 7,
}

/// Edge type in the Trinity graph
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EdgeType {
    /// A depends on B
    DependsOn = 0,
    /// A implements B
    Implements = 1,
    /// A tests B
    Tests = 2,
    /// A documents B
    Documents = 3,
    /// A generates B
    Generates = 4,
    /// Sacred/phi-critical dependency
    SacredEdge = 5,
}

// ─── Structs ──────────────────────────────────────────────────────────

/// Graph node identifier
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct NodeId {
    /// Node index in the graph
    pub index: usize,
    /// Node name (null-terminated)
    pub name: [c_char; MAX_NODE_NAME_LEN],
    /// Node type
    pub node_type: NodeType,
    /// Domain tag (null-terminated)
    pub domain: [c_char; 64],
}

/// Graph edge
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Edge {
    /// Source node index
    pub from: usize,
    /// Target node index
    pub to: usize,
    /// Edge type
    pub edge_type: EdgeType,
    /// Edge weight (0.0–1.0, 1.0 = sacred/phi-critical)
    pub weight: c_double,
}

/// Quest query definition
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct QuestQuery {
    /// Query type
    pub quest_type: QuestType,
    /// Query string (null-terminated)
    pub query: [c_char; MAX_QUERY_LEN],
    /// Node type filter (0xFF = any)
    pub filter_type: u8,
    /// Domain filter (null-terminated, empty = any)
    pub filter_domain: [c_char; 64],
    /// Maximum results to return
    pub max_results: usize,
    /// Sort order
    pub sort_order: SortOrder,
    /// Traversal algorithm (for graph queries)
    pub traversal: TraversalAlgo,
    /// Maximum traversal depth
    pub max_depth: usize,
    /// Start node index (for graph queries)
    pub start_node: usize,
}

/// Single quest result entry
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct QuestResultEntry {
    /// Matched node
    pub node: NodeId,
    /// Relevance score [0.0, 1.0]
    pub score: c_double,
    /// Distance from start node (for graph queries)
    pub distance: usize,
    /// Path from start node (node indices)
    pub path: [usize; MAX_PATH_LEN],
    /// Path length
    pub path_len: usize,
    /// Whether this is an exact match
    pub exact: bool,
}

/// Quest result set
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct QuestResultSet {
    /// Results array
    pub entries: [QuestResultEntry; MAX_RESULTS],
    /// Number of results
    pub count: usize,
    /// Total matches found (may exceed MAX_RESULTS)
    pub total_matches: usize,
    /// Query that produced these results
    pub query: QuestQuery,
    /// Execution time in microseconds
    pub elapsed_us: c_long,
    /// Whether the query succeeded
    pub success: bool,
}

/// Impact analysis result
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ImpactResult {
    /// Source node (the changed node)
    pub source: NodeId,
    /// Directly affected nodes
    pub direct: [NodeId; MAX_RESULTS],
    /// Number of directly affected nodes
    pub direct_count: usize,
    /// Transitively affected nodes
    pub transitive: [NodeId; MAX_RESULTS],
    /// Number of transitively affected nodes
    pub transitive_count: usize,
    /// Maximum impact depth
    pub max_depth: usize,
    /// Impact severity [0.0, 1.0]
    pub severity: c_double,
    /// Whether any sacred edges are affected
    pub sacred_impact: bool,
}

// ─── Query Construction ──────────────────────────────────────────────

/// Create a new exact-match query
#[no_mangle]
pub extern "C" fn trios_quest_exact_query(
    pattern: *const c_char,
    max_results: usize,
) -> QuestQuery {
    let mut query: QuestQuery = unsafe { std::mem::zeroed() };
    query.quest_type = QuestType::Exact;
    query.max_results = max_results.min(MAX_RESULTS);
    query.sort_order = SortOrder::Relevance;
    query.filter_type = 0xFF;
    query.max_depth = MAX_TRAVERSAL_DEPTH;

    if !pattern.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(pattern) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_QUERY_LEN - 1);
        query.query[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        query.query[len] = 0;
    }

    query
}

/// Create a new fuzzy search query
#[no_mangle]
pub extern "C" fn trios_quest_fuzzy_query(
    pattern: *const c_char,
    max_results: usize,
) -> QuestQuery {
    let mut query = trios_quest_exact_query(pattern, max_results);
    query.quest_type = QuestType::Fuzzy;
    query
}

/// Create a graph traversal query
#[no_mangle]
pub extern "C" fn trios_quest_traversal_query(
    start_node: usize,
    algo: TraversalAlgo,
    max_depth: usize,
) -> QuestQuery {
    let mut query: QuestQuery = unsafe { std::mem::zeroed() };
    query.quest_type = QuestType::GraphTraversal;
    query.traversal = algo;
    query.start_node = start_node;
    query.max_depth = max_depth.min(MAX_TRAVERSAL_DEPTH);
    query.max_results = MAX_RESULTS;
    query.filter_type = 0xFF;
    query.sort_order = SortOrder::Distance;
    query
}

/// Create an impact analysis query
#[no_mangle]
pub extern "C" fn trios_quest_impact_query(
    source_node: usize,
    max_depth: usize,
) -> QuestQuery {
    let mut query: QuestQuery = unsafe { std::mem::zeroed() };
    query.quest_type = QuestType::Impact;
    query.start_node = source_node;
    query.max_depth = max_depth.min(MAX_TRAVERSAL_DEPTH);
    query.max_results = MAX_RESULTS;
    query.filter_type = 0xFF;
    query.sort_order = SortOrder::Distance;
    query
}

// ─── Result Construction ──────────────────────────────────────────────

/// Create an empty result set
#[no_mangle]
pub extern "C" fn trios_quest_result_set_new(query: QuestQuery) -> QuestResultSet {
    QuestResultSet {
        entries: unsafe { std::mem::zeroed() },
        count: 0,
        total_matches: 0,
        query,
        elapsed_us: 0,
        success: true,
    }
}

/// Add a result entry to the result set
#[no_mangle]
pub extern "C" fn trios_quest_result_set_add(
    rs: *mut QuestResultSet,
    entry: QuestResultEntry,
) -> bool {
    if rs.is_null() {
        return false;
    }
    unsafe {
        if (*rs).count >= MAX_RESULTS {
            (*rs).total_matches += 1;
            return false;
        }
        (*rs).entries[(*rs).count] = entry;
        (*rs).count += 1;
        (*rs).total_matches += 1;
        true
    }
}

// ─── Node Construction ────────────────────────────────────────────────

/// Create a node identifier
#[no_mangle]
pub extern "C" fn trios_quest_node_new(
    index: usize,
    name: *const c_char,
    node_type: NodeType,
    domain: *const c_char,
) -> NodeId {
    let mut node: NodeId = unsafe { std::mem::zeroed() };
    node.index = index;
    node.node_type = node_type;

    if !name.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(name) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_NODE_NAME_LEN - 1);
        node.name[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        node.name[len] = 0;
    }

    if !domain.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(domain) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(63);
        node.domain[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        node.domain[len] = 0;
    }

    node
}

// ─── Simple Matching ──────────────────────────────────────────────────

/// Check if a node name matches a query (exact or fuzzy)
#[no_mangle]
pub extern "C" fn trios_quest_match(
    node_name: *const c_char,
    pattern: *const c_char,
    quest_type: QuestType,
) -> c_double {
    if node_name.is_null() || pattern.is_null() {
        return 0.0;
    }

    let name = unsafe { std::ffi::CStr::from_ptr(node_name) };
    let pat = unsafe { std::ffi::CStr::from_ptr(pattern) };

    let name_bytes = name.to_bytes();
    let pat_bytes = pat.to_bytes();

    match quest_type {
        QuestType::Exact => {
            if name_bytes == pat_bytes {
                1.0
            } else {
                0.0
            }
        }
        QuestType::Fuzzy => {
            if name_bytes.is_empty() || pat_bytes.is_empty() {
                return 0.0;
            }
            // Simple substring match with scoring
            if name_bytes == pat_bytes {
                1.0
            } else {
                // Check if pattern is a substring
                let name_str = std::str::from_utf8(name_bytes).unwrap_or("");
                let pat_str = std::str::from_utf8(pat_bytes).unwrap_or("");
                let name_lower = name_str.to_lowercase();
                let pat_lower = pat_str.to_lowercase();
                if name_lower.contains(&pat_lower) {
                    // Score based on how much of the name the pattern covers
                    pat_bytes.len() as c_double / name_bytes.len().max(1) as c_double
                } else {
                    0.0
                }
            }
        }
        _ => 0.0,
    }
}

/// Compute fuzzy relevance score between two strings
#[no_mangle]
pub extern "C" fn trios_quest_relevance_score(
    node_name: *const c_char,
    pattern: *const c_char,
) -> c_double {
    trios_quest_match(node_name, pattern, QuestType::Fuzzy)
}

// ─── Impact Analysis Helpers ──────────────────────────────────────────

/// Create a new impact result
#[no_mangle]
pub extern "C" fn trios_quest_impact_result_new(source: NodeId) -> ImpactResult {
    ImpactResult {
        source,
        direct: unsafe { std::mem::zeroed() },
        direct_count: 0,
        transitive: unsafe { std::mem::zeroed() },
        transitive_count: 0,
        max_depth: 0,
        severity: 0.0,
        sacred_impact: false,
    }
}

/// Add a directly affected node to the impact result
#[no_mangle]
pub extern "C" fn trios_quest_impact_add_direct(
    result: *mut ImpactResult,
    node: NodeId,
) -> bool {
    if result.is_null() {
        return false;
    }
    unsafe {
        if (*result).direct_count >= MAX_RESULTS {
            return false;
        }
        (*result).direct[(*result).direct_count] = node;
        (*result).direct_count += 1;
        true
    }
}

/// Add a transitively affected node to the impact result
#[no_mangle]
pub extern "C" fn trios_quest_impact_add_transitive(
    result: *mut ImpactResult,
    node: NodeId,
    depth: usize,
) -> bool {
    if result.is_null() {
        return false;
    }
    unsafe {
        if (*result).transitive_count >= MAX_RESULTS {
            return false;
        }
        (*result).transitive[(*result).transitive_count] = node;
        (*result).transitive_count += 1;
        if depth > (*result).max_depth {
            (*result).max_depth = depth;
        }
        true
    }
}

/// Compute impact severity based on counts and sacred edges
#[no_mangle]
pub extern "C" fn trios_quest_impact_severity(result: *mut ImpactResult) -> c_double {
    if result.is_null() {
        return 0.0;
    }
    unsafe {
        let direct = (*result).direct_count as c_double;
        let transitive = (*result).transitive_count as c_double;
        let sacred_bonus = if (*result).sacred_impact { 0.3 } else { 0.0 };
        let base = (direct * 0.5 + transitive * 0.2) / MAX_RESULTS as c_double;
        (base + sacred_bonus).min(1.0)
    }
}

// ─── Unit Tests ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exact_query() {
        let q = trios_quest_exact_query(b"sacred_physics\0".as_ptr() as *const c_char, 10);
        assert_eq!(q.quest_type, QuestType::Exact);
        assert_eq!(q.max_results, 10);
    }

    #[test]
    fn test_fuzzy_query() {
        let q = trios_quest_fuzzy_query(b"physics\0".as_ptr() as *const c_char, 20);
        assert_eq!(q.quest_type, QuestType::Fuzzy);
        assert_eq!(q.max_results, 20);
    }

    #[test]
    fn test_exact_match() {
        let score = trios_quest_match(
            b"sacred_physics\0".as_ptr() as *const c_char,
            b"sacred_physics\0".as_ptr() as *const c_char,
            QuestType::Exact,
        );
        assert_eq!(score, 1.0);

        let score = trios_quest_match(
            b"sacred_physics\0".as_ptr() as *const c_char,
            b"other\0".as_ptr() as *const c_char,
            QuestType::Exact,
        );
        assert_eq!(score, 0.0);
    }

    #[test]
    fn test_fuzzy_match() {
        let score = trios_quest_match(
            b"sacred_physics\0".as_ptr() as *const c_char,
            b"physics\0".as_ptr() as *const c_char,
            QuestType::Fuzzy,
        );
        assert!(score > 0.0);
        assert!(score <= 1.0);
    }

    #[test]
    fn test_result_set() {
        let query = trios_quest_exact_query(b"test\0".as_ptr() as *const c_char, 10);
        let mut rs = trios_quest_result_set_new(query);
        assert_eq!(rs.count, 0);

        let node = trios_quest_node_new(
            0,
            b"test_node\0".as_ptr() as *const c_char,
            NodeType::Spec,
            b"math\0".as_ptr() as *const c_char,
        );
        let entry = QuestResultEntry {
            node,
            score: 1.0,
            distance: 0,
            path: [0; MAX_PATH_LEN],
            path_len: 1,
            exact: true,
        };

        assert!(trios_quest_result_set_add(&mut rs, entry));
        assert_eq!(rs.count, 1);
    }

    #[test]
    fn test_impact_result() {
        let source = trios_quest_node_new(
            0,
            b"constants\0".as_ptr() as *const c_char,
            NodeType::Spec,
            b"math\0".as_ptr() as *const c_char,
        );
        let mut result = trios_quest_impact_result_new(source);
        assert_eq!(result.direct_count, 0);

        let dep = trios_quest_node_new(
            1,
            b"sacred_physics\0".as_ptr() as *const c_char,
            NodeType::Spec,
            b"math\0".as_ptr() as *const c_char,
        );
        assert!(trios_quest_impact_add_direct(&mut result, dep));
        assert_eq!(result.direct_count, 1);

        let severity = trios_quest_impact_severity(&mut result);
        assert!(severity > 0.0);
    }
}
