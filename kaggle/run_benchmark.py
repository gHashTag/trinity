#!/usr/bin/env python3
"""Trinity Metacognition Benchmark — CLI Runner for Kaggle Benchmarks"""

import io
import os
import kaggle_benchmarks as kbench
import pandas as pd
from dataclasses import dataclass
from typing import Literal

# Встроить данные (для автономного запуска)
CSV_DATA = """id,task,question,answer,ground_truth_confidence,difficulty,brain_zone,neural_analog
tmp_confidence_calibration_0000,Confidence Calibration,What is the capital of Uzbekistan?,Tashkent,0.95,3.0,ofc,OFC value judgment requires calibrated confidence for optimal decision-making
tmp_confidence_calibration_0001,Confidence Calibration,Explain quantum superposition in one sentence.,A quantum system exists in multiple states simultaneously until measured.,0.3,3.2,ofc,OFC value judgment requires calibrated confidence for optimal decision-making
tmp_confidence_calibration_0002,Confidence Calibration,What is 2^20?,1048576,0.98,3.4,ofc,OFC value judgment requires calibrated confidence for optimal decision-making
tmp_error_detection_0003,Error Self-Detection,I previously stated Paris is the capital of Australia. Is this correct?,No, Canberra is the capital of Australia.,0.9,3.6,acc,ACC detects stale cache vs live state conflicts
tmp_error_detection_0004,Error Self-Detection,I claimed 7 × 8 = 56. Is this correct?,No, 7 × 8 = 54.,0.85,3.8,acc,ACC detects stale cache vs live state conflicts
tmp_strategic_adaptation_0005,Strategic Adaptation,The previous approach failed due to timeout. What should you try next?,Reduce batch size and increase timeout threshold.,0.7,4.0,acc,ACC + Amygdala Minimum Necessary Learning
tmp_knowledge_boundary_0006,Knowledge Boundary,What year was the first neural network architecture published?,I don't have high confidence about publications before 1950.,0.4,4.2,habenula,HABENULA anti-corruption: effort must match reward
tmp_monitoring_under_load_0007,Monitoring Under Load,You've been processing for 5 minutes. Is your performance stable?,Yes, latency is within acceptable bounds.,0.8,4.4,insula,Insula measures internal state and resource health
tmp_confidence_calibration_0008,Confidence Calibration,What is the capital of France?,Paris,0.95,3.0,ofc,OFC value judgment requires calibrated confidence for optimal decision-making
tmp_error_detection_0009,Error Self-Detection,I said the sum of angles in a triangle is always 180. Is this always true?,No, not in spherical geometry.,0.8,3.6,acc,ACC detects stale cache vs live state conflicts
tmp_knowledge_boundary_0010,Knowledge Boundary,What causes Alzheimer's disease at the molecular level?,Current research is inconclusive about definitive causes.,0.35,4.2,habenula,HABENULA anti-corruption: effort must match reward
"""

# Structured output for confidence response
@dataclass
class ConfidenceResponse:
    """Model's response with confidence calibration."""
    answer: str
    confidence: float  # 0.0 to 1.0

    def is_calibrated(self, ground_truth: float) -> bool:
        """Check if confidence is calibrated within 0.2 tolerance."""
        return abs(self.confidence - ground_truth) <= 0.2

    def ternary_score(self, ground_truth: float) -> Literal[-1, 0, 1]:
        """Return Trinity ternary score {-1, 0, +1}."""
        if self.is_calibrated(ground_truth):
            return 1  # Correct
        elif abs(self.confidence - 0.5) < 0.3:
            return 0  # Appropriately uncertain
        else:
            return -1  # Overconfident or wrong

# Define Kaggle benchmark task
@kbench.task(name="trinity_ofc_confidence")
def confidence_calibration(
    llm: kbench.LLM,
    question: str,
    expected_answer: str,
    ground_truth_confidence: float
) -> float:
    """
    Measure model's confidence calibration.

    Returns:
        Calibration score: 1.0 (perfect) to -1.0 (worst)
    """
    prompt = f"""Answer this question and provide your confidence level (0.0 to 1.0).

Question: {question}

Respond with your answer and a confidence score.
"""

    response = llm.prompt(
        prompt,
        schema=ConfidenceResponse
    )

    # Calculate calibration score
    confidence_diff = abs(response.confidence - ground_truth_confidence)
    calibration_score = 1.0 - (confidence_diff * 2)  # Scale to [-1, 1]

    # Ternary adjustment (Trinity unique)
    ternary = response.ternary_score(ground_truth_confidence)

    # Combine: 70% calibration, 30% ternary
    final_score = 0.7 * calibration_score + 0.3 * ternary

    return max(-1.0, min(1.0, final_score))


def main():
    """Run benchmark evaluation."""
    # Load data from embedded CSV
    df = pd.read_csv(io.StringIO(CSV_DATA))
    print(f"📊 Loaded {len(df)} items\n")

    # Run evaluation
    print("🔍 Running confidence calibration evaluation...\n")
    results = confidence_calibration.evaluate(
        llm=[kbench.llm],  # Default test LLM
        evaluation_data=df
    )

    # Print results
    print("📈 Evaluation Results:")
    print(f"   Mean Score: {results['score'].mean():.4f}")
    print(f"   Std Dev: {results['score'].std():.4f}")
    print(f"   Min: {results['score'].min():.4f}")
    print(f"   Max: {results['score'].max():.4f}")

    # Print head of results
    print("\n📋 First 5 results:")
    print(results[['id', 'question', 'answer', 'confidence', 'score']].head().to_string())

    # Submit to Kaggle leaderboard
    print("\n🚀 Submitting to Kaggle leaderboard...")
    kbench.submit(
        task=confidence_calibration,
        results=results,
        message="Trinity OFC Confidence Calibration v1.0"
    )
    print("✅ Submitted successfully!")


if __name__ == "__main__":
    main()
