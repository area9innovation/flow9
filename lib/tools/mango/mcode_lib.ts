// TypeScript runtime library for Mango-generated parsers
// This is the TypeScript equivalent of mcode_lib.flow

export interface MoParseAcc {
    input: string;
    env: PEnv;
    i: number;
    stack: MCheckpoint[];
    starti: number;
    maxi: number;
    posStack: number[];
    errors: Map<number, string>;
}

export interface MCheckpoint {
    i: number;
    poppyStack: any[];
}

export interface PEnv {
    stack: any[];
}

// Create a new parser accumulator
export function createMoParseAcc(input: string): MoParseAcc {
    return {
        input,
        env: { stack: [] },
        i: 0,
        stack: [],
        starti: 0,
        maxi: 0,
        posStack: [],
        errors: new Map()
    };
}

// Optimized checkpoint functions when we do not need the stack
export function pushMCheckpointNoStack(acc: MoParseAcc): void {
    acc.posStack.push(acc.i);
}

export function discardMCheckpointNoStack(acc: MoParseAcc): boolean {
    acc.posStack.pop();
    return true;
}

export function restoreMCheckpointNoStack(acc: MoParseAcc): boolean {
    const pos = acc.posStack.pop();
    if (pos !== undefined) {
        acc.i = pos;
    }
    return false;
}

// Always use full stack checkpoints
export function pushMCheckpoint(acc: MoParseAcc): void {
    acc.stack.push({
        i: acc.i,
        poppyStack: [...acc.env.stack]
    });
}

export function discardMCheckpoint(acc: MoParseAcc): boolean {
    acc.stack.pop();
    return true;
}

export function restoreMCheckpoint(acc: MoParseAcc): boolean {
    const checkpoint = acc.stack.pop();
    if (checkpoint) {
        acc.i = checkpoint.i;
        acc.env.stack = checkpoint.poppyStack;
    }
    return false;
}

export function mparseStar(acc: MoParseAcc, matcher: () => boolean): boolean {
    pushMCheckpoint(acc);
    if (matcher()) {
        discardMCheckpoint(acc);
        return mparseStar(acc, matcher);
    } else {
        restoreMCheckpoint(acc);
        return true;
    }
}

// Optimized version of mparseStar for operations that don't modify the stack
// and don't need full backtracking. This is for simple patterns like character
// classes or simple string matches.
export function mparseStarNobacktrackOrStack(acc: MoParseAcc, matcher: () => boolean): boolean {
    function doMatch(): void {
        const startPos = acc.i;
        
        // Try to match
        if (matcher()) {
            // If match succeeds, continue recursively
            doMatch();
        } else {
            // If match fails, restore position and stop recursion
            acc.i = startPos;
        }
    }
    
    doMatch();
    return true;  // Star always succeeds
}

// Optimized version of mparseStar for operations that don't modify the stack
// but may need position backtracking.
export function mparseStarBacktrackOnly(acc: MoParseAcc, matcher: () => boolean): boolean {
    function doMatch(): void {
        const startPos = acc.i;
        
        // Try to match
        if (matcher()) {
            doMatch();
        } else {
            // If match fails, restore position and stop recursion
            acc.i = startPos;
        }
    }
    
    doMatch();
    return true;  // Star always succeeds
}

export function mmatchString(acc: MoParseAcc, s: string): boolean {
    if (acc.input.substr(acc.i, s.length) === s) {
        acc.i += s.length;
        if (acc.i > acc.maxi) {
            acc.maxi = acc.i;
        }
        return true;
    }
    return false;
}

export function mmatchRange(acc: MoParseAcc, l: number, u: number): boolean {
    if (acc.i < acc.input.length) {
        const code = acc.input.charCodeAt(acc.i);
        if (l <= code && code <= u) {
            acc.i += 1;
            if (acc.i > acc.maxi) {
                acc.maxi = acc.i;
            }
            return true;
        }
    }
    return false;
}

