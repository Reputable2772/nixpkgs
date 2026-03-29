{
  lib,
  stdenv,
  fetchFromCodeberg,
  gradle_9,
  makeBinaryWrapper,
  jdk25,
  libGL,
  nix-update-script,
  help2man,
  # breakpointHook
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gaiasky";
  version = "3.7.1";
  src = fetchFromCodeberg {
    owner = "gaiasky";
    repo = "gaiasky";
    tag = finalAttrs.version;
    hash = "sha256-UAVuivkeF234hoUyfCv7depspr3dyoyzYJDD0mKGAr4=";
  };

  nativeBuildInputs = [
    gradle_9
    makeBinaryWrapper
    help2man
  ];

  buildInputs = [
    jdk25
    libGL
    # breakpointHook
  ];

  __darwinAllowLocalNetworking = true;

  gradleBuildTask = "core:dist";

  # Gaiasky binary has to be executed to generate manpage.
  # However, since since /usr/bin/env bash is hardcoded in the binary
  # it errors out. It is generated in postBuild phase instead.
  gradleFlags = [
    "--stacktrace"
    "--debug"
    "-x :core:generateManPage"
    "-x :core:gzipManPage"
  ];

  mitmCache = gradle_9.fetchDeps {
    inherit (finalAttrs) pname;
    data = ./deps.json;
  };

  # The build output is stored in releases/gaiasky-version-version instead of releases/gaiasky-.
  postPatch = ''
    substituteInPlace build.gradle \
      --replace-fail "def cmd = \"git describe --abbrev=0 --tags HEAD\"" "def cmd = \"echo ${finalAttrs.version}\"" \
      --replace-fail "cmd = \"git rev-parse --short HEAD\"" "cmd = \"echo ${finalAttrs.version}\""

    printenv
  '';

  postBuild = ''
    patchShebangs "releases/gaiasky-${finalAttrs.version}.${finalAttrs.version}"/gaiasky
    # gradleFlags="" gradle :core:generateManPage -x :core:copyExecutables
  '';

  installPhase = ''
    runHook preInstall
    # exit 1

    install -m755 -d $out/bin $out/share/applications $out/share/metainfo $out/share/gaiasky $out/share/man/man6

    cp -r "releases/gaiasky-${finalAttrs.version}.${finalAttrs.version}"/* $out/share/gaiasky/
    install -Dm644 $out/share/gaiasky/gs_icon.svg $out/share/icons/hicolor/scalable/apps/gaiasky.svg
    install -Dm644 $out/share/gaiasky/gs_round_256.png $out/share/icons/hicolor/256x256/apps/gaiasky.png
    install -m644 $out/share/gaiasky/space.gaiasky.GaiaSky.metainfo.xml $out/share/metainfo/
    install -m644 $out/share/gaiasky/gaiasky.desktop $out/share/applications/
    # install -m644 $out/share/gaiasky/gaiasky.6 $out/share/man/man6/

    substituteInPlace $out/share/applications/gaiasky.desktop \
      --replace-fail "Icon=/opt/gaiasky/gs_icon.svg" "Icon=gaiasky"

    makeWrapper $out/share/gaiasky/gaiasky \
      $out/bin/gaiasky \
      --set JAVA_HOME ${jdk25} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL ]}

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Open source 3D universe visualization software for desktop and VR with support for more than a billion objects.";
    homepage = "https://gaiasky.space";
    changelog = "https://codeberg.org/gaiasky/gaiasky/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [ reputable2772 ];
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
    mainProgram = "gaiasky";
  };
})
