/**
 * @file semantic_search.c
 * @brief Semantic search demo using libtrinity-vsa text encoding
 *
 * Demonstrates:
 *   1. Encoding text strings to hypervectors
 *   2. Computing semantic similarity between texts
 *   3. Building a simple corpus and finding nearest neighbors
 *
 * Build:
 *   zig build libvsa
 *   cc -I zig-out/include -L zig-out/lib -ltrinity-vsa semantic_search.c -o semantic_search
 *   ./semantic_search
 */

#include <stdio.h>
#include <string.h>
#include "trinity_vsa.h"

#define MAX_CORPUS 20

typedef struct {
    trinity_vsa_vector_t vec;
    const char* label;
} corpus_entry_t;

static corpus_entry_t corpus[MAX_CORPUS];
static int corpus_size = 0;

static void corpus_add(const char* text, const char* label) {
    if (corpus_size >= MAX_CORPUS) return;
    corpus[corpus_size].vec = trinity_vsa_encode_text(text, strlen(text));
    corpus[corpus_size].label = label;
    corpus_size++;
}

static const char* corpus_search(const char* query) {
    trinity_vsa_vector_t q = trinity_vsa_encode_text(query, strlen(query));
    if (!q) return "(error)";

    double best_sim = -2.0;
    int best_idx = 0;

    for (int i = 0; i < corpus_size; i++) {
        double sim = trinity_vsa_cosine_similarity(q, corpus[i].vec);
        if (sim > best_sim) {
            best_sim = sim;
            best_idx = i;
        }
    }

    trinity_vsa_vector_free(q);
    printf("    best match: \"%s\" (similarity: %.4f)\n", corpus[best_idx].label, best_sim);
    return corpus[best_idx].label;
}

static void corpus_free(void) {
    for (int i = 0; i < corpus_size; i++) {
        trinity_vsa_vector_free(corpus[i].vec);
    }
    corpus_size = 0;
}

int main(void) {
    printf("=== Trinity VSA Semantic Search Demo ===\n");
    printf("Version: %s\n\n", trinity_vsa_version());

    /* 1. Text similarity */
    printf("--- Text Similarity ---\n");

    trinity_vsa_vector_t hello1 = trinity_vsa_encode_text("hello world", 11);
    trinity_vsa_vector_t hello2 = trinity_vsa_encode_text("hello world", 11);
    trinity_vsa_vector_t hi     = trinity_vsa_encode_text("hi world", 8);
    trinity_vsa_vector_t bye    = trinity_vsa_encode_text("goodbye moon", 12);

    printf("  sim(\"hello world\", \"hello world\") = %.4f (identical)\n",
           trinity_vsa_cosine_similarity(hello1, hello2));
    printf("  sim(\"hello world\", \"hi world\")    = %.4f (similar)\n",
           trinity_vsa_cosine_similarity(hello1, hi));
    printf("  sim(\"hello world\", \"goodbye moon\") = %.4f (different)\n\n",
           trinity_vsa_cosine_similarity(hello1, bye));

    trinity_vsa_vector_free(hello1);
    trinity_vsa_vector_free(hello2);
    trinity_vsa_vector_free(hi);
    trinity_vsa_vector_free(bye);

    /* 2. Semantic search corpus */
    printf("--- Corpus Search ---\n");
    printf("Building corpus...\n");

    corpus_add("cat",       "cat");
    corpus_add("dog",       "dog");
    corpus_add("fish",      "fish");
    corpus_add("apple",     "apple");
    corpus_add("banana",    "banana");
    corpus_add("orange",    "orange");
    corpus_add("car",       "car");
    corpus_add("bicycle",   "bicycle");
    corpus_add("airplane",  "airplane");

    printf("Corpus size: %d entries\n\n", corpus_size);

    printf("Query: \"cat\"\n");
    corpus_search("cat");

    printf("Query: \"dog\"\n");
    corpus_search("dog");

    printf("Query: \"apple\"\n");
    corpus_search("apple");

    printf("Query: \"car\"\n");
    corpus_search("car");

    printf("\n");

    /* 3. Bind for associative memory */
    printf("--- Associative Memory ---\n");
    printf("Encoding: country -> capital pairs\n");

    trinity_vsa_vector_t france  = trinity_vsa_encode_text("france", 6);
    trinity_vsa_vector_t paris   = trinity_vsa_encode_text("paris", 5);
    trinity_vsa_vector_t germany = trinity_vsa_encode_text("germany", 7);
    trinity_vsa_vector_t berlin  = trinity_vsa_encode_text("berlin", 6);

    /* Create associations: country * capital */
    trinity_vsa_vector_t fr_pair = trinity_vsa_bind(france, paris);
    trinity_vsa_vector_t de_pair = trinity_vsa_bind(germany, berlin);

    /* Query: given france, what's the capital? */
    trinity_vsa_vector_t query_result = trinity_vsa_unbind(fr_pair, france);
    printf("  unbind(france*paris, france) ~ paris? sim = %.4f\n",
           trinity_vsa_cosine_similarity(query_result, paris));
    printf("  unbind(france*paris, france) ~ berlin? sim = %.4f\n\n",
           trinity_vsa_cosine_similarity(query_result, berlin));

    trinity_vsa_vector_free(france);
    trinity_vsa_vector_free(paris);
    trinity_vsa_vector_free(germany);
    trinity_vsa_vector_free(berlin);
    trinity_vsa_vector_free(fr_pair);
    trinity_vsa_vector_free(de_pair);
    trinity_vsa_vector_free(query_result);

    /* Cleanup corpus */
    corpus_free();

    printf("=== Demo complete ===\n");
    return 0;
}
