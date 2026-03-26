# Contributing to Trinity Cognitive Probes

Thank you for your interest in contributing to Trinity Cognitive Probes!

## Overview

Trinity Cognitive Probes is a dataset for evaluating AGI capabilities through neuroanatomically-grounded cognitive tasks. Contributions are welcome in the form of:

- New question templates
- Additional cognitive tasks
- Improved validation
- Bug fixes
- Documentation improvements

## Getting Started

### Prerequisites

- Python 3.10+
- pip package manager

### Setup

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity/kaggle

# Install dependencies
pip install -r requirements.txt

# Run tests
python -m pytest tests/
```

## Adding Questions

### Question Template Format

Questions are stored as JSON in `kaggle/questions/`:

```json
{
  "task_name": {
    "description": "Task description",
    "templates": [
      {
        "id": "unique_id",
        "question": "Question text",
        "answer": "Expected answer",
        "ground_truth_confidence": 0.95,
        "category": "category_name",
        "difficulty": "easy"
      }
    ]
  }
}
```

### Guidelines

1. **Diversity**: Ensure questions are semantically diverse
2. **Difficulty**: Vary difficulty across levels (easy, medium, hard)
3. **Accuracy**: Verify all factual claims
4. **Clarity**: Questions should be unambiguous
5. **Confidence**: Set appropriate ground truth confidence values

### Adding New Questions

1. Edit the appropriate JSON file in `kaggle/questions/`
2. Run validation: `python -m kaggle.validate --check diversity`
3. Run tests: `python -m pytest tests/test_generators.py`
4. Submit pull request

## Adding New Tasks

### 1. Define Task Specification

Create a task definition in the appropriate generator:

```python
TASK_DESCRIPTIONS = {
    "new_task": {
        "name": "Human-Readable Name",
        "desc": "Scientific description",
        "brain_zone": "zone_name",
        "neural_analog": "Implementation reference"
    }
}
```

### 2. Create Question Templates

Add question templates to `kaggle/questions/`:

```json
{
  "new_task": {
    "templates": [
      {
        "id": "nt_001",
        "question": "...",
        "answer": "...",
        "ground_truth_confidence": 0.9
      }
    ]
  }
}
```

### 3. Implement Generator Logic

Add generation function to the appropriate `gen_*.py` file:

```python
def generate_new_task_items(target_count: int = 440) -> List[NewItem]:
    items = []
    for i in range(target_count):
        # Generate item logic
        item = NewItem(...)
        items.append(item)
    return items
```

### 4. Add Tests

Add tests in `kaggle/tests/test_generators.py`:

```python
class TestNewTaskGenerator(unittest.TestCase):
    def test_generate_items(self):
        items = gen_module.generate_new_task_items(target_count=10)
        self.assertEqual(len(items), 10)
```

## Code Style

- Follow PEP 8
- Use type hints
- Add docstrings to functions
- Keep functions under 50 lines
- Write tests for new functionality

## Testing

### Running Tests

```bash
# Run all tests
python -m pytest tests/

# Run specific test file
python -m pytest tests/test_scoring.py

# Run with coverage
python -m pytest --cov=kaggle.eval tests/
```

### Test Coverage

Aim for >80% code coverage on new code.

## Validation

Always run validation before committing:

```bash
# Validate all datasets
python -m kaggle.validate --check all

# Validate specific file
python -m kaggle.validate --file data/tmp_metacognition.csv
```

## Documentation

### Updating Documentation

- Keep DATASET_CARD.md accurate
- Update relevant writeup in `writeups/`
- Add inline comments for complex logic

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and test
4. Run validation and tests
5. Commit with conventional commits: `feat(scope): description`
6. Push and create pull request

### PR Checklist

- [ ] Tests pass locally
- [ ] Validation passes
- [ ] Documentation updated
- [ ] Commit messages follow convention
- [ ] No merge conflicts

## Issue Reporting

When reporting issues, include:

- Python version
- Steps to reproduce
- Expected vs actual behavior
- Error messages/tracebacks

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

- Open an issue for discussion
- Check existing documentation
- Review scientific writeups in `writeups/`

Thank you for contributing to Trinity Cognitive Probes!
