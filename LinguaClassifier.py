"""
LinguaClassifier — Multi-layered Classification of Lean Identifiers
Layer 1: Lexical (token) → Layer 2: Morphology → Layer 3: POS → Layer 4: Semantics
"""
import json
from collections import defaultdict
from typing import List, Dict, Optional
from pathlib import Path

class MorphologicalAnalyzer:
    """Layer 2: Morphological analysis of identifiers."""
    def __init__(self):
        self.prefix_patterns = [("Is","IS"),("Has","HAS"),("Of","OF"),("To","TO"),
                                ("Coerce","COERCE"),("From","FROM"),("With","WITH"),
                                ("No","NO"),("Non","NON"),("Un","UN"),("Re","RE")]
        self.suffix_patterns = [("_iff","IFF"),("_eq","EQ"),("_ne","NE"),
                                ("_of","OF"),("_le","LE"),("_lt","LT"),
                                ("_ge","GE"),("_gt","GT"),("_like","LIKE"),
                                ("_esque","ESQUE"),("_ish","ISH")]
    def analyze(self, identifier: str) -> Dict:
        detected_prefixes = []
        body = identifier
        for prefix, name in self.prefix_patterns:
            if identifier.startswith(prefix):
                detected_prefixes.append(name)
                body = identifier[len(prefix):]
                break
        detected_suffixes = []
        for suffix, name in self.suffix_patterns:
            if identifier.endswith(suffix):
                detected_suffixes.append(name)
                body = identifier[:-len(suffix)]
                break
        camel_parts = self._split_camel_case(identifier)
        underscore_parts = identifier.split('_') if '_' in identifier else []
        return {
            'identifier': identifier,
            'body': body,
            'prefixes': detected_prefixes,
            'suffixes': detected_suffixes,
            'camel_parts': camel_parts,
            'underscore_parts': underscore_parts,
            'is_decomposed': len(detected_prefixes) > 0 or len(detected_suffixes) > 0,
            'part_count': max(len(camel_parts), len(underscore_parts))
        }
    def _split_camel_case(self, s: str) -> List[str]:
        parts = []
        current = []
        for char in s:
            if char.isupper():
                if current:
                    parts.append(''.join(current))
                    current = []
                current.append(char)
            else:
                current.append(char)
        if current:
            parts.append(''.join(current))
        return parts

class PartOfSpeechClassifier:
    """Layer 3: Part of Speech classification."""
    determinatives = ["True", "False", "Empty", "Unit", "Prop", "Type", "Sort"]
    numerals = ["Nat", "Int", "Rat", "Real", "Complex", "Fin", "Ne", "NonEmpty"]
    connectives = {"and", "or", "xor", "iff", "not", "imp"}
    quantifiers = {"forall", "exists", "existsUnique", "Forall", "Exists"}
    operators = {"add", "mul", "sub", "div", "pow", "neg", "abs", "sqrt", "log",
                 "exp", "coe", "to", "from", "by", "eq", "le", "lt", "ge", "gt",
                 "ne", "map", "flatMap", "foldl", "foldr", "traverse"}
    adverbs = {"classically", "constructively", "strictly", "uniformly", "locally",
               "continuously", "almost", "everywhere", "sometimes"}
    prepositions = {"within", "at", "on", "over", "under", "from", "to", "into",
                    "onto", "beyond", "inside", "outside", "between"}
    tactics = {"intro", "apply", "rw", "simp", "cases", "induction", "refine", "calc",
               "exact", "assumption", "contradiction", "clear", "rename", "generalize",
               "replace", "conv", "dsimp", "aesop", "omega", "linarith", "ring",
               "field_simp", "norm_cast", "norm_fin", "norm_num", "norm_simp", "simpa",
               "finish", "tauto", "nlinarith", "abnormal", "sorry", "admit",
               "by_contra", "by_cases", "by_refine"}
    attributes = {"simp", "norm_num", "reducible", "irreducible", "unsafe", "synthetic",
                  "noinferable"}
    keywords = {"def", "theorem", "lemma", "example", "axiom", "structure", "class",
                "instance", "inductive", "coinductive", "namespace", "import", "open",
                "section", "variable", "attribute", "include", "local", "end", "where",
                "ext", "begin"}
    constructors = {"left", "right", "top", "bottom", "head", "tail", "first", "second",
                    "third", "fourth"}
    def classify(self, identifier: str, morphological: Dict = None) -> str:
        s = identifier.lower()
        if identifier in self.determinatives:
            return "Determiner"
        if identifier in self.numerals:
            return "Numeral"
        if s in self.connectives:
            return "Conjunction"
        if identifier in self.quantifiers:
            return "Quantifier"
        if s in self.operators:
            return "Verb"
        if s in self.adverbs:
            return "Adverb"
        if s in self.prepositions:
            return "Preposition"
        if s in self.tactics:
            return "Tactic"
        if s in self.attributes:
            return "Attribute"
        if s in self.keywords:
            return "Keyword"
        if s in self.constructors:
            return "Constructor"
        if identifier.startswith("Is") or identifier.startswith("Has") \
                or identifier.startswith("Exists"):
            return "Adjective"
        if identifier and identifier[0].isupper():
            return "Noun"
        return "Verb"

