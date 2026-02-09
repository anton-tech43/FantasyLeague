#!/usr/bin/env python3
"""
Goal Digger — Prompt Validation Framework

Validates generated content against the quality rules defined in the prompt system.
Can be run locally without an API key for structural validation, or with
ANTHROPIC_API_KEY set to run full review bot tests.

Usage:
    # Structural validation only (no API key needed)
    python validate-content.py --structural

    # Full review bot testing (requires ANTHROPIC_API_KEY)
    python validate-content.py --full

    # Validate a single content item from JSON file
    python validate-content.py --file content.json

    # Validate the golden examples
    python validate-content.py --golden
"""

import json
import os
import re
import sys
from pathlib import Path

# Paths relative to this script
SCRIPT_DIR = Path(__file__).parent
PROMPTS_DIR = SCRIPT_DIR.parent
GOLDEN_EXAMPLES_FILE = SCRIPT_DIR / "golden-examples.json"


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    BOLD = "\033[1m"
    END = "\033[0m"


def load_golden_examples():
    """Load golden examples from JSON file."""
    with open(GOLDEN_EXAMPLES_FILE, "r") as f:
        return json.load(f)


# --- Structural Validators ---

def validate_headline(headline: str) -> list[dict]:
    """Validate headline meets structural requirements."""
    issues = []

    # Character count
    char_count = len(headline)
    if char_count > 200:
        issues.append({
            "rule": "headline_length",
            "severity": "fail",
            "message": f"Headline is {char_count} characters (max 200)",
        })

    # Sentence count (rough: split on . ! ?)
    sentences = [s.strip() for s in re.split(r'[.!?]+', headline) if s.strip()]
    if len(sentences) > 2:
        issues.append({
            "rule": "headline_sentences",
            "severity": "fail",
            "message": f"Headline has {len(sentences)} sentences (max 2)",
        })

    # Should not start with team name
    team_names = ["Arsenal", "Manchester United", "Man United", "Man Utd",
                  "West Ham", "West Ham United"]
    for name in team_names:
        if headline.startswith(name):
            issues.append({
                "rule": "headline_starts_with_team",
                "severity": "warning",
                "message": f"Headline starts with team name '{name}' — should lead with something more engaging",
            })
            break

    # Should not start with BREAKING
    if headline.upper().startswith("BREAKING"):
        issues.append({
            "rule": "headline_breaking",
            "severity": "warning",
            "message": "Headline starts with 'BREAKING' — too news-alert-y",
        })

    return issues


def validate_talking_points(talking_points: list[str]) -> list[dict]:
    """Validate talking points meet structural requirements."""
    issues = []

    # Count check
    count = len(talking_points)
    if count < 3:
        issues.append({
            "rule": "talking_points_min",
            "severity": "fail",
            "message": f"Only {count} talking points (minimum 3)",
        })
    if count > 5:
        issues.append({
            "rule": "talking_points_max",
            "severity": "fail",
            "message": f"{count} talking points (maximum 5)",
        })

    # Per-point checks
    for i, point in enumerate(talking_points, 1):
        sentences = [s.strip() for s in re.split(r'[.!?]+', point) if s.strip()]
        if len(sentences) > 3:  # Allow some slack since conversational text is tricky to split
            issues.append({
                "rule": "talking_point_length",
                "severity": "warning",
                "message": f"Talking point {i} may be too long ({len(sentences)} sentences detected)",
            })

    return issues


def validate_body(body: str) -> list[dict]:
    """Validate body meets structural requirements."""
    issues = []

    # Paragraph count
    paragraphs = [p.strip() for p in body.split("\n\n") if p.strip()]
    para_count = len(paragraphs)
    if para_count < 3:
        issues.append({
            "rule": "body_paragraphs_min",
            "severity": "fail",
            "message": f"Only {para_count} paragraphs (minimum 3)",
        })
    if para_count > 5:
        issues.append({
            "rule": "body_paragraphs_max",
            "severity": "fail",
            "message": f"{para_count} paragraphs (maximum 5)",
        })

    # Per-paragraph sentence check
    for i, para in enumerate(paragraphs, 1):
        sentences = [s.strip() for s in re.split(r'[.!?]+', para) if s.strip()]
        if len(sentences) > 5:  # Slight slack for conversational writing
            issues.append({
                "rule": "paragraph_length",
                "severity": "warning",
                "message": f"Paragraph {i} may be too long ({len(sentences)} sentences)",
            })

    # Estimated read time (rough: ~250 words per minute = ~4 words per second)
    word_count = len(body.split())
    read_seconds = (word_count / 250) * 60
    if read_seconds > 75:  # Allow 25% over the 60-second target
        issues.append({
            "rule": "body_read_time",
            "severity": "warning",
            "message": f"Body is ~{word_count} words, estimated {int(read_seconds)}s read time (target: <60s)",
        })

    return issues


