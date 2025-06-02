// TypeScript program that imports and uses the Flow exports
import { Flow, type Foo, type Shape, type Result, type Circle, type Rectangle, type Triangle } from '../flow_export.js';

console.log('=== Testing Foo struct ===');
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

console.log('\n=== Testing Shape union ===');
// Create different shape instances
const circle: Circle = Flow.createCircle(5.0);
const rectangle: Rectangle = Flow.createRectangle(10.0, 8.0);
const triangle: Triangle = Flow.createTriangle(6.0, 4.0);

console.log('Created shapes:');
console.log('Circle:', circle, 'kind:', circle.kind);
console.log('Rectangle:', rectangle, 'kind:', rectangle.kind);
console.log('Triangle:', triangle, 'kind:', triangle.kind);

// Test shape functions with union types
const shapes: Shape[] = [circle, rectangle, triangle];

console.log('\nTesting shape calculations:');
for (const shape of shapes) {
    const area = Flow.calculateArea(shape);
    const type = Flow.getShapeType(shape);
    console.log(`${type}: area = ${area}`);
}

// Test default shapes
console.log('\nDefault shapes:');
const defaultShapes = Flow.createDefaultShapes();
for (const shape of defaultShapes) {
    const area = Flow.calculateArea(shape);
    const type = Flow.getShapeType(shape);
    console.log(`Default ${type}: area = ${area}, kind = ${shape.kind}`);
}

console.log('\n=== Testing Result union ===');
// Test Result union with generic types
const successResult: Result<number> = Flow.createSuccessResult(42);
const errorResult: Result<number> = Flow.createErrorResult("Something went wrong");

console.log('Created results:');
console.log('Success result:', successResult, 'kind:', successResult.kind);
console.log('Error result:', errorResult, 'kind:', errorResult.kind);

// Test result handling
console.log('\nTesting result handling:');
const successMessage = Flow.handleResult(successResult);
const errorMessage = Flow.handleResult(errorResult);

console.log('Success message:', successMessage);
console.log('Error message:', errorMessage);

console.log('\n=== Demonstrating TypeScript type safety ===');

// This would cause a TypeScript error if uncommented:
// const invalidFoo: Foo = { b: "wrong" }; // Error: Object literal may only specify known properties

// This works because we're following the Foo interface
const validFoo: Foo = Flow.createFoo(999);
Flow.addFoo(validFoo);
console.log('Added valid foo:', validFoo);

// Demonstrate union type safety
function processShape(shape: Shape): string {
    // TypeScript knows shape can be Circle | Rectangle | Triangle
    const area = Flow.calculateArea(shape);
    const type = Flow.getShapeType(shape);
    
    // We can access the kind discriminant field
    return `Processed ${type} (kind: ${shape.kind}) with area ${area}`;
}

console.log('\nProcessing shapes with type safety:');
console.log(processShape(circle));
console.log(processShape(rectangle));
console.log(processShape(triangle));

// Show final result
const finalFoo = Flow.getFoo();
console.log('\nFinal foo:', finalFoo);

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

export function createShapeOfType(type: 'circle' | 'rectangle' | 'triangle'): Shape {
    switch (type) {
        case 'circle':
            return Flow.createCircle(3.0);
        case 'rectangle':
            return Flow.createRectangle(4.0, 5.0);
        case 'triangle':
            return Flow.createTriangle(3.0, 4.0);
    }
}

export function calculateTotalArea(shapes: Shape[]): number {
    return shapes.reduce((total, shape) => total + Flow.calculateArea(shape), 0);
}
