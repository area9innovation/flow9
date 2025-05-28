// TypeScript program that imports and uses the Flow exports
import { Flow, type Foo } from '../flow_export.js';

// Create some Foo instances using the TypeScript types
const foo1: Foo = Flow.createFoo(42);
const foo2: Foo = Flow.createFoo(100);
const foo3: Foo = Flow.createFoo(-5);

console.log('Initial state:');
let currentFoo = Flow.getFoo();
console.log('Current foo:', currentFoo);

console.log('\nAdding foos:');
Flow.addFoo(foo1);
console.log('Added foo1:', foo1);

Flow.addFoo(foo2);
console.log('Added foo2:', foo2);

Flow.addFoo(foo3);
console.log('Added foo3:', foo3);

console.log('\nFinal state:');
currentFoo = Flow.getFoo();
console.log('Current foo after additions:', currentFoo);

// Demonstrate type safety
console.log('\nDemonstrating TypeScript type safety:');

// This would cause a TypeScript error if uncommented:
// const invalidFoo: Foo = { b: "wrong" }; // Error: Object literal may only specify known properties

// This works because we're following the Foo interface
const validFoo: Foo = Flow.createFoo(999);
Flow.addFoo(validFoo);
console.log('Added valid foo:', validFoo);

// Show final result
const finalFoo = Flow.getFoo();
console.log('Final foo:', finalFoo);

// Export some functionality for potential use by other modules
export function createAndAddFoo(value: number): Foo {
    const newFoo: Foo = Flow.createFoo(value);
    Flow.addFoo(newFoo);
    return newFoo;
}

export function getCurrentFooValue(): number {
    const currentFoo = Flow.getFoo();
    return currentFoo.a;
}
