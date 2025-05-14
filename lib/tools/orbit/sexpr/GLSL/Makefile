# Compiler and Linker
CXX = g++
GLSLC = glslc

# Compiler and Linker Flags
CXXFLAGS = -std=c++17 -Wall -Wextra
# Use pkg-config to get Vulkan flags and libraries
# Ensure VULKAN_SDK environment variable is set if not installing to system paths
# and PKG_CONFIG_PATH includes $VULKAN_SDK/lib/pkgconfig
VK_CFLAGS := $(shell pkg-config --cflags vulkan)
VK_LIBS := $(shell pkg-config --static --libs vulkan)

# Add Vulkan CFLAGS and LIBS to compiler/linker flags
CXXFLAGS += $(VK_CFLAGS)
LDFLAGS = $(VK_LIBS) -lpthread # Vulkan often needs pthread

# Source Files and Targets
GLSL_SHADER = interpreter.glsl
SPIRV_SHADER = $(GLSL_SHADER:.glsl=.spv)
HOST_SRC = host.cpp
HOST_TARGET = sexpr_vulkan_host

# Default target
all: build

# Compile GLSL to SPIR-V
$(SPIRV_SHADER): $(GLSL_SHADER)
	$(GLSLC) -fshader-stage=compute $(GLSL_SHADER) -o $(SPIRV_SHADER)
	@echo "Compiled $(GLSL_SHADER) to $(SPIRV_SHADER)"

# Compile C++ host application
$(HOST_TARGET): $(HOST_SRC) $(SPIRV_SHADER)
	$(CXX) $(CXXFLAGS) $(HOST_SRC) -o $(HOST_TARGET) $(LDFLAGS)
	@echo "Compiled $(HOST_SRC) to $(HOST_TARGET)"

# Build all
build: $(HOST_TARGET)

# Run the host application
run: $(HOST_TARGET)
	@echo "Running $(HOST_TARGET)..."
	./$(HOST_TARGET)

# Clean up build artifacts
clean:
	rm -f $(HOST_TARGET) $(SPIRV_SHADER)
	@echo "Cleaned build artifacts."

.PHONY: all build run clean
