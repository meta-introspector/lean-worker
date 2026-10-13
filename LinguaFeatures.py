"""
LinguaFeatures — Feature extraction from classifications.

This module converts a LinguaClassifier analysis dict into a fixed-length feature
vector x in F_N^d (represented as a list of ints in [0, N-1]).
"""

from typing import List, Dict, Any
from LinguaClassifier import ClassificationEngine

# Feature encoding
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

PROOF_ROLES = [
    "Axiom", "Definition", "Theorem", "Lemma", "Corollary",
    "Instance", "Structure", "Typeclass", "Inductive", "Meta"
]


class FeatureExtractor:
    """Extract fixed-length feature vectors from classifications."""

    def __init__(self, prefix_list=None, suffix_list=None):
        # Prefix flags
        self.prefix_list = prefix_list or [
            "Is", "Has", "Of", "To", "Coerce", "From", "With", "No", "Non", "Un", "Re"
        ]
        self.prefix_map = {p.lower(): i for i, p in enumerate(self.prefix_list)}
        # Suffix flags
        self.suffix_list = suffix_list or [
            "_iff", "_eq", "_ne", "_of", "_le", "_lt", "_ge", "_gt",
            "_decidable_eq", "_decidable_le", "_decidable_lt",
            "_decidable_ge", "_decidable_gt", "_for_", "_like", "_esque", "_ish"
        ]
        self.suffix_map = {s: i for i, s in enumerate(self.suffix_list)}
        # POS map
        self.pos_map = {pos: i for i, pos in enumerate(POS_TAGS)}
        # Semantics map
        self.sem_map = {cat: i for i, cat in enumerate(SEM_CATS)}
        # Proof role map
        self.proof_map = {role: i for i, role in enumerate(PROOF_ROLES)}
        # Feature names for readability
        self.feature_names = self._build_feature_names()

    def _build_feature_names(self) -> List[str]:
        names = []
        names.append("len")
        names.append("ascii_sum")
        names.append("hash")
        names.append("decomposed")
        names.append("part_count")
        names.extend(f"prefix_{p.lower()}" for p in self.prefix_list)
        names.extend(f"suffix_{s}" for s in self.suffix_list)
        # We'll add a few camel part indicators (first 3)
        names.extend(f"camel_part_{i+1}" for i in range(3))
        names.extend(f"pos_{pos}" for pos in POS_TAGS)
        names.extend(f"sem_{cat}" for cat in SEM_CATS)
        names.extend(f"proof_{role}" for role in PROOF_ROLES)
        return names

    def _lexical(self, identifier: str) -> List[int]:
        return [len(identifier) % 997, sum(ord(c) for c in identifier) % 997]

    def _morphology(self, morph: Dict[str, Any], N: int) -> List[int]:
        vec = []
        identifier = morph["identifier"]
        s = identifier.lower()
        for p in self.prefix_list:
            vec.append(1 if identifier.startswith(p) else 0)
        for sfx in self.suffix_list:
            vec.append(1 if s.endswith(sfx) else 0)
        # Camel part indicators: we'll store whether each of the first three parts is non-empty
        camel_parts = morph["camel_parts"]
        vec.append(len(camel_parts))
        for i in range(3):
            vec.append(1 if i < len(camel_parts) and camel_parts[i] else 0)
        # Underscore parts count
        vec.append(len(morph["underscore_parts"]))
        return [v % N for v in vec]

    def _pos(self, analysis: Dict[str, Any]) -> List[int]:
        vec = [0] * len(POS_TAGS)
        pos = analysis.get("pos")
        if pos in self.pos_map:
            vec[self.pos_map[pos]] = 1
        return vec

    def _semantics(self, analysis: Dict[str, Any]) -> List[int]:
        vec = [0] * len(SEM_CATS)
        sem = analysis.get("semantics")
        if sem in self.sem_map:
            vec[self.sem_map[sem]] = 1
        return vec

    def _proofrole(self) -> List[int]:
        # Placeholder for future extension
        return [0] * len(PROOF_ROLES)

    def to_vector(self, analysis: Dict[str, Any], N: int) -> List[int]:
        """Convert an analysis dict to a fixed-length feature vector in F_N^d."""
        morph = analysis["morphology"]
        vec = []
        identifier = analysis["identifier"]
        # Lexical
        vec.extend(self._lexical(identifier))
        # Morphology
        vec.extend(self._morphology(morph, N))
        # POS
        vec.extend(self._pos(analysis))
        # Semantics
        vec.extend(self._semantics(analysis))
        # ProofRole (zeros for now)
        vec.extend(self._proofrole())
        # Normalize all entries to [0, N-1]
        return [v % N for v in vec]

    def to_vector_str(self, analysis: Dict[str, Any], N: int) -> str:
        return ",".join(str(v) for v in self.to_vector(analysis, N))


def extract_features(identifiers: List[str], N: int = 257) -> tuple:
    """Batch extract features for a list of identifiers.
    Returns (feature_matrix, feature_names)."""
    engine = ClassificationEngine()
    extractor = FeatureExtractor()
    features = []
    for ident in identifiers:
        analysis = engine.classify(ident)
        features.append(extractor.to_vector(analysis, N))
    return features, extractor.feature_names


def load_signatures(path: str) -> List[str]:
    import json
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list):
        return [s for s in data if isinstance(s, str)]
    elif isinstance(data, dict):
        for key in ('symbols', 'identifiers', 'terms', 'signatures', 'results'):
            if key in data and isinstance(data[key], list):
                return [s for s in data[key] if isinstance(s, str)]
    return []


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Extract LinguaLean feature vectors")
    parser.add_argument("input", help="Input signatures (JSON)")
    parser.add_argument("--output", "-o", help="Output vectors file (CSV)")
    parser.add_argument("--N", "-N", type=int, default=257, help="Field size")
    parser.add_argument("--limit", "-n", type=int, default=None, help="Limit entries")
    args = parser.parse_args()

    sigs = load_signatures(args.input)
    if args.limit:
        sigs = sigs[:args.limit]

    features, names = extract_features(sigs, args.N)

    with open(args.output, "w") as f:
        f.write(",".join(names) + "\n")
        for vec in features:
            f.write(",".join(str(v) for v in vec) + "\n")

    print(f"Extracted {len(features)} feature vectors ({len(names)} features)")
    print(f"First vector: {features[0]}")
    if args.output:
        print(f"Saved to {args.output}")
