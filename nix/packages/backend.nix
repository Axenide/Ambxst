# Ambxst Go backend binary
{ pkgs, lib, version }:

let
  src = lib.cleanSource ../../backend;
in
pkgs.buildGoModule {
  pname = "ambxst-backend";
  inherit version;

  inherit src;

  # Vendored deps committed in-tree (go mod vendor)
  vendorHash = null;

  subPackages = [ "cmd/ambxst" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = {
    description = "Ambxst backend daemon and CLI";
    mainProgram = "ambxst";
  };
}
