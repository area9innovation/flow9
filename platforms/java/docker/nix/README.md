# Flow Java Docker Image with Nix

This directory contains Nix configurations to build a Docker image equivalent to the one defined in the parent directory's Dockerfile.

## Prerequisites

- Nix package manager installed (https://nixos.org/download.html)
- Docker (if you want to run the image)

## Building the Docker Image

1. Enter a Nix shell (optional, but provides required tools):
   ```bash
	 nix-shell
```

2. Build the Docker image:
   ```bash
	 nix-build
```
   This will create a `result` file that is the Docker image.

3. Load the Docker image:
   ```bash
	 docker load < result
```

4. Verify the image is loaded:
   ```bash
	 docker images
```
   You should see an entry for `flow-java:latest`.

## Using the Docker Image

Run the image with a JAR file:

```bash
docker run -e JAR=filename.jar -v /path/to/jar/dir:/app flow-java:latest
```

You can also set memory parameters:

```bash
docker run -e JAR=filename.jar -e JAVA_XMX=4096m -e JAVA_XSS=256m -v /path/to/jar/dir:/app flow-java:latest
```

Environment variables prefixed with `flow_` will be passed to the JAR file.

## Differences from the Original Dockerfile

- The Nix version builds the image in a single layer, which is more efficient
- It uses the same scripts and configuration as the original Docker image
- OpenJDK version may differ slightly depending on your Nixpkgs version