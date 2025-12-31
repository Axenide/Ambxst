# Installing without Nix

- Clone quickshell
  - git clone https://git.outfoxxed.me/quickshell/quickshell.git 
  - cmake -GNinja -B build 
  - cmake --build build 
  - sudo cmake --install build
- Install org.kde.syntaxhighlighting (Required for the assistant in dashboard)
   - sudo pacman -S syntax-highlighting
