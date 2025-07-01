# Pseudo Flow

This is an example grammar that was written on a live stream
to demonstrate how Gringo works.

It parses a subset of Flow grammar to a strongly typed AST.

Run

	flowcpp tools/gringo/pflow/pflow.flow

# Videos

Check out the video here where the parser is written:

https://youtu.be/ZnIlsZbY4JY

In a second video, the interpreter is implemented:

https://youtu.be/L4l7RHsmjnQ

In the third vide, the type inference is implemented:
https://youtu.be/FYpjNMgcRZg

There was a bug in that live stream, which was not solved. This 
was fixed by changing from the union-find data structure to the 
union-find-map data structure, which can make sure associated data 
is also joined transitively.
