{lib, ...}:

with lib;
{
  imports = [
    ./android.nix
    ./backlight.nix
    ./bluetooth.nix
    ./cpu
    ./firmware.nix
    ./gpu
    ./keyboard.nix
    ./lid.nix
    ./monitors.nix
    ./printing.nix
    ./raid.nix
    ./scanner.nix
    ./sound.nix
    ./touchpad.nix
    ./webcam.nix
    ./wireless.nix
    ./yubikey.nix
  ];
}
