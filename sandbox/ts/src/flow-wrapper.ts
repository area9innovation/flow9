// Wrapper to import the Flow JavaScript with TypeScript types
// This file bridges the generated Flow JS with TypeScript

// Import the Flow namespace from the ES6 module
import { Flow } from '../flow_export.js';

// Re-export with proper TypeScript types
import type { Foo } from '../types';

export const addFoo: (f: Foo) => void = Flow.addFoo;
export const getFoo: () => Foo = Flow.getFoo;

// Type constructor for Foo (since Flow structs become plain objects in JS)
export function createFoo(a: number): Foo {
    return { a };
}

export type { Foo };