export function moconstruct(acc: MoParseAcc, uid: string, arity: number): boolean {
    const args: any[] = [];
    for (let i = 0; i < arity; i++) {
        args.unshift(popPEnv(acc.env));
    }
    
    const struct = makeStructValue(uid, args);
    if (struct !== null) {
        pushPEnv(acc.env, struct);
        return true;
    } else {
        console.error(`Could not construct ${uid} with args ${JSON.stringify(args)}`);
        return false;
    }
}

// Create a struct value with the conventional TypeScript "kind" object form
function makeStructValue(uid: string, args: any[]): any {
    const result: any = { kind: uid };
    
    // Use semantic field names based on common patterns
    if (args.length === 1) {
        // For single-argument structs, use "value" as the field name
        result.value = args[0];
    } else {
        // For multi-argument structs, use positional names for now
        args.forEach((arg, index) => {
            result[`arg${index}`] = arg;
        });
    }
    
    return result;
}

// PEnv (Poppy Environment) operations
export function pushPEnv(env: PEnv, value: any): boolean {
    env.stack.push(value);
    return true;
}

export function popPEnv(env: PEnv): any {
    return env.stack.pop();
}

export function getSinglePEnv(env: PEnv, defaultValue: any): any {
    if (env.stack.length === 1) {
        return env.stack[0];
    }
    return defaultValue;
}

// Get all values from the PEnv stack (for grammars that capture multiple values)
export function getAllPEnv(env: PEnv): any[] {
    return [...env.stack];
}

// Get result from PEnv - returns single value if there's one, array if multiple, or default if none
export function getResultPEnv(env: PEnv, defaultValue: any): any {
    if (env.stack.length === 0) {
        return defaultValue;
    } else if (env.stack.length === 1) {
        return env.stack[0];
    } else {
        return env.stack;
    }
}

// Driver to parse a compiled mango file
export function parseCompiledMango<T>(
    path: string, 
    content: string, 
    parseFn: (acc: MoParseAcc) => boolean, 
    defaultValue: T
): { result: T; error: string } {
    resetProfilingData();
    const macc = createMoParseAcc(content);
    const ok = parseFn(macc);

    if (Object.keys(profileMangoProductions).length > 0) {
        printProfilingResults(path, macc);
    }

    const value = getResultPEnv(macc.env, defaultValue);

    // If we failed the parse, or did not parse everything, create an error message
    if (!ok || macc.i < content.length || macc.errors.size > 0) {
        let errors = "";
        macc.errors.forEach((msg, pos) => {
            errors += getLinePos(path, content, msg, pos);
        });
        
        const errorMsg = errors || getLinePos(path, content, "Parse error", macc.maxi);
        return { result: value, error: errorMsg };
    } else {
        return { result: value, error: "" };
    }
}

// Global objects for profiling rule calls
let profileMangoProductions: { [key: string]: number } = {};
let profileMangoPositions: { [key: string]: { [key: number]: number } } = {};

// Reset profiling data
function resetProfilingData(): void {
    profileMangoProductions = {};
    profileMangoPositions = {};
}

export function profileMangoProduction(name: string): void {
    profileMangoProductions[name] = (profileMangoProductions[name] || 0) + 1;
}

export function profileMangoProductionWithPos(acc: MoParseAcc, name: string): void {
    profileMangoProduction(name);
    
    const pos = acc.i;
    
    if (!profileMangoPositions[name]) {
        profileMangoPositions[name] = {};
    }
    
    profileMangoPositions[name][pos] = (profileMangoPositions[name][pos] || 0) + 1;
}

// Utility functions
function getLinePos(path: string, content: string, message: string, pos: number): string {
    let line = 1;
    let col = 1;
    
    for (let i = 0; i < pos && i < content.length; i++) {
        if (content[i] === '\n') {
            line++;
            col = 1;
        } else {
            col++;
        }
    }
    
    return `${path}:${line}:${col}: ${message}\n`;
}

function getSourceFragment(source: string, pos: number, contextSize: number): string {
    const startPos = Math.max(0, pos - contextSize);
    const endPos = Math.min(source.length, pos + contextSize);
    
    const fragment = source.substring(startPos, endPos);
    const relativePos = pos - startPos;
    const indicator = " ".repeat(relativePos) + "^";
    
    return fragment + "\n" + indicator;
}

