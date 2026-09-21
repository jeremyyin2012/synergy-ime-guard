# Synergy IME Guard

Synergy IME Guard 是一个原生 macOS 小工具，用于规避 Synergy 3 的一种输入问题：
当 Mac 作为 Synergy 服务器并使用简体中文拼音输入法时，发送到远端屏幕的逗号、
句号等标点可能丢失。

鼠标离开本机屏幕时，守护程序会暂时把服务器 Mac 切到系统自带的 ABC 键盘布局；
鼠标返回后，再恢复原来的输入法。程序只运行在 macOS 上，但远端客户端可以是
Windows、Linux 或 macOS。

## 哪些组合需要安装

| 键盘所在机器 / Synergy 服务器 | 远端客户端 | 是否需要 Guard |
| --- | --- | --- |
| macOS，使用中文拼音 | Windows、Linux 或 macOS | 需要，安装在服务器 Mac 上 |
| macOS，只使用 ABC | 任意支持的客户端 | 通常不需要 |
| Windows 或 Linux | 任意支持的客户端 | 不需要，不经过这条 macOS 输入法链路 |

如果多台 Mac 都可能切换成服务器，就在每台 Mac 上安装。处于客户端角色时，
本机 Guard 会保持被动，不会切换输入法。

[Synergy 本身支持 Windows、macOS 和 Linux](https://support.symless.com/hc/en-us/articles/33562793892497-Operating-system-and-hardware-requirements)；
本项目不修改、不内嵌，也不重新分发 Synergy。
本项目是独立的社区解决方案，与 Symless 没有关联，也未获得其背书；Synergy 商标
归相应权利人所有。

## 使用条件与已验证范围

- 服务器为 macOS 13 或更高版本
- Synergy 3 正在运行，存在本机 `synergy-core` 进程和切屏日志
- 系统已启用 ABC 输入源
- 已关闭 Synergy 的语言同步功能

v0.1.x 已在 Synergy 3.6.3、macOS 26.5.1/26.5.2、Apple Silicon、简体中文
拼音、一台活动服务器 Mac 和一台被动客户端 Mac 的环境中完成实机验证；主从进程
识别与角色门控另有自动化测试。Windows/Linux 属于 Synergy 支持的远端平台，也符合
本工具的运行边界，但没有纳入实机实验室，因此不会把它们标记成
“已实测”。Deskflow 暂不声明支持。

v0.1.1 修复了进程探测子进程在长期运行时泄漏文件描述符的问题，同时减少后台进程
快照次数，并把探测失败明确写入诊断日志。

## 安装

下载压缩包与校验文件，核对 SHA-256 后，以当前登录用户安装。不要使用 `sudo`。

```bash
curl -fLO https://github.com/jeremyyin2012/synergy-ime-guard/releases/download/v0.1.1/synergy-ime-guard-v0.1.1-macos-universal.tar.gz
curl -fLO https://github.com/jeremyyin2012/synergy-ime-guard/releases/download/v0.1.1/synergy-ime-guard-v0.1.1-macos-universal.tar.gz.sha256
shasum -a 256 -c synergy-ime-guard-v0.1.1-macos-universal.tar.gz.sha256
tar -xzf synergy-ime-guard-v0.1.1-macos-universal.tar.gz
cd synergy-ime-guard-v0.1.1-macos-universal
./install.sh
```

安装器会自动读取本机 Synergy 屏幕名。如果 Synergy 未运行、语言同步仍开启、ABC
不存在，或二进制与当前 Mac 不兼容，安装器会停止。官方 Release 同时支持 Intel 和
Apple Silicon；升级激活失败时会恢复上一版。

Release 使用临时签名，尚未经过 Apple 公证；Release 提供的 SHA-256 文件是完整性
校验依据。也可以自行从源码构建。

## 查看状态

```bash
"$HOME/Library/Application Support/SynergyIMEGuard/scripts/status.sh"
```

诊断结果会显示 Synergy 主从角色、屏幕名、语言同步状态、当前与待恢复输入源、ABC
是否可用以及最近的鼠标位置。程序不读取或记录键盘内容。

运行日志位于 `~/Library/Logs/SynergyIMEGuard/`。鼠标停留在远端期间，
`~/Library/Application Support/SynergyIMEGuard/state/` 中可能存在一份待恢复状态；
只有输入法恢复成功后才会清除。

## 卸载

```bash
"$HOME/Library/Application Support/SynergyIMEGuard/scripts/uninstall.sh"
```

卸载器会先恢复输入法。若恢复失败，它会停止卸载并保留二进制和状态，供下次重试。
传入 `--keep-logs` 可以保留日志。

## 源码构建与测试

需要带 Swift 5.9 Package 工具链或更高版本的 Xcode。

```bash
swift test
./scripts/build-release.sh
```

Release 脚本会分别构建 arm64 和 x86_64，合并成通用二进制，完成临时签名，并生成
压缩包及 SHA-256 校验文件。

## 安全边界

- 只有本机确实是指定名称的 Synergy 服务器时才处理离开事件。
- 不记录按键、剪贴板或输入内容；不联网，也没有遥测。
- 不修改 Synergy 证书、加密、账号或屏幕拓扑。
- 切到 ABC 前先持久化原输入法。
- 重复离开、日志轮换或进程重启不会覆盖待恢复状态。
- 鼠标返回、服务器消失、正常退出、升级和卸载时都会尝试恢复。

更多细节见[设计文档](docs/DESIGN.md)、[测试矩阵](docs/TEST_MATRIX.md)和
[安全策略](SECURITY.md)。

## 上游问题

相关行为见 Deskflow issue
[#9465](https://github.com/deskflow/deskflow/issues/9465)、
[#9791](https://github.com/deskflow/deskflow/issues/9791) 和
[#9332](https://github.com/deskflow/deskflow/issues/9332)。

## 许可证

MIT
