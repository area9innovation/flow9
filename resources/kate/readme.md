
Using Kate editor with flow
---------------------------

DO THESE STEPS:

- Follow the instructions from https://kate-editor.org/build-it/ to clone and build local 
  kate distribution.
- Copy flow/symbolviewer plugin sources (directory flow) to kate/addons/ 
- Add information about flow plugin to kate/addons/CMakeLists.txt (following lines):
	# flow language IDE
	ecm_optional_add_subdirectory (flow)
- Build Kate
- Run Kate and switch on the flow plugin.
- Setup flow directory in the flow config/Compiler tab in UI

Available functions
-------------------

Now flow plugin for Kate is able to:
1. Compile flow files using info from flow.config 
2. Lookup symbol definition
3. Lookup types of expressions/variables
4. Rename identifiers (local and global)
5. Launch programs with user-defined argument list
6. Debug programs with user-defined argument list
