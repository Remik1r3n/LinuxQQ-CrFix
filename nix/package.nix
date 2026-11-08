{
  lib,
  stdenv,
  makeWrapper,
  pkg-config,
  wayland-scanner,
  libx11,
  wayland,
  # 启动器脚本运行时要用的小工具：pgrep、wayland-info、od、xargs、systemctl…，
  # 从应用菜单启动时它们不一定在 PATH 里，wrap 的时候补上。
  coreutils,
  findutils,
  gawk,
  gnugrep,
  gnused,
  procps,
  systemd,
  wayland-utils,
  # 名字刻意不叫 src：callPackage 会把 pkgs 里的同名属性自动填进来
  # （pkgs.src 是 simple-revision-control），默认值就永远用不上。
  source ? ../.,
  version ? "0.0.0",
  # 被修复的 QQ（nixpkgs 的 pkgs.qq，unfree 许可）。
  # null 表示不写死：启动器会退回自己在 PATH 里找 linuxqq（或 /opt/QQ/qq），
  # 或者读用户显式设置的 QQ_CRFIX_QQ。
  #
  # 名字不叫 qq 是因为 callPackage 会拿 pkgs 里的同名属性自动填充，
  # pkgs.qq 正好存在，会把这个默认值覆盖成 unfree 的 QQ 本体。
  qqPackage ? null,
}:

let
  runtimeTools = [
    coreutils
    findutils
    gawk
    gnugrep
    gnused
    procps # pgrep：--doctor 检查 QQ 是否被注入、clipsync 是否在跑
    systemd # systemctl：--doctor 检查 linuxqq-clipsync
    wayland-utils # wayland-info：--doctor 检查 data-control 协议与 text-input-v1
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "qq-crfix";
  inherit version;
  src = source;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    libx11
    wayland
  ];

  # Makefile 的 PREFIX 决定 bin/、lib/qq-crfix/、share/ 的落点；
  # 启动器里的 @LIBEXECDIR@ 在安装时展开成 store 里的绝对路径。
  makeFlags = [
    "VERSION=${finalAttrs.version}"
    "PREFIX=${placeholder "out"}"
  ];

  buildPhase = ''
    runHook preBuild
    make $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make install $makeFlags
    runHook postInstall
  '';

  postFixup = ''
    # 菜单里的 Exec 用绝对路径，profile 不在 PATH 里也能启动。
    substituteInPlace $out/share/applications/qq-crfix.desktop \
      --replace-fail 'Exec=qq-crfix' "Exec=$out/bin/qq-crfix"

    # 下面两个补丁只改装出来的运行时脚本，不动仓库源码。
    #
    # 1. 上游用 `compgen -G` 判断有没有崩溃记录。compgen 属于 bash 的可编程补全
    #    内建，nix 构建出的 bash 没编译它（compgen: command not found），而
    #    keep_crash_records 在每次启动前都会调用。换成等价的 ls 判断。
    substituteInPlace $out/bin/qq-crfix \
      --replace-fail 'compgen -G "$QQ_CRASH_DIR/tomb_*.txt" >/dev/null || return 0' \
      'ls "$QQ_CRASH_DIR"/tomb_*.txt >/dev/null 2>&1 || return 0'

    # 2. QQ 装在 store 里，没有 /opt/QQ，--doctor 的剪贴板实现检查会找不到 QQ。
    #    QQ_CRFIX_QQ_ROOT 由下面的 wrapper 指向 store 里的 .../opt/QQ；
    #    没设这个变量时保持 /opt/QQ 的行为。qq_runtime_exe 找不到运行中的 QQ
    #    时的回退路径也要跟着走 store（qq_runtime_dir 由它得来）。
    substituteInPlace $out/bin/qq-crfix \
      --replace-fail 'elif [[ -d /opt/QQ/resources/app ]]; then' \
      'elif [[ -d "''${QQ_CRFIX_QQ_ROOT:-/opt/QQ}/resources/app" ]]; then' \
      --replace-fail '        echo /opt/QQ/resources/app' \
      '        echo "''${QQ_CRFIX_QQ_ROOT:-/opt/QQ}/resources/app"' \
      --replace-fail '    [[ -x /opt/QQ/qq ]] && echo /opt/QQ/qq' \
      '    [[ -x "''${QQ_CRFIX_QQ_ROOT:-/opt/QQ}/qq" ]] && echo "''${QQ_CRFIX_QQ_ROOT:-/opt/QQ}/qq"'

    # 3. 上游在 PATH 里只找 linuxqq（AppImage 包的命令名）。nixpkgs 的 QQ 命令
    #    叫 qq，加上它，这样没有写死 QQ 路径时（没开 allowUnfree，见 flake.nix）
    #    启动器仍能从 PATH 里找到 nixpkgs 装的 QQ。
    substituteInPlace $out/bin/qq-crfix \
      --replace-fail '    elif command -v linuxqq >/dev/null 2>&1; then
        command -v linuxqq
' \
      '    elif command -v linuxqq >/dev/null 2>&1; then
        command -v linuxqq
    elif command -v qq >/dev/null 2>&1; then
        command -v qq
'

    # PATH：补上启动器与 --doctor 依赖的小工具。
    # QQ_CRFIX_QQ：指向 pkgs.qq 的启动脚本（它会自己处理 libssh2 预加载、
    #   gsettings / GIO 模块、NIXOS_OZONE_WL 等 NixOS 上必需的运行环境）。
    # QQ_CRFIX_QQ_ROOT：上面第 2 个补丁用到的 QQ 安装目录。
    wrapProgram $out/bin/qq-crfix \
      --prefix PATH : ${lib.makeBinPath runtimeTools} \
      ${lib.optionalString (qqPackage != null) ''
        --set QQ_CRFIX_QQ ${lib.getExe' qqPackage "qq"} \
        --set QQ_CRFIX_QQ_ROOT "${qqPackage}/opt/QQ"
      ''}
  '';

  meta = {
    description = "Linux QQ ChromeOS Fix：让 Linux QQ 在 ChromeOS Crostini 下以原生 Wayland 运行并使用 ChromeOS 输入法";
    longDescription = ''
      默认给 QQ 加上 --ozone-platform=wayland --enable-wayland-ime
      --wayland-text-input-version=1（ChromeOS 的 crosim 只支持 text-input-v1），
      不传任何 ANGLE/Vulkan 后端参数（Crostini 的虚拟 GPU 走 Vulkan 会花屏）。
      同时通过 LD_PRELOAD 注入剪贴板修复库，不改动 QQ 自身文件。
      从应用菜单的「QQ (CrFix)」启动，或用 qq-crfix --doctor 自检。
    '';
    homepage = "https://github.com/Remik1r3n/LinuxQQ-CrFix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "qq-crfix";
  };
})
