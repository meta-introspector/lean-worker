"""
Extract one-hot labels from LinguaClassifier classifications.

Usage:
    python3 extract_labels.py --sigs path/to/signatures.json \
                              --labels path/to/labels.csv \
                              --label-type {pos,sem} \
                              --N 257 \
                              --limit 1000

Outputs a CSV where each row is a one-hot vector over the POS tags or semantic
categories, in the same order as the signatures.
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from LinguaClassifier import ClassificationEngine, load_signatures

POS_TAGS = [
    "Noun", "Verb", "Adjective", "Adverb", "Conjunction", "Preposition",
    "Quantifier", "Determiner", "Numeral", "Constructor",
    "Eliminator", "Keyword", "Attribute", "Tactic", "Interjection"
]

SEM_CATS = [
    "Misc", "Analysis", "Topology", "Algebra", "ZeroKnowledge", "DataStructures",
    "TypeTheory", "Arithmetic", "NumberTheory", "Computation", "CategoryTheory",
    "AristotleSpecific", "Combinatorics", "FileSystem", "Logic", "LanguageMeta",
    "Hypertext", "SystemStack"
]


def main():
    parser = argparse.ArgumentParser(description="Extract one-hot labels from classifications")
    parser.add_argument("--sigs", required=True, help="Signatures JSON file")
    parser.add_argument("--labels", required=True, help="Output labels CSV file")
    parser.add_argument("--label-type", choices=["pos", "sem"], default="sem",
                        help="Label type: 'pos' or 'sem'")
    parser.add_argument("--N", type=int, default=257, help="Finite field size")
    parser.add_argument("--limit", type=int, default=None, help="Limit signatures")
    args = parser.parse_args()

    sigs = load_signatures(args.sigs)
    if args.limit:
        sigs = sigs[:args.limit]

    engine = ClassificationEngine()

    if args.label_type == "pos":
        labels_map = {pos: i for i, pos in enumerate(POS_TAGS)}
        labels = POS_TAGS
    else:
        labels_map = {cat: i for i, cat in enumerate(SEM_CATS)}
        labels = SEM_CATS

    # Sort labels for deterministic output
    labels.sort()
    labels_map = {pos: i for i, pos in enumerate(labels)}

    with open(args.labels, "w") as f:
        f.write(",".join(labels) + "\n")
        for ident in sigs:
            analysis = engine.classify(ident)
            if args.label_type == "pos":
                l = analysis["pos"]
            else:
                l = analysis["semantics"]
            one_hot = [0] * len(labels)
            if l in labels_map:
                one_hot[labels_map[l]] = 1
            f.write(",".join(str(v) for v in one_hot) + "\n")

    print(f"Extracted {len(sigs)} labels into {args.labels}")
    print(f"Labels ({len(labels)}): {', '.join(labels)}")


if __name__ == "__main__":
    main()
