# Claude Code 环境一键安装脚本

将 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 接入 [智谱 AI](https://open.bigmodel.cn/) 的 Anthropic 兼容 API，一行命令完成安装和配置。

## 一行安装

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/xiaowen-0725/scripts/main/claude_code_env.sh | bash
```

**Windows PowerShell**

```powershell
iex (irm 'https://raw.githubusercontent.com/xiaowen-0725/scripts/main/claude_code_env.ps1' -UseBasicParsing)
```

## 脚本会做什么

1. 检测并安装 Node.js（>= 18）
2. 全局安装 Claude Code CLI（`npm install -g @anthropic-ai/claude-code`）
3. 跳过首次启动引导
4. 交互式输入智谱 AI API Key，写入配置文件

## 前置条件

- 智谱 AI API Key — 从 [智谱开放平台](https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys) 获取
- 网络能访问 `open.bigmodel.cn` 和 `registry.npmjs.org`

## 安装后使用

```bash
claude
```

## 配置文件位置

| 系统 | 路径 |
|------|------|
| macOS / Linux | `~/.claude/settings.json` |
| Windows | `%USERPROFILE%\.claude\settings.json` |

配置内容：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "<your-api-key>",
    "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5-turbo",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.1",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  }
}
```

## 常见问题

**Q: npm install 速度慢或超时**

可以设置 npm 镜像后重新运行脚本：

```bash
npm config set registry https://registry.npmmirror.com
```

**Q: macOS 提示 nvm 安装失败**

确保网络能访问 `raw.githubusercontent.com`，或手动安装 nvm 后再运行脚本。

**Q: Windows 提示"无法运行脚本"或参数为空**

PowerShell 默认禁止运行脚本，使用以下命令临时放开：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

然后重新运行一行安装命令。

如果一行命令仍然失败，可以手动下载后执行：

```powershell
# 下载脚本
Invoke-WebRequest -Uri https://raw.githubusercontent.com/xiaowen-0725/scripts/main/claude_code_env.ps1 -OutFile claude_code_env.ps1 -UseBasicParsing
# 执行
.\claude_code_env.ps1
```

**Q: 如何更换 API Key**

直接编辑配置文件，修改 `ANTHROPIC_AUTH_TOKEN` 的值即可。

## License

MIT
