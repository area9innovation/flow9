{ pkgs ? import <nixpkgs> {} }:

let
  entrypoint = pkgs.writeScriptBin "entrypoint" (builtins.readFile ../entrypoint.sh);
  passthrough = pkgs.writeScriptBin "passthrough" (builtins.readFile ../passthrough.sh);
in

pkgs.dockerTools.buildImage {
  name = "flow-java";
  tag = "latest";
  
  # Set a recent timestamp instead of the default (1970-01-01)
  created = "now";

  # Create a non-root user
  extraCommands = ''
    mkdir -p ./usr/local/bin
    mkdir -p ./app
    mkdir -p ./etc
    mkdir -p ./tmp

    # Create user app with UID 1000
    echo "app:x:1000:1000:app:/home/app:/bin/bash" >> ./etc/passwd
    echo "app:x:1000:" >> ./etc/group
    
    # Copy scripts
    cp ${entrypoint}/bin/entrypoint ./usr/local/bin/
    cp ${passthrough}/bin/passthrough ./usr/local/bin/
  '';

  # These environment variables can be overridden when running the container
  config = {
    Cmd = ["entrypoint"];
    Entrypoint = ["passthrough"];
    User = "app";
    WorkingDir = "/app";
  };

  # Create a layer with Java and required tools
  contents = with pkgs; [
    # Use OpenJDK 18 or the closest available version
    jdk
    bash
    coreutils
    gnugrep    # Add grep
    gnused     # Add sed
    curl
    procps
  ];
}