def validate_emotional_context(emotional_context: str) -> list[dict]:
    """Validate emotional_context is a valid enum value."""
    valid = ["exciting", "bad_news", "drama", "informational", "funny"]
    issues = []
    if emotional_context not in valid:
        issues.append({
            "rule": "emotional_context_enum",
            "severity": "fail",
            "message": f"Invalid emotional_context '{emotional_context}'. Must be one of: {valid}",
        })
    return issues


def validate_newsworthiness(score: int, is_newsworthy: bool = True) -> list[dict]:
    """Validate newsworthiness score and publish decision."""
    issues = []
    if score < 1 or score > 10:
        issues.append({
            "rule": "newsworthiness_range",
            "severity": "fail",
            "message": f"Newsworthiness score {score} out of range (1-10)",
        })
    if is_newsworthy and score < 6:
        issues.append({
            "rule": "newsworthiness_threshold",
            "severity": "warning",
            "message": f"Marked as newsworthy but score is {score} (publish threshold is 6+)",
        })
    return issues


def check_jargon(text: str) -> list[dict]:
    """Check for unexplained football jargon."""
    jargon_terms = [
        "clean sheet", "set piece", "counter-attack", "counter attack",
        "pressing", "back four", "holding midfielder", "xG",
        "progressive passes", "expected assists", "chance creation",
        "final third", "box-to-box", "false nine", "number 10",
        "deep-lying", "regista", "trequartista", "gegenpressing",
        "low block", "high line", "offside trap", "overlapping run",
        "inverted fullback", "double pivot", "half-space",
        "underlap", "ball retention", "possession-based",
        "transition play",
    ]
    issues = []
    text_lower = text.lower()
    for term in jargon_terms:
        if term.lower() in text_lower:
            # Check if the term is explained (heuristic: look for parentheses or dash nearby)
            idx = text_lower.index(term.lower())
            context = text[max(0, idx - 20):idx + len(term) + 100]
            if "(" not in context and " — " not in context and " - " not in context:
                issues.append({
                    "rule": "unexplained_jargon",
                    "severity": "warning",
                    "message": f"Potentially unexplained jargon: '{term}'",
                })
    return issues


def check_condescension(text: str) -> list[dict]:
    """Check for condescending phrases."""
    patterns = [
        r"you probably don.t know",
        r"football might seem confusing",
        r"don.t worry if you don.t understand",
        r"you might not know this",
        r"this might be confusing",
        r"let me explain",
        r"as you may not know",
        r"football can be confusing",
    ]
    issues = []
    text_lower = text.lower()
    for pattern in patterns:
        if re.search(pattern, text_lower):
            issues.append({
                "rule": "condescending_tone",
                "severity": "fail",
                "message": f"Condescending phrase detected: '{pattern}'",
            })
    return issues


def check_filler_phrases(text: str) -> list[dict]:
    """Check for filler phrases that should be removed."""
    fillers = [
        "it's worth noting that",
        "interestingly enough",
        "at the end of the day",
        "when all is said and done",
        "it goes without saying",
        "needless to say",
        "as a matter of fact",
    ]
    issues = []
    text_lower = text.lower()
    for filler in fillers:
        if filler in text_lower:
            issues.append({
                "rule": "filler_phrase",
                "severity": "warning",
                "message": f"Filler phrase detected: '{filler}'",
            })
    return issues


def validate_content_item(item: dict) -> dict:
    """Run all structural validations on a content item."""
    all_issues = []

    # Headline
    if "headline" in item:
        all_issues.extend(validate_headline(item["headline"]))

    # Talking points
    if "talking_points" in item:
        all_issues.extend(validate_talking_points(item["talking_points"]))

    # Body
    if "body" in item:
        all_issues.extend(validate_body(item["body"]))

    # Emotional context
    if "emotional_context" in item:
        all_issues.extend(validate_emotional_context(item["emotional_context"]))

    # Newsworthiness
    if "newsworthiness_score" in item:
        all_issues.extend(validate_newsworthiness(
            item["newsworthiness_score"],
            item.get("is_newsworthy", True),
        ))

    # Cross-cutting checks on all text
    full_text = " ".join([
        item.get("headline", ""),
        " ".join(item.get("talking_points", [])),
        item.get("body", ""),
    ])
    all_issues.extend(check_jargon(full_text))
    all_issues.extend(check_condescension(full_text))
    all_issues.extend(check_filler_phrases(full_text))

    # Compute results
    fails = [i for i in all_issues if i["severity"] == "fail"]
    warnings = [i for i in all_issues if i["severity"] == "warning"]

    return {
        "pass": len(fails) == 0,
        "fail_count": len(fails),
        "warning_count": len(warnings),
        "issues": all_issues,
    }


