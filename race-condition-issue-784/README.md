# Race Condition Bug #784 - Reproduction Case

## 🐛 Bug 描述 (Bug Description)

**中文：**  
当一个文件变更触发新的构建（Build B）时，如果之前的构建（Build A）还在进行中，Air 的竞态条件会导致新的构建取消自己，使得运行的二进制文件版本落后。

**English:**  
When a file change triggers a new build (Build B) while an existing build (Build A) is running, a race condition in Air causes the new build to cancel itself, making the running binary outdated.

---

## 📋 问题根源 (Root Cause)

### 时间线分析 (Timeline Analysis)

```
Time:     0s        2s        4s        6s        8s       10s       12s
          |         |         |         |         |         |         |
Build A:  [触发] ----[========== building ==========]-[sleep 10s]----[完成]
                     ↑ buildRunCh <- true
                     ↑ 开始构建...

Build B:            [触发]--[X 自己取消了自己!]
                     ↑ 检查到 buildRunCh 有值
                     ↑ 向 buildRunStopCh 发送停止信号
                     ↑ 启动 go buildRun()
                     ↑ buildRunCh <- true (成功)
                     ↑ 检查 buildRunStopCh → 发现有值!
                     ↑ return (误以为要停止自己)

预期行为:           [========== building ==========]-[sleep 10s]----[完成]
(Expected)          应该继续执行，成为最新版本
```

### 代码位置 (Code Location)

**问题代码在 `air/runner/engine.go`：**

1. **Line 408-413** - `start()` 函数中：
```go
// already build and run now
select {
case <-e.buildRunCh:
    e.buildRunStopCh <- true  // Build B 为了停止 Build A 发送信号
default:
}
```

2. **Line 422-432** - `buildRun()` 函数中：
```go
func (e *Engine) buildRun() {
    e.buildRunCh <- true  // Build B 成功发送
    defer func() {
        <-e.buildRunCh
    }()

    select {
    case <-e.buildRunStopCh:  // Build B 收到了自己发送的停止信号!
        return                 // Build B 取消自己
    default:
    }
    // ...
}
```

### 竞态条件详解 (Race Condition Details)

**步骤 1：** Build A 启动
- `buildRun()` 执行 `buildRunCh <- true`
- 开始构建过程（需要 ~10 秒）

**步骤 2：** 用户触发 Build B（在 Build A 完成前）
- `start()` 中检查 `buildRunCh`，发现有值（Build A 放的）
- 向 `buildRunStopCh` 发送 `true`（意图停止 Build A）
- 调用 `go e.buildRun()` 启动 Build B

**步骤 3：** Build B 的 `buildRun()` 执行
- 此时 `buildRunCh` 已空（Build A 已取走）
- Build B 成功执行 `buildRunCh <- true`
- **问题：** Build B 立即检查 `buildRunStopCh`
- **发现有值！**（这是 Build B 自己在步骤 2 中发送的）
- Build B 误认为这是停止信号，执行 `return`
- **Build B 取消了自己！**

**结果：** 
- Build A 继续运行并完成
- Build B 被取消
- 最终运行的是 Build A 的代码（旧版本）
- 用户的最新修改（触发 Build B 的修改）不会生效

---

## 🔬 复现步骤 (Reproduction Steps)

### 🚀 方法 1: 自动化脚本（推荐）

#### A. 全自动复现 `reproduce-auto.sh`

**最简单的方式！** 一键运行，自动完成所有步骤：

```bash
cd race-condition-issue-784
./reproduce-auto.sh
```

**脚本会自动：**
- ✓ 启动 air（后台运行）
- ✓ 等待初始构建完成
- ✓ 精确时机触发 Build A 和 Build B
- ✓ 分析日志并检测 bug
- ✓ 生成详细的分析报告
- ✓ 自动清理和恢复文件

