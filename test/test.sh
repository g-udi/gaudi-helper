
SOURCE_LOCATION="$(pwd)"
source $SOURCE_LOCATION/lib.sh

@test "Should return correct information (Description and Website) for an existing cask software" {
  run getSoftwareInfo "cask" "google-chrome" "brew cask info"
  [ "$output" = "google-chrome::Cross-platform web browser https://www.google.com/chrome/" ]
}

@test "Should return correct information (Website) for an existing cask software if description is not found" {
  run getSoftwareInfo "cask" "franz" "brew cask info"
  [ "$output" = "franz::https://meetfranz.com/" ]
}

@test "Should return an error code and no information for a non-existent cask software" {
  run getSoftwareInfo "cask" "iDontExist!!!" "brew cask info"
  [ "$status" -eq 1 ]
}

@test "Should return correct information (Description and Website) for an existing brew formula" {
  run getSoftwareInfo "brew" "screen" "brew info"
  [ "$output" = "screen::Terminal multiplexer with VT100/ANSI terminal emulation https://www.gnu.org/software/screen" ]
}

@test "Should return an error code and no information for a non-existent brew forumla" {
  run getSoftwareInfo "brew" "iDontExist!!!" "brew info"
  [ "$status" -eq 1 ]
}

@test "Should return correct information (Description and Website) for an existing npm package" {
  run getSoftwareInfo "npm" "npmrc" "npm view"
  [ "$output" = "npmrc::Switch between different .npmrc files with ease and grace [36mhttps://github.com/deoxxa/npmrc[39m" ]
}

@test "Should return an error code and no information for a non-existent npm package" {
  run getSoftwareInfo "npm" "iDontExist!!!" "npm view"
  [ "$status" -eq 1 ]
}

@test "Should return correct information (Description and Website) for an existing pip package" {
  run getSoftwareInfo "pip" "pycparser" "pip show"
  [ "$output" = "pycparser::C parser in Python https://github.com/eliben/pycparser" ]
}

@test "Should return an error code and no information for a non-existent pip package" {
  run getSoftwareInfo "pip" "iDontExist!!!" "pip show"
  [ "$status" -eq 1 ]
}

@test "Should return the software name if no information is available (denoted by *)" {
  run getSoftwareInfo "tap" "koekeishiya/formulae" "*"
  [ "$output" = "koekeishiya/formulae::" ]
  run getSoftwareInfo "gem" "bundler" "*"
  [ "$output" = "bundler::" ]
}