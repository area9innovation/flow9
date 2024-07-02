import * as MT from './mango_types.ts';

interface MEnv<T> {
	// The string we are parsing
    input: string;
	// The rules
    names: Map<string, MT.Term>;
	// The result stack used for semantic actions
    result: T[];
	// The position in the input
    i: number;
	// Did parsing fail?
    fail: boolean;
	// What is the longest we have parsed?
    maxi: number;
	// What errors did we get?
    errors: Map<number, string>;
	// How to construct a value						
    construct: (name: string, args: T[]) => T;
}

// Function to parse Mango grammar
export function parseMango<T>(grammar: MT.Term, input: string, construct: (name: string, args: T[]) => T): MEnv<T> {
    const env: MEnv<T> = {
        input: input,
        names: new Map<string, MT.Term>(),
        result: [],
        i: 0,
        fail: false,
        maxi: 0,
        errors: new Map<number, string>(),
        construct: construct
    };
    return parse(env, grammar);
}

// parse function, using generic type parameter
function parse<T>(env: MEnv<T>, t: MT.Term): MEnv<T> {
    switch (t.kind) {
        case MT.TermType.Token: {
			const tokenTerm = t as MT.Token; // Type assertion
			const token = tokenTerm.token;

			if (token === "") {
				return env;
			} else {
				let text: string;

				// Handle special characters
				switch (token) {
					case "\\n": text = "\n"; break;
					case "\\r": text = "\r"; break;
					case "\\t": text = "\t"; break;
					default: text = token; break;
				}

				// Check if the text is at the current position in the input
				if (strContainsAt(env.input, env.i, text)) {
					const ni = env.i + text.length;
					return {
						...env,
						i: ni,
						maxi: Math.max(env.maxi, ni)
					};
				} else {
					return { ...env, fail: true };
				}
			}
		}
		default: return env;
	}
}

// Helper function to check if a string contains a substring at a specific position
function strContainsAt(input: string, index: number, searchString: string): boolean {
    return input.substring(index, index + searchString.length) === searchString;
}