**输出示例：**
```
════════════════════════════════════════
🐛 Race Condition Bug #784 - Automated Reproducer
════════════════════════════════════════

[STEP] Running pre-flight checks...
[✓] Correct directory confirmed
[✓] air found: /home/user/go/bin/air
[✓] Port 8080 is available

[STEP] Starting air in background...
[✓] Air started (PID: 12345)

[STEP] Triggering Build A (modifying main.go)...
[✓] Build A triggered at 21:30:15.456

[STEP] Triggering Build B (modifying helper.go)...
[⚠] This should happen WHILE Build A is still running!
[✓] Build B triggered at 21:30:17.789

════════════════════════════════════════
📊 ANALYSIS RESULTS
════════════════════════════════════════

[INFO] Build starts detected: 3
[INFO] Build completions detected: 2

🐛 BUG REPRODUCED!

Analysis:
  • 3 builds were started
  • Only 2 builds completed
  • 1 build(s) were cancelled
  • Server is running OLD code (Build A)!
```

---

#### B. 手动辅助触发 `trigger-race.sh`

**想看完整的 air 日志？** 这个脚本配合手动启动的 air 使用：

**终端 1：**
```bash
cd race-condition-issue-784
air
```

**终端 2：**
```bash
cd race-condition-issue-784
./trigger-race.sh
```

**脚本会：**
- ✓ 检查 air 是否已启动
- ✓ 提供清晰的步骤说明
- ✓ 按精确时机触发两次构建
- ✓ 告诉你应该观察什么
- ✓ 辅助验证结果

**优势：**
- 可以实时观察 air 的完整日志
- 更清楚地理解 bug 发生过程
- 适合学习和演示

---

### 🔧 方法 2: 手动复现

#### 前置条件 (Prerequisites)

1. 确保已安装 Air：
   ```bash
   # 检查 air 是否在 PATH 中
   which air
   ```

2. 进入测试目录：
   ```bash
   cd race-condition-issue-784
   ```

#### 手动复现步骤 (Manual Reproduction)

#### 终端 1 - 启动 Air

```bash
# 启动 Air
air
```

**观察输出：**
- 初始构建开始
- 看到 "🔨 Build started at XX:XX:XX.XXX"
- 等待约 15 秒（构建 + sleep 10 秒）
- 看到 "🚀 Server started" 和 "📅 BUILD TIME: XX:XX:XX.XXX"
- 记录这个 BUILD TIME（例如：14:30:45.123）

#### 终端 2 - 触发测试

```bash
# 等待初始构建完成后再执行以下步骤

# 步骤 1: 触发 Build A
echo "// Trigger Build A" >> main.go
```

**返回终端 1 观察：**
- 应该看到 "🔨 Build started at XX:XX:XX.XXX"
- 记录 Build A 的开始时间（例如：14:31:00.456）

**立即在终端 2 执行（约 2-3 秒内）：**

```bash
# 步骤 2: 触发 Build B（在 Build A 完成前）
echo "// Trigger Build B" >> helper.go
```

**返回终端 1 观察日志：**
- 应该看到第二个 "🔨 Build started at XX:XX:XX.XXX"
- 记录 Build B 的开始时间（例如：14:31:02.789）
- **关键观察：** Build B 会立即停止，没有 "✅ Build complete"
- Build A 继续运行，最终完成并启动服务器

#### 终端 3 - 验证 Bug

等待所有构建完成后（约 15-20 秒），执行：

```bash
# 检查当前运行的版本
curl http://localhost:8080/version
```

**分析结果：**

🐛 **如果 Bug 存在：**
```
Build Time: 14:31:00.456
```
- 显示的是 Build A 的时间
- Build B 被自己取消了
- helper.go 的修改没有生效

✅ **如果 Bug 修复：**
```
Build Time: 14:31:02.789
```
- 显示的是 Build B 的时间
- Build B 正常完成
- helper.go 的修改已生效

---

## 📊 详细日志分析 (Log Analysis)

### 正常情况下的日志（Bug 存在时）

