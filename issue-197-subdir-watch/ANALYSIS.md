# Issue #197 分析总结

GitHub Issue: https://github.com/air-verse/air/issues/197

## 一、问题分类

**类型**: Bug（缺陷）

**严重程度**: 中等（影响 WSL2 用户体验，但有 workaround）

**影响范围**: 
- WSL2 用户（特别是使用 `/mnt/c/...` 路径）
- 部分 NFS/网络文件系统用户
- 深层目录结构的项目

## 二、核心问题

Air 在某些环境下（特别是 WSL2）无法检测子目录中的文件变更，即使日志显示正在监听这些目录。

### 症状

- ✅ 修改根目录文件 → 触发重新编译
- ❌ 修改子目录文件（如 `cmd/app/main.go`） → 无响应
- ⚠️ 日志显示 "watching cmd/app" 但实际不工作

## 三、根因分析

### 主要原因：WSL2 的 inotify 限制

```
┌─────────────────────────────────────────────┐
│           WSL2 文件系统架构                  │
├─────────────────────────────────────────────┤
│                                             │
│  Linux 原生文件系统 (ext4)                   │
│  /home/user/...                             │
│  ✅ inotify 正常工作                         │
│                                             │
│  ─────────────────────────────────────      │
│                                             │
│  Windows 文件系统 (9P 协议挂载)              │
│  /mnt/c/Users/...                           │
│  ❌ inotify 不支持                           │
│                                             │
└─────────────────────────────────────────────┘
```

**技术细节**:
- WSL2 使用 9P 协议访问 Windows 文件系统
- 9P 协议不支持 Linux inotify 事件
- fsnotify 库依赖 inotify，无法接收文件变更通知

### 次要原因：事件处理竞态条件

**代码位置**: `air/runner/engine.go:301-303` + `util.go:280-286`

```go
// 事件处理
if isDir(ev.Name) {
    e.watchNewDir(ev.Name, removeEvent(ev))
    break
}

// isDir 检查
func isDir(path string) bool {
    i, err := os.Stat(path)
    if err != nil {
        return false  // ⚠️ stat 失败返回 false
    }
    return i.IsDir()
}
```

**问题**: 
1. 目录创建事件到达时，目录可能已被删除/移动
2. `os.Stat()` 失败，`isDir()` 错误地返回 false
3. 新目录未被添加到监听列表

## 四、为什么 poll=true 能解决问题

### Poll 模式工作原理

**代码位置**: Hugo `filenotify/poller.go`

```go
// 每 500ms 轮询一次
func (w *filePoller) watch(item *itemToWatch) {
    ticker := time.NewTicker(w.interval)
    for {
        select {
        case <-ticker.C:
            evs, err := item.checkForChanges()  // 检测变更
            // 发送合成事件...
        }
    }
}

// 记录目录状态
func (r *recording) record(filename string) error {
    fi, err := os.Stat(filename)
    r.FileInfo = fi
    
    if fi.IsDir() {
        f, err := os.Open(filename)
        fis, err := f.Readdir(-1)  // 读取目录内所有文件
        for _, fi := range fis {
            r.entries[fi.Name()] = fi  // 记录每个文件的状态
        }
    }
}
```

### Poll vs fsnotify 对比

| 特性 | fsnotify (默认) | Poll 模式 |
|------|----------------|-----------|
| 检测机制 | Linux inotify 内核事件 | 定时 `os.Stat()` + `os.Readdir()` |
| 延迟 | 即时（毫秒级） | ≥500ms (可配置) |
| CPU 使用 | 低 | 略高（定时轮询） |
| 文件系统兼容性 | 仅原生文件系统 | **所有文件系统** |
| WSL2 `/mnt/c/...` | ❌ 不工作 | ✅ 正常工作 |
| 系统资源限制 | 受 inotify watch 数量限制 | 无限制 |

**Poll 模式优势**:
- 不依赖内核事件，主动扫描文件状态
- 通过快照对比检测变更
- 在任何文件系统上都能工作（NFS、CIFS、9P 等）

## 五、复现方法

### 复现目录

已创建在: `issue-197-subdir-watch/`

```
issue-197-subdir-watch/
├── .air.toml           # Air 配置
├── go.mod              # Go 模块定义
├── README.md           # 详细说明
├── test.sh             # 测试脚本
└── cmd/
    └── app/
        └── main.go     # 简单 HTTP 服务器
```

### 快速测试

```bash
cd issue-197-subdir-watch

# 方法 1: 使用测试脚本
./test.sh

# 方法 2: 手动测试
air
# 在另一个终端修改 cmd/app/main.go
# 观察 Air 是否检测到变更
```

### 验证 Workaround

编辑 `.air.toml`，取消注释：
```toml
[build]
poll = true
poll_interval = 500
```

重启 Air 后应能正常检测子目录变更。

## 六、关键代码位置汇总

| 功能 | 文件路径 | 行号 |
|------|---------|------|
| Watcher 工厂函数 | `air/runner/watcher.go` | 9-24 |
| 目录递归监听 | `air/runner/engine.go` | 168-206 |
| 事件处理循环 | `air/runner/engine.go` | 292-320 |
| 动态添加新目录 | `air/runner/engine.go` | 325-347 |
| isDir 检查（竞态风险） | `air/runner/util.go` | 280-286 |
| Poll 模式实现 | Hugo `filenotify/poller.go` | 全文件 |
| fsnotify 封装 | Hugo `filenotify/fsnotify.go` | 全文件 |

## 七、解决方案建议

### 短期方案（用户）

在 `.air.toml` 中启用 poll 模式：
```toml
[build]
poll = true
poll_interval = 500
```

### 长期方案（Air 项目）

1. **自动检测 WSL2**: 
   - 检查 `/proc/version` 是否包含 "microsoft"
   - 检查路径是否以 `/mnt/` 开头
   - 自动启用 poll 模式或警告用户

2. **改进错误提示**:
   - 当 `watcher.Add()` 失败时记录详细日志
   - 提示用户启用 poll 模式

3. **修复 isDir 竞态**:
   - 在 `isDir()` 检查中添加重试逻辑
   - 或者记录 CREATE 事件的目录，延迟检查

4. **文档改进**:
   - 在 README 中明确说明 WSL2 限制
   - 提供故障排查指南

## 八、相关 Issue

- #274 - WSL file watching issues
- #509 - Poll mode discussion  
- fsnotify/fsnotify#9 - Request for poll-based watcher

## 九、测试环境矩阵

| 环境 | 预期结果 |
|------|----------|
| WSL2 + `/mnt/c/...` | ❌ Bug 必现 |
| WSL2 + `/home/...` | ✅ 通常正常 |
| 原生 Linux (ext4) | ✅ 正常 |
| macOS | ❓ 需测试 (FSEvents) |
| Windows 原生 | ❓ 需测试 (ReadDirectoryChangesW) |
| Docker (bind mount) | ⚠️ 可能有问题 |
| NFS/CIFS | ❌ 可能需要 poll 模式 |

## 十、总结

这是一个由 WSL2 架构限制引起的已知问题，而非 Air 代码缺陷。Air 已经提供了 `poll` 模式作为通用解决方案，但需要更好的文档和自动检测机制来帮助用户发现和解决这个问题。

**用户行动建议**:
- 如遇到子目录监听问题，立即启用 `poll = true`
- 尽量将项目放在 WSL2 原生文件系统 (`/home/...`) 而非 `/mnt/c/...`

**开发者行动建议**:
- 考虑为 WSL2 环境自动启用 poll 模式
- 改进诊断日志和错误提示
- 在文档中突出显示这个常见问题