function printProfilingResults(path: string, macc: MoParseAcc): void {
    const prods = Object.entries(profileMangoProductions)
        .sort((a, b) => b[1] - a[1]);
    
    console.log("\nMango Grammar Profiling Results:\n");
    console.log("Rule Count   | Rule Name");
    console.log("------------+--------------------");
    
    prods.forEach(([rule, count]) => {
        const countStr = count.toString();
        const padding = " ".repeat(Math.max(0, 10 - countStr.length));
        console.log(padding + countStr + " | " + rule);
    });
    
    console.log("");
    
    // Print position histogram for top rules
    if (Object.keys(profileMangoPositions).length > 0) {
        console.log("\nTop Call Sites by Position:\n");
        
        Object.keys(profileMangoPositions).forEach(rule => {
            const posTree = profileMangoPositions[rule];
            
            if (Object.keys(posTree).length > 0) {
                console.log(`\nHotspots for rule '${rule}':`);
                
                const posCounts = Object.entries(posTree)
                    .map(([pos, count]) => ({ pos: parseInt(pos), count }))
                    .sort((a, b) => b.count - a.count)
                    .slice(0, 100);
                
                posCounts.forEach(({ pos, count }) => {
                    const contextStr = getSourceFragment(macc.input, pos, 25);
                    console.log(getLinePos(path, macc.input, `${count} calls`, pos));
                    console.log("");
                });
            }
        });
    }
}

// Poppy construct functions (matching Flow version)
export function pconstruct0(env: PEnv, uid: string): boolean {
    const struct = makeStructValue(uid, []);
    if (struct !== null) {
        pushPEnv(env, struct);
        return true;
    }
    return false;
}

export function pconstruct1(env: PEnv, uid: string): boolean {
    const arg = popPEnv(env);
    const struct = makeStructValue(uid, [arg]);
    if (struct !== null) {
        pushPEnv(env, struct);
        return true;
    }
    return false;
}

export function pconstruct2(env: PEnv, uid: string): boolean {
    const arg2 = popPEnv(env);
    const arg1 = popPEnv(env);
    const struct = makeStructValue(uid, [arg1, arg2]);
    if (struct !== null) {
        pushPEnv(env, struct);
        return true;
    }
    return false;
}

export function pconstruct3(env: PEnv, uid: string): boolean {
    const arg3 = popPEnv(env);
    const arg2 = popPEnv(env);
    const arg1 = popPEnv(env);
    const struct = makeStructValue(uid, [arg1, arg2, arg3]);
    if (struct !== null) {
        pushPEnv(env, struct);
        return true;
    }
    return false;
}

export function pconstruct4(env: PEnv, uid: string): boolean {
    const arg4 = popPEnv(env);
    const arg3 = popPEnv(env);
    const arg2 = popPEnv(env);
    const arg1 = popPEnv(env);
    const struct = makeStructValue(uid, [arg1, arg2, arg3, arg4]);
    if (struct !== null) {
        pushPEnv(env, struct);
        return true;
    }
    return false;
}

export function pconstruct5(env: PEnv, uid: string): boolean {
    const arg5 = popPEnv(env);
    const arg4 = popPEnv(env);
    const arg3 = popPEnv(env);
    const arg2 = popPEnv(env);
    const arg1 = popPEnv(env);
    const struct = makeStructValue(uid, [arg1, arg2, arg3, arg4, arg5]);
    if (struct !== null) {
        pushPEnv(env, struct);
        return true;
    }
    return false;
}

// String utility functions
export function unescapeString(s: string): string {
    return s.replace(/\\(.)/g, (match, char) => {
        switch (char) {
            case 'n': return '\n';
            case 't': return '\t';
            case 'r': return '\r';
            case '\\': return '\\';
            case '"': return '"';
            case "'": return "'";
            case 'u': 
                // Handle Unicode escapes like \u1234
                const unicode = s.substr(s.indexOf(match) + 2, 4);
                return String.fromCharCode(parseInt(unicode, 16));
            case 'x':
                // Handle hex escapes like \x41
                const hex = s.substr(s.indexOf(match) + 2, 2);
                return String.fromCharCode(parseInt(hex, 16));
            default: return char;
        }
    });
}