```
[时间] watching main.go
[时间] watching helper.go
[时间] 🔨 Build started at 14:31:00.456
[时间] 🔨 Build started at 14:31:02.789    ← Build B 开始
[时间] ✅ Build complete at 14:31:05.123   ← 只有 Build A 完成
[时间] 🚀 Server started
[时间] 📅 BUILD TIME: 14:31:00.456         ← Build A 的时间
```

**注意：** Build B 开始了但没有 "✅ Build complete"，因为它取消了自己。

### 修复后的日志（期望行为）

```
[时间] watching main.go
[时间] watching helper.go
[时间] 🔨 Build started at 14:31:00.456
[时间] 🔨 Build started at 14:31:02.789    ← Build B 开始
[时间] ✅ Build complete at 14:31:07.234   ← Build B 完成
[时间] 🚀 Server started
[时间] 📅 BUILD TIME: 14:31:02.789         ← Build B 的时间（最新）
```

**注意：** Build B 完整执行并完成，服务器运行最新版本。

---

## 🔧 配置说明 (Configuration Notes)

### .air.toml 关键配置

```toml
[build]
  # 关键：添加 sleep 10 模拟慢速构建
  # 这创造了一个时间窗口，让 Build B 可以在 Build A 期间被触发
  cmd = "... && sleep 10"
  
  # 不跳过未修改的文件，确保每次修改都触发构建
  exclude_unchanged = false
  
  # 不在错误时停止，以便清楚地看到竞态条件
  stop_on_error = false
```

### 为什么需要 sleep？

- **真实场景：** 在大型项目中，构建可能需要几秒到几十秒
- **Bug 触发条件：** 只有在第一个构建还在运行时触发第二个构建，才会出现竞态条件
- **sleep 作用：** 延长构建时间，给我们足够的时间手动触发第二个构建
- **真实性：** 这不是人为制造的 bug，而是真实场景下会发生的问题

---

## 🎯 验证清单 (Verification Checklist)

使用此清单确认你已成功复现 Bug：

- [ ] Air 正常启动，初始构建完成
- [ ] 触发 Build A（修改 main.go）
- [ ] 看到 "🔨 Build started at XX:XX:XX" 并记录时间
- [ ] 在 2-3 秒内触发 Build B（修改 helper.go）
- [ ] 看到第二个 "🔨 Build started at XX:XX:XX"
- [ ] **关键：** Build B 没有显示 "✅ Build complete"
- [ ] Build A 继续运行并完成
- [ ] 服务器启动显示 BUILD TIME 是 Build A 的时间
- [ ] `curl http://localhost:8080/version` 返回 Build A 的时间
- [ ] **确认：** helper.go 的修改没有反映在运行的程序中

如果以上所有项目都符合，说明你已成功复现 Bug #784！

---

## 📚 相关链接 (References)

- **GitHub Issue:** https://github.com/air-verse/air/issues/784
- **问题代码位置:** `air/runner/engine.go` lines 408-413, 422-432
- **提出者:** [@assembled-dylan](https://github.com/assembled-dylan)
- **发现日期:** 2025-07-23

---

## 💡 提示 (Tips)

1. **时机很重要：** 需要在第一个构建完成前（约 2-3 秒内）触发第二个构建
2. **观察日志：** 仔细观察 Air 的输出，特别注意哪些构建完成了，哪些没有
3. **多次尝试：** 如果第一次没有复现，可能是时机不对，多试几次
4. **清理环境：** 如果需要重新开始，删除 `tmp/` 目录并重启 Air
5. **端口占用：** 如果 8080 端口被占用，修改 main.go 中的端口号

---

## 🧹 清理 (Cleanup)

```bash
# 停止 Air (Ctrl+C)
# 删除临时文件
rm -rf tmp/

# 恢复文件到初始状态
git checkout main.go helper.go
# 或手动删除添加的注释
```

---

**Happy Bug Hunting! 🐛🔍**
