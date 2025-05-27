// TypeScript program that imports and uses the Flow exports
import { Foo, addFoo, getFoo, createFoo } from './flow-wrapper';

// Create some Foo instances using the TypeScript types
const foo1: Foo = createFoo(42);
const foo2: Foo = createFoo(100);
const foo3: Foo = createFoo(-5);

console.log('Initial state:');
let currentFoo = getFoo();
console.log('Current foo:', currentFoo);

console.log('\nAdding foos:');
addFoo(foo1);
console.log('Added foo1:', foo1);

addFoo(foo2);
console.log('Added foo2:', foo2);

addFoo(foo3);
console.log('Added foo3:', foo3);

console.log('\nFinal state:');
currentFoo = getFoo();
console.log('Current foo after additions:', currentFoo);

// Demonstrate type safety
console.log('\nDemonstrating TypeScript type safety:');

// This would cause a TypeScript error if uncommented:
// const invalidFoo: Foo = { b: "wrong" }; // Error: Object literal may only specify known properties

// This works because we're following the Foo interface
const validFoo: Foo = createFoo(999);
addFoo(validFoo);
console.log('Added valid foo:', validFoo);

// Show final result
const finalFoo = getFoo();
console.log('Final foo:', finalFoo);

// Export some functionality for potential use by other modules
export function createAndAddFoo(value: number): Foo {
    const newFoo: Foo = createFoo(value);
    addFoo(newFoo);
    return newFoo;
}

export function getCurrentFooValue(): number {
    const currentFoo = getFoo();
    return currentFoo.a;
}

export { Foo, addFoo, getFoo, createFoo };