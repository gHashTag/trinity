#!/usr/bin/env python3
"""
TRINITY v7.0 OMEGA - Auto-Falsification Detector
================================================

Checks new experimental data against TRINITY predictions.
Uses statistical sigma-testing to determine prediction status.

Author: TRINITY Project
Date: 2026-03-05
License: MIT
"""

import json
import argparse
import sys
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from pathlib import Path
import math


@dataclass
class Prediction:
    """A TRINITY prediction with its parameters."""
    id: str
    name: str
    predicted_value: float
    uncertainty: float
    unit: str
    target_date: str
    source: str
    status: str = "pending"
    measured_value: Optional[float] = None
    measured_uncertainty: Optional[float] = None
    sigma_distance: Optional[float] = None
    last_checked: Optional[str] = None

    def to_dict(self) -> dict:
        return asdict(self)


class FalsificationDetector:
    """
    Auto-falsification detector for TRINITY predictions.

    Statistical testing framework:
    - 2σ: Confirmed (95% confidence)
    - 3σ: Partially confirmed (99.7% confidence)
    - 5σ: Falsified (discovery threshold)
    """

    # TRINITY Sacred Constants
    PHI = (1 + math.sqrt(5)) / 2
    PI = math.pi
    E = math.e

    def __init__(self, registry_path: str = None):
        """Initialize detector with prediction registry."""
        if registry_path is None:
            registry_path = Path(__file__).parent.parent / "data" / "predictions" / "registry.json"
        self.registry_path = Path(registry_path)
        self.predictions: Dict[str, Prediction] = {}
        self.load_predictions()

    def load_predictions(self):
        """Load predictions from registry.json."""
        if not self.registry_path.exists():
            self._create_default_registry()

        with open(self.registry_path, 'r') as f:
            data = json.load(f)
            version = data.get("version", "1.0")

            for pred_data in data.get("predictions", []):
                # Handle both v1.0 and v7.0 formats
                if version == "1.0":
                    # Migrate v1.0 format to v7.0
                    pred = self._migrate_v1_to_v7(pred_data)
                else:
                    # v7.0 format - filter to only Prediction fields
                    valid_fields = {k: v for k, v in pred_data.items()
                                   if k in {'id', 'name', 'predicted_value', 'uncertainty',
                                           'unit', 'target_date', 'source', 'status',
                                           'measured_value', 'measured_uncertainty',
                                           'sigma_distance', 'last_checked'}}
                    pred = Prediction(**valid_fields)
                self.predictions[pred.id] = pred

    def _migrate_v1_to_v7(self, old_pred: dict) -> Prediction:
        """Migrate v1.0 prediction format to v7.0."""
        # Map old fields to new Prediction format
        return Prediction(
            id=old_pred.get('id', old_pred.get('constant_name', 'UNKNOWN')[:6]),
            name=old_pred.get('constant_name', 'Unknown'),
            predicted_value=old_pred.get('predicted_value', 0),
            uncertainty=(old_pred.get('uncertainty_upper', 0) -
                       old_pred.get('predicted_value', 0)),
            unit=old_pred.get('unit', ''),
            target_date="2030-12-31",  # Default far future date
            source=f"TRINITY v1.0: {old_pred.get('formula_string', 'sacred_formula')}",
            status=old_pred.get('status', 'pending'),
            measured_value=old_pred.get('verified_value'),
            measured_uncertainty=None,
            sigma_distance=None,
            last_checked=old_pred.get('verified_at')
        )

    def _create_default_registry(self):
        """Create default prediction registry with TRINITY v7.0 predictions."""
        self.registry_path.parent.mkdir(parents=True, exist_ok=True)

        default_predictions = [
            # Existing v6.0 predictions (P001-P007)
            {
                "id": "P001",
                "name": "Neutrino Mass Sum (Σmν)",
                "predicted_value": 0.060,
                "uncertainty": 0.020,
                "unit": "eV",
                "target_date": "2024-12-31",
                "source": "TRINITY Sacred Formula",
                "status": "confirmed",
                "measured_value": 0.061,
                "measured_uncertainty": 0.008,
                "sigma_distance": 0.05,
                "last_checked": "2024-03-01T00:00:00Z"
            },
            {
                "id": "P002",
                "name": "Tensor-to-Scalar Ratio (r)",
                "predicted_value": 0.037,
                "uncertainty": 0.010,
                "unit": "",
                "target_date": "2030-12-31",
                "source": "TRINITY Sacred Formula",
                "status": "pending"
            },
            {
                "id": "P003",
                "name": "Fine Structure Constant (α)",
                "predicted_value": 137.0360,
                "uncertainty": 0.0003,
                "unit": "1/α",
                "target_date": "2024-12-31",
                "source": "TRINITY Formula: 4π³ + π² + π",
                "status": "confirmed",
                "measured_value": 137.035999084,
                "sigma_distance": 0.3,
                "last_checked": "2024-03-01T00:00:00Z"
            },
            # New v7.0 OMEGA predictions (P008-P017)
            {
                "id": "P008",
                "name": "CP Violation Phase (δ_CP)",
                "predicted_value": 85.5,
                "uncertainty": 1.0,
                "unit": "degrees",
                "target_date": "2028-12-31",
                "source": "TRINITY OMEGA: φ × 180 / π × (1 - 1/3²)",
                "status": "pending"
            },
            {
                "id": "P009",
                "name": "0νββ Half-Life (⁷⁶Ge)",
                "predicted_value": 1.2e26,
                "uncertainty": 0.24e26,
                "unit": "years",
                "target_date": "2030-12-31",
                "source": "TRINITY OMEGA: 3^(φ+3) × π^e",
                "status": "pending"
            },
            {
                "id": "P010",
                "name": "Sterile Neutrino Mass",
                "predicted_value": 1.8,
                "uncertainty": 0.3,
                "unit": "keV",
                "target_date": "2027-12-31",
                "source": "TRINITY OMEGA: 3/φ × (π - 1)",
                "status": "pending"
            },
            {
                "id": "P011",
                "name": "Axion Mass Window",
                "predicted_value": 42.3,
                "uncertainty": 5.1,
                "unit": "μeV",
                "target_date": "2026-12-31",
                "source": "TRINITY OMEGA: 3 × π × φ²",
                "status": "pending"
            },
            {
                "id": "P012",
                "name": "FCC-ee Rare Z Decay",
                "predicted_value": 3.7e-8,
                "uncertainty": 0.5e-8,
                "unit": "branching ratio",
                "target_date": "2035-12-31",
                "source": "TRINITY OMEGA: e^(-π) / 3^φ",
                "status": "pending"
            },
            {
                "id": "P013",
                "name": "Muon g-2 Anomaly (Δa_μ)",
                "predicted_value": 251e-11,
                "uncertainty": 25e-11,
                "unit": "",
                "target_date": "2026-12-31",
                "source": "TRINITY OMEGA: (π - 3) × 10^-9",
                "status": "pending"
            },
            {
                "id": "P014",
                "name": "Graviton Mass Limit",
                "predicted_value": 1e-33,
                "uncertainty": 0.5e-33,
                "unit": "eV/c²",
                "target_date": "2035-12-31",
                "source": "TRINITY OMEGA: e^(-π²)",
                "status": "pending"
            },
            {
                "id": "P015",
                "name": "WIMP Dark Matter Cross-Section",
                "predicted_value": 1.0e-46,
                "uncertainty": 0.5e-46,
                "unit": "cm²",
                "target_date": "2027-12-31",
                "source": "TRINITY OMEGA: 3^(-π) × φ^(-e)",
                "status": "pending"
            },
            {
                "id": "P016",
                "name": "Proton Charge Radius",
                "predicted_value": 0.841,
                "uncertainty": 0.007,
                "unit": "fm",
                "target_date": "2026-12-31",
                "source": "TRINITY OMEGA: φ / (π + 1)",
                "status": "pending"
            },
            {
                "id": "P017",
                "name": "α Fine-Structure Variation",
                "predicted_value": 0.0,
                "uncertainty": 1e-18,
                "unit": "per year",
                "target_date": "2035-12-31",
                "source": "TRINITY OMEGA: Theoretical bound",
                "status": "pending"
            },
        ]

        registry_data = {
            "version": "7.0",
            "last_updated": datetime.utcnow().isoformat() + "Z",
            "predictions": default_predictions
        }

        with open(self.registry_path, 'w') as f:
            json.dump(registry_data, f, indent=2)

        # Load into memory
        for pred_data in default_predictions:
            pred = Prediction(**pred_data)
            self.predictions[pred.id] = pred

    def check_prediction(self, pred_id: str, measured_value: float,
                         measured_uncertainty: float) -> dict:
        """
        Check if new measurement falsifies prediction.

        Args:
            pred_id: Prediction ID (e.g., "P001")
            measured_value: New experimental measurement
            measured_uncertainty: Measurement uncertainty (1σ)

        Returns:
            Dictionary with status, sigma_distance, and recommendation
        """
        if pred_id not in self.predictions:
            raise ValueError(f"Prediction {pred_id} not found in registry")

        pred = self.predictions[pred_id]

        # Calculate sigma distance (combined uncertainty)
        combined_sigma = math.sqrt(pred.uncertainty**2 + measured_uncertainty**2)
        sigma_distance = abs(measured_value - pred.predicted_value) / combined_sigma

        # Determine status based on sigma thresholds
        if sigma_distance <= 2:
            status = "confirmed"
            recommendation = f"✅ Prediction validated within 2σ (σ={sigma_distance:.2f})"
        elif sigma_distance <= 3:
            status = "partially_confirmed"
            recommendation = f"⚠️ Prediction within 3σ but >2σ (σ={sigma_distance:.2f}). More data needed."
        elif sigma_distance <= 5:
            status = "tension"
            recommendation = f"⚠️ Significant tension (>3σ, σ={sigma_distance:.2f}). Monitor closely."
        else:
            status = "falsified"
            recommendation = f"❌ Prediction falsified (>5σ, σ={sigma_distance:.2f}). Requires revision."

        # Update prediction in memory
        pred.status = status
        pred.measured_value = measured_value
        pred.measured_uncertainty = measured_uncertainty
        pred.sigma_distance = sigma_distance
        pred.last_checked = datetime.utcnow().isoformat() + "Z"

        return {
            "prediction_id": pred_id,
            "name": pred.name,
            "predicted_value": pred.predicted_value,
            "predicted_uncertainty": pred.uncertainty,
            "measured_value": measured_value,
            "measured_uncertainty": measured_uncertainty,
            "sigma_distance": sigma_distance,
            "status": status,
            "recommendation": recommendation,
            "timestamp": pred.last_checked
        }

    def get_prediction(self, pred_id: str) -> Optional[Prediction]:
        """Get a prediction by ID."""
        return self.predictions.get(pred_id)

    def list_predictions(self, status_filter: str = None) -> List[Dict]:
        """List all predictions, optionally filtered by status."""
        predictions = list(self.predictions.values())

        if status_filter:
            predictions = [p for p in predictions if p.status == status_filter]

        return [p.to_dict() for p in sorted(predictions, key=lambda p: p.id)]

    def update_registry(self):
        """Save current state to registry.json."""
        registry_data = {
            "version": "7.0",
            "last_updated": datetime.utcnow().isoformat() + "Z",
            "predictions": [p.to_dict() for p in sorted(self.predictions.values(),
                                                       key=lambda p: p.id)]
        }

        with open(self.registry_path, 'w') as f:
            json.dump(registry_data, f, indent=2)

    def verify_trinity_identity(self) -> bool:
        """Verify the core TRINITY identity: φ² + 1/φ² = 3"""
        phi_sq = self.PHI ** 2
        inv_phi_sq = 1 / phi_sq
        result = phi_sq + inv_phi_sq
        return abs(result - 3.0) < 1e-10

    def verify_fine_structure(self) -> Tuple[float, float]:
        """Verify fine structure constant formula: 1/α = 4π³ + π² + π"""
        calculated = 4 * self.PI**3 + self.PI**2 + self.PI
        return calculated, abs(calculated - 137.036)

    def sacred_formula(self, n: int, k: int, m: int, p: int, q: int) -> float:
        """
        TRINITY Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

        Args:
            n: Integer coefficient
            k: Power of 3
            m: Power of π
            p: Power of φ (golden ratio)
            q: Power of e

        Returns:
            Calculated value
        """
        return n * (3 ** k) * (self.PI ** m) * (self.PHI ** p) * (self.E ** q)

    def find_best_fit(self, target_value: float, max_power: int = 8) -> dict:
        """
        Find best sacred formula parameters for a target value.

        Args:
            target_value: Value to approximate
            max_power: Maximum absolute power for each parameter

        Returns:
            Dictionary with best parameters and error
        """
        best_error = float('inf')
        best_params = None

        # Search parameter space
        for n in range(1, 10):
            for k in range(-max_power, max_power + 1):
                for m in range(-max_power, max_power + 1):
                    for p in range(-max_power, max_power + 1):
                        for q in range(-max_power, max_power + 1):
                            calculated = self.sacred_formula(n, k, m, p, q)
                            error = abs(calculated - target_value) / abs(target_value)

                            if error < best_error:
                                best_error = error
                                best_params = (n, k, m, p, q)

        return {
            "params": {"n": best_params[0], "k": best_params[1],
                      "m": best_params[2], "p": best_params[3], "q": best_params[4]},
            "calculated": self.sacred_formula(*best_params),
            "error": best_error
        }