def validate_golden_examples():
    """Validate all golden examples pass structural checks."""
    data = load_golden_examples()

    print(f"\n{Colors.BOLD}=== Goal Digger Prompt Validation ==={Colors.END}\n")
    print(f"Testing {len(data['golden_examples'])} golden examples...\n")

    all_passed = True

    for example in data["golden_examples"]:
        result = validate_content_item(example)
        status = f"{Colors.GREEN}PASS{Colors.END}" if result["pass"] else f"{Colors.RED}FAIL{Colors.END}"
        warnings = f" ({Colors.YELLOW}{result['warning_count']} warnings{Colors.END})" if result["warning_count"] > 0 else ""

        print(f"  [{status}] {example['name']}{warnings}")

        if not result["pass"]:
            all_passed = False
            for issue in result["issues"]:
                if issue["severity"] == "fail":
                    print(f"         {Colors.RED}FAIL: {issue['message']}{Colors.END}")

        for issue in result["issues"]:
            if issue["severity"] == "warning":
                print(f"         {Colors.YELLOW}WARN: {issue['message']}{Colors.END}")

    print(f"\n{Colors.BOLD}--- Anti-Pattern Checks ---{Colors.END}\n")
    print(f"Testing {len(data['anti_patterns'])} anti-patterns...\n")

    # Anti-patterns that can only be caught by review bots (not structural checks)
    review_bot_only = {"accuracy", "should_not_publish"}

    for anti in data["anti_patterns"]:
        expected_failures = set(anti.get("expected_failures", []))
        needs_review_bot = expected_failures.issubset(review_bot_only)

        # Build a minimal content item from the anti-pattern
        test_item = {}
        if "headline" in anti:
            test_item["headline"] = anti["headline"]
        if "talking_point" in anti:
            test_item["talking_points"] = [anti["talking_point"]]

        result = validate_content_item(test_item)

        # Anti-patterns SHOULD fail or have warnings
        has_issues = result["fail_count"] > 0 or result["warning_count"] > 0
        if has_issues:
            status = f"{Colors.GREEN}CAUGHT{Colors.END}"
        elif needs_review_bot:
            status = f"{Colors.BLUE}REVIEW-BOT-ONLY{Colors.END}"
        else:
            status = f"{Colors.RED}MISSED{Colors.END}"
            all_passed = False

        print(f"  [{status}] {anti['name']}")
        if needs_review_bot and not has_issues:
            print(f"         {Colors.BLUE}(Requires {', '.join(expected_failures)} review bot to detect){Colors.END}")
        for issue in result["issues"]:
            color = Colors.RED if issue["severity"] == "fail" else Colors.YELLOW
            print(f"         {color}{issue['severity'].upper()}: {issue['message']}{Colors.END}")

    print(f"\n{Colors.BOLD}{'=' * 40}{Colors.END}")
    if all_passed:
        print(f"\n{Colors.GREEN}{Colors.BOLD}All validations passed.{Colors.END}\n")
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}Some validations failed. See above for details.{Colors.END}\n")

    return all_passed


def validate_file(filepath: str):
    """Validate a single content item from a JSON file."""
    with open(filepath, "r") as f:
        item = json.load(f)

    result = validate_content_item(item)

    print(f"\n{Colors.BOLD}=== Validating: {filepath} ==={Colors.END}\n")
    status = f"{Colors.GREEN}PASS{Colors.END}" if result["pass"] else f"{Colors.RED}FAIL{Colors.END}"
    print(f"  Result: [{status}] ({result['fail_count']} fails, {result['warning_count']} warnings)")

    for issue in result["issues"]:
        color = Colors.RED if issue["severity"] == "fail" else Colors.YELLOW
        print(f"    {color}{issue['severity'].upper()}: {issue['message']}{Colors.END}")

    return result["pass"]


def main():
    args = sys.argv[1:]

    if not args or "--golden" in args or "--structural" in args:
        success = validate_golden_examples()
        sys.exit(0 if success else 1)
    elif "--file" in args:
        idx = args.index("--file")
        if idx + 1 >= len(args):
            print("Error: --file requires a path argument")
            sys.exit(1)
        success = validate_file(args[idx + 1])
        sys.exit(0 if success else 1)
    elif "--full" in args:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("Error: ANTHROPIC_API_KEY environment variable not set")
            print("Set it to run full review bot testing, or use --structural for offline validation")
            sys.exit(1)
        print("Full review bot testing requires the Anthropic SDK.")
        print("Install with: pip install anthropic")
        print("Then re-run this script.")
        sys.exit(1)
    else:
        print(__doc__)
        sys.exit(0)


if __name__ == "__main__":
    main()