class SemanticCategoryClassifier:
    """Layer 4: Semantic category classification."""
    def __init__(self):
        self.categories = {
            "Arithmetic": ["add","mul","sub","div","pow","neg","abs","sqrt","log","exp",
                           "zpow","one","zero","nat","int","rat","real","complex",
                           "floor","ceil"],
            "Logic": ["and","or","xor","iff","not","implies"],
            "Algebra": ["group","ring","field","module","vector","algebra","monoid",
                        "semigroup","magma","abelian","lattice","ideal","subgroup",
                        "submodule","subring"],
            "Analysis": ["measure","integral","limit","converge","sequence","deriv",
                         "differentiable","continuously","continuous","smooth",
                         "analytic","derivative","gradient","hessian"],
            "CategoryTheory": ["functor","monad","applicative","category","morphism",
                               "natural","tangent","cotangent","bundle","sheaf",
                               "presheaf","site","topos"],
            "DataStructures": ["list","array","tree","graph","map","set","vector",
                               "matrix","tuple","prod","sum","option","stream","multiset",
                               "finset","finsupp","hashmap"],
            "TypeTheory": ["type","sort","universe","eq","heq","coerce","subtype",
                           "quotient","inductive","coinductive","structure","record",
                           "class","instance","typeclass"],
            "Topology": ["topo","space","open","closed","compact","connected","hausdorff",
                         "regular","normal","metric","metric_space","topological","homeo",
                         "homeomorphism","embedding","fiber"],
            "Combinatorics": ["perm","comb","partition","graph","color","matching",
                              "euler","hamiltonian","clique","independent_set",
                              "vertex_cover","dominating_set"],
            "NumberTheory": ["prime","factor","divisible","mod","gcd","lcm","euler_phi",
                             "totient","fermat","chinese_remainder","primitive_root",
                             "quadratic_residue","legendre_symbol"],
            "Computation": ["compute","eval","exec","run","execute","turing","machine",
                            "automaton","decidable","undecidable","complexity","np","p",
                            "pspace","logspace"],
            "SystemStack": ["nix","linux","llvm","gcc","tinyc","compcert","mojo"],
            "LanguageMeta": ["elixir","nodejs","python","rust","r"],
            "FileSystem": ["ipfs","wasm","file","drop","web","server"],
            "Hypertext": ["html","web","http","url","link","page"],
            "ZeroKnowledge": ["zk","zkp","proof","zero","knowledge","solana","bpf"],
            "AristotleSpecific": ["aristotle","godel","quine","maxim","residue"]
        }
        # Build reverse lookup
        self.reverse_lookup = {}
        for cat, terms in self.categories.items():
            for term in terms:
                self.reverse_lookup[term.lower()] = cat
    def classify(self, identifier: str) -> str:
        s = identifier.lower()
        if s in self.reverse_lookup:
            return self.reverse_lookup[s]
        # Fallback: substring match
        for term, cat in self.reverse_lookup.items():
            if len(term) > 3 and term in s:
                return cat
        return "Misc"

