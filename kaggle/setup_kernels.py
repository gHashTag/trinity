#!/usr/bin/env python3
"""
Kaggle Kernel Metadata Generator v5
Final fix: clean IDs without duplication
"""
import json
from pathlib import Path

# Track configuration mapping
# id_prefix should NOT contain the task name
TRACKS = {
    "track1_learning": {
        "id_prefix": "playra/trinity-thlp",
        "dataset": "playra/trinity-cognitive-probes-thlp",
        "notebooks": [
            ("task01_few_shot_induction", "Task01 Few Shot"),
            ("task02_belief_update", "Task02 Belief Update"),
            ("task03_error_driven", "Task03 Error Driven"),
            ("task04_reward_signal", "Task04 Reward Signal"),
            ("task05_long_context", "Task05 Long Context"),
        ]
    },
    "track2_metacognition": {
        "id_prefix": "playra/trinity-tmp",
        "dataset": "playra/trinity-cognitive-probes-tmp",
        "notebooks": [
            ("task06_confidence_calib", "Task06 Confidence"),
        ]
    },
    "track3_attention": {
        "id_prefix": "playra/trinity-tagp",
        "dataset": "playra/trinity-cognitive-probes-tagp",
        "notebooks": [
            ("task11_selective_filtering", "Task11 Selective"),
            ("task12_sustained_attention", "Task12 Sustained"),
            ("task13_attention_shifting", "Task13 Shifting"),
            ("task14_adversarial_needle", "Task14 Needle"),
            ("task15_divided_attention", "Task15 Divided"),
        ]
    },
    "track4_executive": {
        "id_prefix": "playra/trinity-tefb",
        "dataset": "playra/trinity-cognitive-probes-tefb",
        "notebooks": [
            ("task16_multi_step", "Task16 Multi Step"),
            ("task17_stroop", "Task17 Stroop"),
            ("task18_wisconsin", "Task18 Wisconsin"),
            ("task19_working_memory", "Task19 Working Memory"),
            ("task20_conflicting", "Task20 Conflicting"),
        ]
    },
    "track5_social": {
        "id_prefix": "playra/trinity-tscp",
        "dataset": "playra/trinity-cognitive-probes-tscp",
        "notebooks": [
            ("task21_theory_of_mind", "Task21 Theory Of Mind"),
            ("task22_pragmatic", "Task22 Pragmatic"),
            ("task23_audience_adaptation", "Task23 Audience"),
            ("task25_social_norms", "Task25 Social Norms"),
        ]
    },
}

def slugify(title: str) -> str:
    """Convert title to slug format (lowercase, hyphens)"""
    return title.lower().replace(" ", "-")

def create_kernel_metadata(track_dir: str, config: dict, notebook_name: str, title: str) -> dict:
    """Create kernel metadata for a single notebook"""
    notebook_file = f"{notebook_name}.ipynb"
    slug = slugify(title)
    kernel_id = f"{config['id_prefix']}-{slug}"

    return {
        "id": kernel_id,
        "title": title,
        "code_file": notebook_file,
        "language": "python",
        "kernel_type": "notebook",
        "is_private": "false",
        "enable_gpu": "false",
        "enable_internet": "true",  # CRITICAL: for OpenRouter API calls
        "dataset_sources": [config['dataset']],
        "competition_sources": ["kaggle-measuring-agi"],
        "kernel_sources": [],
        "model_sources": []
    }

def main():
    base_dir = Path("kaggle/notebooks")
    created = []
    errors = []

    for track_dir, config in TRACKS.items():
        track_path = base_dir / track_dir

        for notebook_name, title in config["notebooks"]:
            notebook_path = track_path / notebook_name
            notebook_file = notebook_path / f"{notebook_name}.ipynb"

            if not notebook_file.exists():
                errors.append(f"Notebook not found: {notebook_file}")
                continue

            metadata = create_kernel_metadata(track_dir, config, notebook_name, title)
            metadata_path = track_path / notebook_name / "kernel-metadata.json"

            with open(metadata_path, 'w') as f:
                json.dump(metadata, f, indent=2)

            created.append((track_dir, metadata['id'], title))

    for item in created:
        print(f"✅ {item[2]}")
        print(f"   → {item[1]}")

    if errors:
        print("\n⚠️  Errors:")
        for e in errors:
            print(f"   {e}")

    print(f"\n📊 Created {len(created)} kernel-metadata.json files")
    return created

if __name__ == "__main__":
    main()
