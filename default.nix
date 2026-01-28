{ lib
, stdenvNoCC
, fetchFromGitHub
}:

stdenvNoCC.mkDerivation rec {
  pname = "rime-xkjd";
  version = "6.0";

  src = ./.;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/share/rime-data
    
    # Install main rime config files
    cp -r rime/* $out/share/rime-data/
    
    # Install Linux-specific system tools config files
    cp Tools/SystemTools/default.yaml $out/share/rime-data/
    cp Tools/SystemTools/default.custom.yaml $out/share/rime-data/
    
    # Install Linux-specific schema files
    cp Tools/SystemTools/rime/Linux/*.yaml $out/share/rime-data/
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Xingkong Jiandao (星空键道6) - A Rime input method schema";
    homepage = "https://github.com/xkinput/Rime_JD";
    license = licenses.free; # No explicit license in repository
    maintainers = [ ];
    platforms = platforms.all;
  };
}
