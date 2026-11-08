{
  mkPackage,
  defaultQQ,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.qq-crfix;
in {
  options.programs.qq-crfix = {
    enable = lib.mkEnableOption "Linux QQ ChromeOS Fix (qq-crfix)：Crostini 下以原生 Wayland 运行并使用 ChromeOS 输入法";

    package = lib.mkOption {
      type = lib.types.package;
      default = mkPackage {
        inherit pkgs;
        overrides = {qqPackage = cfg.qq;};
      };
      defaultText = lib.literalExpression "qq-crfix.packages.\${system}.default";
      description = ''
        使用的 qq-crfix 包。默认用当前 pkgs 由 flake 里的
        {file}`nix/package.nix` 构建，因此跟随你系统的 nixpkgs。
      '';
    };

    qq = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = defaultQQ pkgs;
      defaultText = lib.literalExpression "(if pkgs.config.allowUnfree then pkgs.qq else null)";
      description = ''
        被修复的 QQ，即 nixpkgs 的 {option}`pkgs.qq`（unfree 许可，需要
        `nixpkgs.config.allowUnfree = true`）。它的路径会被写进启动器的
        `QQ_CRFIX_QQ`，并装进 {option}`home.packages`
        —— 原生 QQ 的菜单项和 `Icon=qq` 用的图标都来自它。

        设为 `null` 时不安装 QQ，启动器退回自己在 PATH 里找 `linuxqq` 或 `qq`
        （或者 `/opt/QQ/qq`），或者读你设置的 `QQ_CRFIX_QQ`。
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package] ++ lib.optional (cfg.qq != null) cfg.qq;
  };
}
