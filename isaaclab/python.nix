{
  lib,
  runCommand,
  makeWrapper,
  glibc,
  zlib,
  libxcrypt-legacy,
  libnsl,
  libtirpc,
  libuuid,
  libxrender,
  libxi,
  libxinerama,
  libxext,
  libxxf86vm,
  isaacsim,
}:
runCommand "isaaclab-bundled-python" {nativeBuildInputs = [makeWrapper];} ''
  mkdir -p "$out/bin"
  makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 "$out/bin/python3" \
    --add-flags '--argv0 ${isaacsim}/isaacsim/kit/python/bin/python3 ${isaacsim}/isaacsim/kit/python/bin/.python3-wrapped' \
    --run 'source ${isaacsim}/bin/isaacsim-env' \
    --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
    zlib
    libxcrypt-legacy
    libnsl
    libtirpc
    libuuid
    libxrender
    libxi
    libxinerama
    libxext
    libxxf86vm
  ]}
''
