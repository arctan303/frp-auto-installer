# 📘 FRP Manager — 一键安装与管理 FRP 客户端（frpc）

一个简洁高效的 **FRP（Fast Reverse Proxy）客户端一键安装与管理脚本**。  
支持 **自动安装、生成配置、添加/修改/删除映射、systemd 服务管理、自动规则命名** 等功能。

适用于：Ubuntu / Debian / 其它 systemd Linux。

---

## ✨ 功能特性

- 🚀 **一键安装 frpc**（自动下载 + 解压 + 配置）
- 🛠️ **自动生成 frpc.toml 配置**
- 🔁 **自动生成规则名称：`22_to_6700`**
- ⚙️ **支持添加、删除、修改代理映射**
- 🔧 **内置 systemd 管理：启动 / 停止 / 启用开机自启**
- 📂 **配置文件结构保持整洁，自动删除指定 [[proxies]] 块**
- 👀 **实时查看运行状态与日志**

---

## 📥 安装与运行

在任意 Linux 服务器终端执行以下任意方式下载安装：

### 🔹方式 1：从 GitHub Raw 下载（推荐）

```bash
wget -O frp_manager.sh https://raw.githubusercontent.com/arctan303/frp-auto-installer/main/frp_manager.sh && chmod +x frp_manager.sh && ./frp_manager.sh
```
或使用 curl：

```bash
curl -o frp_manager.sh https://raw.githubusercontent.com/arctan303/frp-auto-installer/main/frp_manager.sh && chmod +x frp_manager.sh && ./frp_manager.sh
```
### 🔹方式 2：从 arctan.top 镜像下载（备用源）
```bash
wget -O frp_manager.sh https://arctan.top/share/frp_manager.sh && chmod +x frp_manager.sh && ./frp_manager.sh
```
或使用 curl：

```bash
curl -o frp_manager.sh https://arctan.top/share/frp_manager.sh && chmod +x frp_manager.sh && ./frp_manager.sh
```
