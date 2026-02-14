{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "rime-keytao";
  version = "6.0";

  src = ./.;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/rime-data

    # Install main rime config files
    cp -r rime/* $out/share/rime-data/

    # Install platform-specific schema files
    ${
      if stdenvNoCC.isDarwin then
        ''
          # macOS: Install Mac-specific configs
          cp schema/mac/*.yaml $out/share/rime-data/
        ''
      else
        ''
          # Linux: Install Linux-specific schemas
          cp schema/linux/*.yaml $out/share/rime-data/
        ''
    }

    runHook postInstall
  '';

  meta = with lib; {
    description = "KeyTao (星空键道6) - A Rime input method schema";
    homepage = "https://github.com/xkinput/KeyTao";
    license = licenses.free; # No explicit license in repository
    maintainers = [ ];
    platforms = platforms.all;
  };
}
