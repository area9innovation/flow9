// Enum for node types
export enum TermType {
    Choice,
    Construct,
    Error,
    GrammarMacro,
    Lower,
    Negate,
    Optional,
    Plus,
    Precedence,
    PushMatch,
    Range,
    Rule,
    Sequence,
    StackOp,
    Star,
    Token,
    Variable
}

// Interfaces for each node type
export interface Choice {
    kind: TermType.Choice;
    term1: Term;
    term2: Term;
}
export function Choice(term1: Term, term2: Term): Choice {
    return { kind: TermType.Choice, term1, term2 };
}

export interface Construct {
    kind: TermType.Construct;
    uid: string;
    int1: string;
}
export function Construct(uid: string, int1: string): Construct {
    return { kind: TermType.Construct, uid, int1 };
}

export interface Error {
    kind: TermType.Error;
    term: Term;
}
export function Error(term: Term): Error {
    return { kind: TermType.Error, term };
}

export interface GrammarMacro {
    kind: TermType.GrammarMacro;
    id: string;
    term: Term;
}
export function GrammarMacro(id: string, term: Term): GrammarMacro {
    return { kind: TermType.GrammarMacro, id, term };
}

export interface Lower {
    kind: TermType.Lower;
    term: Term;
}
export function Lower(term: Term): Lower {
    return { kind: TermType.Lower, term };
}

export interface Negate {
    kind: TermType.Negate;
    term: Term;
}
export function Negate(term: Term): Negate {
    return { kind: TermType.Negate, term };
}

export interface Optional {
    kind: TermType.Optional;
    term: Term;
}
export function Optional(term: Term): Optional {
    return { kind: TermType.Optional, term };
}

export interface Plus {
    kind: TermType.Plus;
    term: Term;
}
export function Plus(term: Term): Plus {
    return { kind: TermType.Plus, term };
}

export interface Precedence {
    kind: TermType.Precedence;
    term1: Term;
    term2: Term;
}
export function Precedence(term1: Term, term2: Term): Precedence {
    return { kind: TermType.Precedence, term1, term2 };
}

export interface PushMatch {
    kind: TermType.PushMatch;
    term: Term;
}
export function PushMatch(term: Term): PushMatch {
    return { kind: TermType.PushMatch, term };
}

export interface Range {
    kind: TermType.Range;
    char1: string;
    char2: string;
}
export function Range(char1: string, char2: string): Range {
    return { kind: TermType.Range, char1, char2 };
}

export interface Rule {
    kind: TermType.Rule;
    id: string;
    term1: Term;
    term2: Term;
}
export function Rule(id: string, term1: Term, term2: Term): Rule {
    return { kind: TermType.Rule, id, term1, term2 };
}

export interface Sequence {
    kind: TermType.Sequence;
    term1: Term;
    term2: Term;
}
export function Sequence(term1: Term, term2: Term): Sequence {
    return { kind: TermType.Sequence, term1, term2 };
}

export interface StackOp {
    kind: TermType.StackOp;
    id: string;
}
export function StackOp(id: string): StackOp {
    return { kind: TermType.StackOp, id };
}

export interface Star {
    kind: TermType.Star;
    term: Term;
}
export function Star(term: Term): Star {
    return { kind: TermType.Star, term };
}

export interface Token {
    kind: TermType.Token;
    token: string;
}
export function Token(token: string): Token {
    return { kind: TermType.Token, token };
}

export interface Variable {
    kind: TermType.Variable;
    id: string;
}
export function Variable(id: string): Variable {
    return { kind: TermType.Variable, id };
}

// Union type for any term
export type Term = Choice | Construct | Error | GrammarMacro | Lower | Negate | Optional | Plus | Precedence | PushMatch | Range | Rule | Sequence | StackOp | Star | Token | Variable;