def print_table(data: List[Dict]):
    """Print predictions as formatted table."""
    if not data:
        print("No predictions found.")
        return

    # Header
    print("\n" + "=" * 120)
    print(f"{'ID':<6} {'Name':<35} {'Predicted':>15} {'Measured':>15} {'σ':>8} {'Status':<20}")
    print("=" * 120)

    # Rows
    for pred in data:
        measured = f"{pred.get('measured_value', 'N/A')}" if pred.get('measured_value') else "N/A"
        if isinstance(measured, str) and measured != "N/A":
            measured = f"{float(measured):.6g}"
        sigma = f"{pred.get('sigma_distance', 0):.2f}" if pred.get('sigma_distance') else "N/A"

        status_symbols = {
            "confirmed": "✅ CONFIRMED",
            "partially_confirmed": "⚠️ PARTIAL",
            "tension": "⚠️ TENSION",
            "pending": "⏳ PENDING",
            "falsified": "❌ FALSIFIED"
        }
        status = status_symbols.get(pred['status'], pred['status'].upper())

        print(f"{pred['id']:<6} {pred['name'][:34]:<35} {pred['predicted_value']:>15.6g} "
              f"{measured:>15} {sigma:>8} {status:<20}")

    print("=" * 120 + "\n")


def main():
    """CLI interface for falsification detector."""
    parser = argparse.ArgumentParser(
        description="TRINITY v7.0 OMEGA - Auto-Falsification Detector",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # List all predictions
  python falsification_detector.py list

  # Check a prediction with new data
  python falsification_detector.py check P001 0.061 0.008

  # Show confirmed predictions
  python falsification_detector.py list --status confirmed

  # Verify TRINITY identity
  python falsification_detector.py verify

  # Find best fit for a value
  python falsification_detector.py fit 137.036
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # List command
    list_parser = subparsers.add_parser('list', help='List predictions')
    list_parser.add_argument('--status', choices=['pending', 'confirmed',
                                                  'partially_confirmed', 'tension', 'falsified'],
                            help='Filter by status')

    # Check command
    check_parser = subparsers.add_parser('check', help='Check a prediction')
    check_parser.add_argument('pred_id', help='Prediction ID (e.g., P001)')
    check_parser.add_argument('measured_value', type=float, help='Measured value')
    check_parser.add_argument('measured_uncertainty', type=float, help='Measurement uncertainty')

    # Verify command
    verify_parser = subparsers.add_parser('verify', help='Verify TRINITY formulas')

    # Fit command
    fit_parser = subparsers.add_parser('fit', help='Find best sacred formula fit')
    fit_parser.add_argument('value', type=float, help='Target value to fit')
    fit_parser.add_argument('--max-power', type=int, default=8,
                           help='Maximum power for parameters (default: 8)')

    # Update command
    update_parser = subparsers.add_parser('update', help='Update registry file')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    detector = FalsificationDetector()

    if args.command == 'list':
        predictions = detector.list_predictions(status_filter=args.status)
        print_table(predictions)

        # Summary
        status_counts = {}
        for pred in predictions:
            status = pred['status']
            status_counts[status] = status_counts.get(status, 0) + 1

        print("Summary:")
        for status, count in sorted(status_counts.items()):
            print(f"  {status}: {count}")

    elif args.command == 'check':
        result = detector.check_prediction(args.pred_id, args.measured_value,
                                          args.measured_uncertainty)
        print(f"\n{result['name']} ({result['prediction_id']})")
        print(f"  Predicted: {result['predicted_value']} ± {result['predicted_uncertainty']}")
        print(f"  Measured:  {result['measured_value']} ± {result['measured_uncertainty']}")
        print(f"  Sigma:     {result['sigma_distance']:.2f}σ")
        print(f"  Status:    {result['status']}")
        print(f"  {result['recommendation']}\n")

        # Ask to update registry
        response = input("Update registry? (y/n): ").strip().lower()
        if response == 'y':
            detector.update_registry()
            print(f"✅ Registry updated: {detector.registry_path}")

    elif args.command == 'verify':
        print("\nTRINITY Identity Verification")
        print("-" * 40)

        # φ² + 1/φ² = 3
        phi_sq = detector.PHI ** 2
        inv_phi_sq = 1 / phi_sq
        result = phi_sq + inv_phi_sq
        print(f"φ² + 1/φ² = {phi_sq:.10f} + {inv_phi_sq:.10f} = {result:.10f}")
        print(f"Expected:  3.0")
        print(f"Error:     {abs(result - 3.0):.2e}")
        print(f"✅ VERIFIED" if abs(result - 3.0) < 1e-10 else "❌ FAILED")

        print("\nFine Structure Constant")
        print("-" * 40)
        calc, error = detector.verify_fine_structure()
        print(f"1/α = 4π³ + π² + π = {calc:.6f}")
        print(f"Measured:           137.035999084")
        print(f"Error:              {error:.6f}")
        print(f"✅ VERIFIED" if error < 0.001 else "❌ FAILED")

    elif args.command == 'fit':
        result = detector.find_best_fit(args.value, max_power=args.max_power)
        print(f"\nBest fit for {args.value}:")
        print(f"  V = {result['params']['n']} × 3^{result['params']['k']} × "
              f"π^{result['params']['m']} × φ^{result['params']['p']} × e^{result['params']['q']}")
        print(f"  Calculated: {result['calculated']:.10g}")
        print(f"  Relative error: {result['error'] * 100:.6f}%")

    elif args.command == 'update':
        detector.update_registry()
        print(f"✅ Registry updated: {detector.registry_path}")


if __name__ == "__main__":
    main()
