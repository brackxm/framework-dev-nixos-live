{ pkgs }:
let
  # Official Node 24.22.1 Linux x64 binary, verified SHA-256.
  node = pkgs.stdenv.mkDerivation {
    pname = "nodejs";
    version = "24.22.1";
    src = pkgs.fetchurl {
      url = "https://nodejs.org/dist/v24.22.1/node-v24.22.1-linux-x64.tar.xz";
      hash = "sha256-bBcqmrZxj3uAH7WnvUhq8u5eMnWAhqBLhPzOKqdwleY=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r bin include lib share "$out/"
      runHook postInstall
    '';
    meta = {
      description = "Official Node.js 24.22.1 Linux x64 distribution";
      platforms = [ "x86_64-linux" ];
      license = pkgs.lib.licenses.mit;
    };
  };

  # Nixpkgs's pnpm derivation with the pinned 11.25.0 npm tarball hash.
  pnpm = pkgs.pnpm_11.override {
    version = "11.25.0";
    hash = "sha512-XN6SW08HX3Jetx+64YpC/+eEUkeJ8ZthxzHLhyHsKKruFg4BqNWvT+2ypCzb8wDv4j2zVrDUoXtNY+EfirfJVg==";
    nodejs-slim = node;
  };
in
{ inherit node pnpm; }
