# Linux QQ ChromeOS Fix

让 Linux QQ 在 **ChromeOS 的 Linux 容器（Crostini）** 里以原生 Wayland 舒服地运行。

- 命令：`qq-crfix`
- 应用菜单项：**QQ (CrFix)**
- 基于 [SHORiN-KiWATA/linuxqq-wayland-fix](https://github.com/SHORiN-KiWATA/linuxqq-wayland-fix) 改造。上游面向普通 Linux Wayland 桌面，本项目只针对 Crostini。

警告：Vibe Coding

## 这个项目做了什么

| 改动 | 说明 |
| --- | --- |
| 默认启动参数 | `--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=1`。前两个参数打开 Wayland IME，最后一个把 Chromium 拉回 ChromeOS 认得的 text-input-v1 |
| 删掉 `QQ_WAYLAND_FIX_ANGLE` | 连同全部相关功能一起删除：Vulkan ICD 探测、`--use-angle=vulkan/swiftshader`、`VK_DRIVER_FILES` 混合显卡限定、GPU 进程崩溃后的自动回退监视、`~/.cache/.../angle-vulkan-failed` 记录、`--doctor` 里的 ANGLE 检查，以及文档中的对应章节。启动器**不再给 QQ 传任何 ANGLE/Vulkan 参数，也不设置 `VK_DRIVER_FILES`** |
| 改名 | 项目 **Linux QQ ChromeOS Fix**；可执行文件 `qq-crfix`；桌面项 `QQ (CrFix)`；日志、缓存、环境变量前缀统一为 `qq-crfix` / `QQ_CRFIX_*` |
| 删掉桌面环境专用功能 | KDE 的 KWin `ScreenShot2`、GNOME 的 portal `Screenshot` 两条截图路径，连同 `qq-screenshot-helper` 可执行文件与它的 `.desktop` 权限声明；KDE 下自动禁用剪贴板修复、合成器版本探测（niri / Hyprland / KWin / GNOME Shell）、niri IPC、`--doctor` 里按桌面分流的检查，以及相关环境变量和文档章节 |
| **删掉截图 / 屏幕共享 / 共享电脑声音 / Easy Effects 相关功能** | 上游的 `libqq-wl-portal.so`（屏幕共享、共享设备音频、共享时防闪退、语音麦克风延迟）、`libqq-screenshot.so`（截图防闪退）、`libqq-borderfix.so`（共享边框、截图覆盖层、提示条）三个注入库整体删除；连同 portal / ScreenCast 自检、Easy Effects 排除名单检查、截屏与 capture-source 协议描述、DMA-BUF/内存测试工具、演示文件、`libpulse` / `libpipewire` 构建依赖及对应文档章节一并清理。ChromeOS 的 Sommelier 不提供 `ext-image-copy-capture`、`wlr-screencopy` 等截屏协议，容器里也没有可用的 ScreenCast 后端，这些功能在 Crostini 下**既不需要也实现不了**。详见 [常见问题与排错](docs/常见问题与排错.md) |
| 不再伪装会话类型 | 启动器不再把 `XDG_SESSION_TYPE` 设成 `x11`（那原本是配合屏幕共享/截图注入库的）。QQ 按容器里的真实会话类型走自己的截图路径，也就不会踩 XWayland 根窗口 `XGetImage` 的闪退 |
| 精简后保留 | 启动参数与启动前 Wayland socket 可连接性检查、剪贴板修复（`libqq-clipbridge.so`）、`--doctor` 自检、`install` / `uninstall` 快捷方式覆盖 |
| 启动前防护 | 启动前真正 connect 一次 `WAYLAND_DISPLAY` 对应的 socket：连不上就自动改用其它可连接的 `wayland-*`，一个都没有就明确报错退出。QQ 在 Ozone/Wayland 初始化失败后会空指针段错误，这层检查保证不会把 QQ 送进那个崩溃路径 |

上游的剪贴板功能演示（录制于普通 Linux Wayland 桌面，不是 Crostini）：[剪贴板](./pics/剪贴板-after.gif)。

> 剪贴板注入库依赖合成器提供 `ext-data-control` / `wlr-data-control` 协议；Sommelier 是否提供取决于 ChromeOS 版本，请以 `qq-crfix --doctor` 的结果为准。**本项目的核心目标（原生 Wayland + 输入法 + 不花屏）不依赖这些协议。**

## 安装

QQ 本体需要另外安装（[官方 deb](https://im.qq.com/linuxqq/)）。目前只支持原生的 `linuxqq` 和 AppImage 版 `linuxqq-appimage`，Flatpak 等沙盒版不支持。

Crostini 里先看容器是 Debian 几：

```bash
cat /etc/debian_version
```

### 发行包（推荐）

从 [Releases](https://github.com/Remik1r3n/LinuxQQ-CrFix/releases) 下载对应的包：

```bash
sudo apt install ./qq-crfix_*debian12_amd64.deb   # Debian 12 (bookworm) 容器
sudo apt install ./qq-crfix_*debian13_amd64.deb   # Debian 13 (trixie) 容器
sudo dnf install ./qq-crfix-*.fc43.x86_64.rpm     # Fedora 43+
sudo pacman -U ./qq-crfix-*.pkg.tar.zst           # Arch（需先装好 linuxqq）
```

### 源码

依赖：C 编译器、make、pkg-config、wayland-scanner，以及 libX11、libwayland-client 的开发文件。不再需要 libpulse / libpipewire 的开发包。

```bash
make
sudo make install PREFIX=/usr
```

### Nix / NixOS（可选，非 Crostini 场景）

仓库自带 `flake.nix`，提供 `packages.default`、`overlays.default`、`nixosModules.default`、`homeModules.default`。模块选项改名为 `programs.qq-crfix`：

```nix
{
  inputs.qq-crfix.url = "github:Remik1r3n/LinuxQQ-CrFix";

  outputs = { self, nixpkgs, qq-crfix, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        qq-crfix.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true; # pkgs.qq 是 unfree
          programs.qq-crfix.enable = true;
        }
      ];
    };
  };
}
```

`enable = true` 会装好修复包和 `pkgs.qq`；只想装修复包：`programs.qq-crfix.qq = null`。Home Manager 用户改用 `homeModules.default`，选项相同。

## 使用

安装后**完全退出 QQ（包括托盘）**，再从应用菜单打开「**QQ (CrFix)**」，或者直接在终端跑：

```bash
qq-crfix
```

ChromeOS 输入法无需在容器里装 Fcitx：确保 ChromeOS 系统层面的中文输入法已经启用，在 QQ 输入框里用系统快捷键切换即可。`--doctor` 会检查合成器有没有提供 `text-input-v1`。

其他命令：

```bash
qq-crfix --doctor      # 检查运行环境与当前 QQ 版本
qq-crfix --version     # 版本
qq-crfix --help        # 完整参数与环境变量说明
qq-crfix install       # 覆盖原生 QQ 快捷方式，让菜单里的「QQ」也启动修复版（会隐藏「QQ (CrFix)」）
qq-crfix uninstall     # 恢复原样
```

`install` 只在 `~/.local/share/applications/` 放快捷方式，不改动系统文件；卸载本项目前请先运行 `uninstall`。

### 环境变量

| 变量 | 作用 |
| --- | --- |
| `QQ_CRFIX_QQ` | QQ 的启动命令（默认先找 PATH 里的 `linuxqq`，再找 `/opt/QQ/qq`） |
| `QQ_CRFIX_LOG` | 日志文件（默认 `$XDG_RUNTIME_DIR/qq-crfix.log`） |
| `QQ_CRFIX_IME_DISABLE=1` | 只关掉两个 IME 参数（排查用），`--ozone-platform=wayland` 仍保留 |
| `QQ_CRFIX_WAYLAND_DISPLAY=wayland-1` | 显式指定给 QQ 的 Wayland display；连不上直接报错，不自动回退 |
| `QQ_CRFIX_IGNORE_WAYLAND_CHECK=1` | 跳过启动前的 socket 可连接性检查（排查用，日志记 `wl=skip`） |
| `QQ_CLIPBOARD_FIX_DISABLE=1` | 关闭剪贴板修复（排查用） |
| `QQ_CLIPBOARD_DEBUG=1` | 剪贴板日志多记每次向 QQ 取数据的结果 |

`qq-crfix --help` 会列出启动器自己认识的变量；剪贴板库自己的开关见 [常见问题与排错](docs/常见问题与排错.md)。

## 常见问题

- **一点图标就段错误 / QQ 没有窗口直接退出**：多半是 `WAYLAND_DISPLAY` 指向的 socket 变成了「空壳」（文件还在但没人监听）。启动器现在会自动改用可连接的 display 并在日志里写 `wl=...`；一个可用都没有时会明确报错而不是段错误。跑 `qq-crfix --doctor` 看会话段，必要时执行 `systemctl --user restart sommelier@0.service` 修复，详见 [常见问题与排错](docs/常见问题与排错.md)。
- **QQ 里打不了中文**：先跑 `qq-crfix --doctor` 看有没有 `text-input-v1`；确认 QQ 是从「QQ (CrFix)」启动的（旧 QQ 要连托盘一起退干净）；ChromeOS 系统输入法要处于启用状态。切换输入法的快捷键若被 ChromeOS 抢走，需要给 Sommelier 配 `SOMMELIER_ACCELERATORS` 放行。
- **整个 QQ 花屏 / 显示不全**：确认没有手动给 QQ 传 `--use-angle=*`、`--enable-features=Vulkan` 或 `VK_DRIVER_FILES`，也没有残留上游 `linuxqq-wayland-fix` 的启动器在启动 QQ。本项目永远不会选 Vulkan 后端。
- **剪贴板不通**：跑一下 `qq-crfix --doctor`；Sommelier 不提供 data-control 协议时剪贴板修复无法生效，详见 [常见问题与排错](docs/常见问题与排错.md)。
- **截图 / 屏幕共享不能用**：这些功能的上游修复已**整体删除**，本项目不再提供任何相关开关或环境变量，Crostini 下本来也无法实现。不要再去寻找 `QQ_WL_*` / `QQ_SCREENSHOT_*` / `QQ_BORDER_*` 之类的变量；QQ 自带的截图/共享行为由 QQ 与 ChromeOS 决定。

更完整的原理与剪贴板逆向分析见 [docs/原理详解.md](docs/原理详解.md)（沿袭上游，已去掉 ANGLE/Vulkan、KDE/GNOME 专用截图，以及截图/屏幕共享/Easy Effects 相关章节）。

## 致谢

上游 [SHORiN-KiWATA/linuxqq-wayland-fix](https://github.com/SHORiN-KiWATA/linuxqq-wayland-fix)

腾讯 Workbuddy 送的免费鸡蛋

## 许可证

MIT。保留上游版权声明；`protocol/` 下的协议描述文件保留其原有版权声明。
