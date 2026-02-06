---
sidebar_position: 2
---
# HDC Applications

Trinity includes 23 Hyperdimensional Computing application modules, each defined as a `.vibee` specification in the `specs/tri/` directory. These modules cover a broad range of machine learning and AI tasks, all implemented using the same ternary Vector Symbolic Architecture operations -- no gradient descent, no backpropagation, and no floating-point weight matrices.

All modules share a common encoding foundation through `HDCTextEncoder` and `ItemMemory`, ensuring consistent vector representations across the entire application suite.

---

## Classification

### HDC Classifier (`hdc_classifier.vibee`)
One-shot and few-shot text classification using bundled class prototypes. Training encodes text samples as hypervectors and bundles them into per-class prototypes via majority vote. Prediction finds the class prototype with the highest cosine similarity to the encoded query. Supports incremental addition of new classes without retraining.

### HDC Stream Classifier (`hdc_stream_classifier.vibee`)
Adaptive online classifier for data streams with concept drift detection. Maintains a sliding window of recent labeled samples and periodically rebuilds class prototypes from the window contents. Monitors prediction confidence over time to detect distribution shifts, alerting when the drift score exceeds a configurable threshold.

### HDC Few-Shot Learner (`hdc_few_shot.vibee`)
Meta-learning for K-shot classification with prototype rectification. Learns new classes from as few as 1-5 examples per class. Applies centroid subtraction to remove shared background components from prototypes, amplifying class-specific signals and improving separation between classes with limited training data.

### HDC Multi-Task Learner (`hdc_multi_task.vibee`)
Simultaneous multi-label classification with independent task heads sharing a single encoder. Text is encoded once, then compared against separate prototype banks for each task (e.g., sentiment, topic, language). Tasks cannot interfere with each other because prototype banks are fully independent.

---

## Clustering and Unsupervised Learning

### HDC Clustering (`hdc_clustering.vibee`)
Unsupervised K-means clustering in hyperdimensional space. Cluster centroids are computed via bundling (majority vote over assigned samples), and assignment uses cosine similarity. Supports random and k-means++ initialization strategies, with convergence tracking via centroid drift measurement and silhouette scoring for cluster quality evaluation.

---

## Natural Language Processing

### HDC Text Encoder (`hdc_text_encoder.vibee`)
Shared text encoding module used by all downstream applications. Supports four encoding modes: character n-gram bundling, word-level encoding with positional permutation, word-level encoding with TF-IDF weighting, and a hybrid mode combining character and word representations.

### HDC Language Model (`hdc_language_model.vibee`)
Character-level language model for next-character prediction and text generation. Stores context vectors bundled per next character, and predicts by finding the most similar stored context. Supports temperature-controlled softmax sampling, top-k filtering, repetition penalty, and perplexity measurement.

### HDC Sequence Predictor (`hdc_sequence_predictor.vibee`)
Word-level next-token prediction using sliding n-gram windows with positional encoding. Trains by extracting context windows and storing them alongside target words. Supports greedy prediction, top-k candidate ranking, iterative text generation, and multi-step beam search for improved sequence quality.

---

## Knowledge Representation and Reasoning

### HDC Knowledge Graph (`hdc_knowledge_graph.vibee`)
Stores subject-relation-object triples in holographic distributed memory. Triples are encoded as three-way bindings and bundled into a single memory vector. Supports pattern-matching queries with wildcards: given two of three elements, the system recovers the missing element by unbinding from memory and decoding against the entity codebook.

### HDC Graph Traversal (`hdc_graph_traversal.vibee`)
Multi-hop reasoning and path queries over HDC knowledge graphs. Chains single-hop queries to traverse paths through the graph. Supports analogy queries ("a is to b as c is to ?") via vector arithmetic, and subgraph matching to find entities satisfying multiple relation constraints simultaneously.

### HDC Symbolic Reasoning (`hdc_symbolic_reasoning.vibee`)
Logic and analogy engine using role-filler bindings in hyperdimensional space. Represents structured concepts as frames composed of bound role-filler pairs. Supports frame queries (slot access via unbinding), analogy solving (extracting and applying relations between concepts), and compositional reasoning over the vocabulary.

### HDC Associative Memory (`hdc_associative_memory.vibee`)
Content-addressable key-value store using holographic distributed memory. Key-value pairs are bound together and bundled into a single memory vector. Queries unbind the key from memory and decode the result against a value codebook. Supports approximate queries with noisy or partial keys and periodic cleanup to reduce accumulated noise.

---

## Anomaly Detection

