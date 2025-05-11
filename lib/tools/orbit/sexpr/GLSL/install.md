# Installation Guide for GLSL/Vulkan S-Expression Interpreter on WSL2 (Ubuntu)

This guide explains how to set up your WSL2 Ubuntu environment to compile GLSL shaders to SPIR-V and run them using a Vulkan host application.

## Prerequisites

1.  **WSL2 Installed and Configured:** Ensure you have WSL2 running with an Ubuntu distribution.
2.  **GPU Drivers on Windows Host:** You need up-to-date graphics drivers installed on your Windows host system that support Vulkan and WSL2 GPU passthrough.
    *   **NVIDIA:** Install the latest GeForce Game Ready or NVIDIA RTX Enterprise drivers that support WSL.
    *   **AMD:** Install the latest Adrenalin drivers that support WSL.
    *   **Intel:** Install the latest graphics drivers that support WSL.
    You typically need a fairly recent Windows 10/11 build as well.

## Installation Steps

### 1. Update Ubuntu Packages

Open your WSL2 Ubuntu terminal and update your package lists:

```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install Build Essentials and Git

```bash
sudo apt install -y build-essential make cmake git pkg-config
```

### 3. Install Vulkan SDK

The Vulkan SDK provides the Vulkan headers, loader, validation layers, and crucial tools like `glslc` (GLSL to SPIR-V compiler).

It's recommended to download the SDK from the official LunarG website for the latest version, but you can also often find it in package repositories.

[Vulkan SDK download page](https://vulkan.lunarg.com/sdk/home).

### 4. Verify `glslc` Installation

After installing the Vulkan SDK or `glslc` separately, verify it's working:

```bash
glslc --version
```

This should print the version of the `glslc` compiler.

### 5. Verify Vulkan Installation (Optional but Recommended)

You can verify that Vulkan is accessible from within WSL2:

```bash
vulkaninfo
```

If this command runs successfully and shows information about your GPU, Vulkan is likely set up correctly for WSL2. If it fails, you may need to troubleshoot your Windows GPU drivers, WSL2 version, or Linux Mesa drivers (though for NVIDIA/AMD direct passthrough, Mesa might not be the primary component for Vulkan itself but can be for GL).

Ensure your WSL2 kernel is up-to-date: `wsl --update` from PowerShell.

## Compiling and Running

Once these dependencies are installed, you should be able to use the provided `Makefile` to:
1.  Compile GLSL shaders to SPIR-V using `glslc`.
2.  Compile a C++ host application using `g++` (or `clang++`) linked against Vulkan libraries.
3.  Run the host application.

For C++ compilation, the `Makefile` will typically use `pkg-config` to find Vulkan libraries:
```makefile
VK_LIBS=$(shell pkg-config --static --libs vulkan)
VK_CFLAGS=$(shell pkg-config --cflags vulkan)
```
Ensure `pkg-config` is installed and can find `vulkan.pc`. If not, you might need to set `PKG_CONFIG_PATH` if the Vulkan SDK didn't install its `.pc` file to a standard location.
For the LunarG SDK, `vulkan.pc` is usually in `$VULKAN_SDK/lib/pkgconfig/`. You might need:
```bash
echo 'export PKG_CONFIG_PATH=$VULKAN_SDK/lib/pkgconfig:$PKG_CONFIG_PATH' >> ~/.bashrc
source ~/.bashrc
```

You are now ready to proceed with compiling and running the GLSL interpreter.
