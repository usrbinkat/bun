{ pkgs }:

# Bun's Linux debug builds require Zstandard-compressed debug sections.
pkgs.llvmPackages_21.overrideScope (
  _final: prev: {
    libllvm = prev.libllvm.overrideAttrs (old: {
      propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pkgs.zstd ];
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DLLVM_ENABLE_ZSTD=FORCE_ON" ];
    });
  }
)