### HDC Anomaly Detector (`hdc_anomaly_detector.vibee`)
One-class anomaly detection that learns a "normal" prototype from positive examples only. Anomaly scores are computed as the distance from the normal prototype (1 minus cosine similarity). Threshold is automatically calibrated from training data statistics using a configurable sensitivity parameter. Supports multiple independent normal profiles.

### HDC Temporal Anomaly Detector (`hdc_temporal_anomaly.vibee`)
Time-series anomaly detection over event sequences using sliding context windows. Encodes windows with positional permutation to preserve temporal order, then scores against learned normal profiles. Includes exponential moving average smoothing for noisy streams and multi-regime support for different normal patterns (e.g., daytime vs. nighttime).

---

## Recommendation

### HDC Recommender (`hdc_recommender.vibee`)
Content-based and collaborative filtering recommendation system. User profiles are constructed by bundling the hypervectors of liked items, and recommendations are generated by ranking unseen items by cosine similarity to the user profile. Supports collaborative filtering by finding users with similar profiles and recommending from the community signal. Handles cold-start naturally -- a single rating produces a functional profile.

---

## Search and Retrieval

### HDC Semantic Search (`hdc_semantic_search.vibee`)
Document retrieval via hyperdimensional similarity. Documents are encoded as hypervectors and stored in an index. Queries are encoded with the same method, and the top-k most similar documents are returned by cosine ranking. Supports TF-IDF weighting for relevance-based ranking and incremental indexing without full rebuild.

---

## Ensemble and Cognitive Systems

### HDC Ensemble (`hdc_ensemble.vibee`)
Unified cognitive pipeline combining a supervised classifier, an anomaly detector, and unsupervised clustering into a single prediction system. Anomaly gating rejects out-of-distribution inputs before classification. Confidence thresholding refuses low-confidence predictions. All subsystems share identical encoding for consistency.

### HDC Cognitive Agent (`hdc_cognitive.vibee`)
Full cognitive loop integrating perception, classification, episodic memory, anomaly detection, explainability, and incremental learning into a single processing pipeline. Each input is encoded once and passed through all subsystems: classify, recall similar past inputs, detect novelty, explain the decision via word attribution, and learn from the experience. Supports supervised, self-supervised, and memory-only learning modes.

---

## Explainability

### HDC Explainer (`hdc_explainer.vibee`)
Feature attribution for classifier decisions using VSA algebra. Explains predictions by computing per-word cosine similarity to class prototypes, revealing which words contributed most to a classification. Supports contrastive explanations ("why class A instead of class B?") by computing attribution differences between two class prototypes.

---

## Learning Paradigms

### HDC Continual Learning (`hdc_continual_learning.vibee`)
Incremental class learning with near-zero catastrophic forgetting. New classes are added by creating new prototypes without modifying existing ones. Tested across 10 phases with 20 classes: average forgetting 3.04%, maximum forgetting 12.5% (compared to 50-90% catastrophic forgetting in neural networks). No replay buffer or regularization is needed because prototypes are fully independent. See [HDC Overview](/docs/hdc/) for full benchmark results.

### HDC Federated Learning (`hdc_federated.vibee`)
Privacy-preserving distributed classification where multiple nodes train locally on private data and share only prototype hypervectors with a central coordinator. The global model is constructed by bundling prototypes from all nodes. Raw data never leaves the local node, and prototypes are high-dimensional bundled averages from which individual samples cannot be recovered.

---

## Reinforcement Learning

### HDC RL Agent (`hdc_rl_agent.vibee`)
Q-learning via hyperdimensional prototypes for reinforcement learning in discrete environments. Maintains positive and negative prototype vectors for each action, bundling state vectors according to their discounted returns. Q-values are estimated as the cosine difference between positive and negative prototypes for a given state-action pair. Includes a gridworld environment for training and evaluation with epsilon-greedy exploration.

---

## Multimodal Processing

### HDC Multimodal Classifier (`hdc_multimodal.vibee`)
Fusion of text, numeric, categorical, and boolean features into a unified hyperdimensional representation. Numeric values are encoded using thermometer coding (close values share most level vectors, producing high similarity). Features are bound with role vectors and bundled with text encodings to produce a single fused hypervector for classification.

---

## Source Specifications

All 23 HDC application modules are defined as `.vibee` specifications in the `specs/tri/` directory of the Trinity repository. Each specification file documents the module's types, behaviors, and architectural design. Code is generated from these specifications using the VIBEE compiler:

```bash
./bin/vibee gen specs/tri/hdc_classifier.vibee
```

Refer to the individual `.vibee` files for complete type definitions, behavior contracts, and detailed architectural descriptions.