class FeedbackSystem:
    """Layer 6b: Feedback loop system."""
    def __init__(self):
        self.feedback_items: List[Dict] = []
        self.classification_weights: Dict[tuple, int] = defaultdict(int)
        self.stats: Dict[str, List[int]] = defaultdict(lambda: [0, 0])
    def record_feedback(self, token, original_pos, corrected_pos,
                        result="accept", comment=""):
        self.feedback_items.append({
            'token': token, 'original_pos': original_pos,
            'corrected_pos': corrected_pos, 'result': result, 'comment': comment
        })
        accept, reject = self.stats[token]
        if result == "accept":
            self.stats[token][0] = accept + 1
        else:
            self.stats[token][1] = reject + 1
        total = accept + reject + 1
        if total > 5:
            accuracy = self.stats[token][0] / total
            weight = int(10 * accuracy) if accuracy > 0.8 else int(5 * accuracy)
            self.classification_weights[(token, original_pos)] = weight
    def get_weight(self, token, original_pos):
        return self.classification_weights.get((token, original_pos), 5)
    def accuracy_rate(self, token):
        accept, reject = self.stats[token]
        total = accept + reject
        if total == 0:
            return 0.5
        return accept / total
    def override_classification(self, token, original_pos):
        if self.accuracy_rate(token) > 0.7:
            for item in self.feedback_items:
                if item['token'] == token:
                    return item['corrected_pos']
        return original_pos

class ClassificationEngine:
    """Main classification engine combining all layers."""
    def __init__(self):
        self.morph = MorphologicalAnalyzer()
        self.pos = PartOfSpeechClassifier()
        self.sem = SemanticCategoryClassifier()
        self.feedback = FeedbackSystem()
    def classify(self, identifier: str) -> Dict:
        morph = self.morph.analyze(identifier)
        pos = self.pos.classify(identifier, morph)
        pos = self.feedback.override_classification(identifier, pos)
        sem = self.sem.classify(identifier)
        return {
            'identifier': identifier,
            'morphology': morph,
            'pos': pos,
            'semantics': sem,
            'layer2_decomposed': morph['is_decomposed'],
            'layer2_parts': morph['part_count']
        }
    def classify_batch(self, identifiers: List[str]) -> List[Dict]:
        return [self.classify(i) for i in identifiers]
    def report(self, analyses: List[Dict]) -> str:
        pos_counts: Dict[str, int] = defaultdict(int)
        sem_counts: Dict[str, int] = defaultdict(int)
        for a in analyses:
            pos_counts[a['pos']] += 1
            sem_counts[a['semantics']] += 1
        total = len(analyses)
        lines = []
        lines.append("=" * 70)
        lines.append("LINGUALEAN MULTI-LAYERED CLASSIFICATION REPORT")
        lines.append("=" * 70)
        lines.append(f"Total identifiers: {total}")
        lines.append("")
        lines.append("- Part of Speech Distribution (Layer 3)")
        lines.append("-" * 70)
        for pos, count in sorted(pos_counts.items()):
            pct = count / total * 100
            lines.append(f"  {pos:25} {count:5}  ({pct:6.2f}%)")
        lines.append("")
        lines.append("- Semantic Category Distribution (Layer 4)")
        lines.append("-" * 70)
        for sem, count in sorted(sem_counts.items()):
            pct = count / total * 100
            lines.append(f"  {sem:25} {count:5}  ({pct:6.2f}%)")
        lines.append("")
        lines.append("- Morphology Statistics (Layer 2)")
        lines.append("-" * 70)
        decomposed = sum(1 for a in analyses if a['layer2_decomposed'])
        lines.append(f"  Decomposed identifiers: {decomposed} "
                     f"({decomposed/total*100:.1f}%)")
        lines.append("")
        return "\n".join(lines)

def load_signatures(path: str) -> List[str]:
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list):
        return [s for s in data if isinstance(s, str)]
    elif isinstance(data, dict):
        for key in ('symbols', 'identifiers', 'terms', 'signatures', 'results'):
            if key in data and isinstance(data[key], list):
                return [s for s in data[key] if isinstance(s, str)]
        values = []
        def collect(v):
            if isinstance(v, list):
                for item in v:
                    if isinstance(item, str):
                        values.append(item)
                    elif isinstance(item, dict):
                        collect(list(item.values()))
        collect(data)
        return values
    return []

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="LinguaLean multi-layered classifier")
    parser.add_argument("input", help="Input file with signatures (JSON or text)")
    parser.add_argument("--output", "-o", help="Output report file")
    parser.add_argument("--limit", "-n", type=int, default=None,
                        help="Limit number of identifiers")
    args = parser.parse_args()
    sigs = load_signatures(args.input)
    if args.limit:
        sigs = sigs[:args.limit]
    engine = ClassificationEngine()
    analyses = engine.classify_batch(sigs)
    report = engine.report(analyses)
    print(report)
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"Report saved to {args.output}")
