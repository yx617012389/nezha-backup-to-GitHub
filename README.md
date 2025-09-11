# **此脚本为 Nezha面板v1 每日自动备份到 GitHub 并通过 Telegram 通知**

操作环境：Debian11 VPS (nezha非docker安装)
> **目标**：每天早上 6:00（北京时间）自动  
> 1. 打包 `/opt/nezha` 为 `.tar.gz`  
> 2. 上传到 GitHub 仓库  
> 3. 自动清理 7 天前的旧备份  
> 4. 通过 Telegram Bot 推送成功/失败通知 

## 第一步：准备工作

### 1. 安装所需软件

```bash
sudo apt update
sudo apt install git zip curl -y
```

### 2. 获取 GitHub Token 并新建仓库

1. 打开 [https://github.com/settings/tokens](https://github.com/settings/tokens)
2. 创建一个  **Classic Token**
3. 勾选权限：✅ `repo`
4. 复制 Token（如：`ghp_xxxxxxxxxxxxxxxxxxxxxxxx`）
5. 新建一个仓库，命名为 `nezha-backup`（建议私有）

### 3. 获取 Telegram Bot Token 和 Chat ID

#### 创建 Telegram Bot：

1. 搜索 `@BotFather`，发送 `/newbot`
2. 设置名称和用户名，获取 Bot Token

#### 获取 Chat ID：

1. 给你的 Bot 发一条消息
2. 访问：

```
https://api.telegram.org/bot<你的BotToken>/getUpdates
```

3. 找到 `"chat":{"id":xxxxx,...}`，这个 `id` 就是 Chat ID

---

## 第二步：创建备份脚本

### 1. 创建脚本文件

```bash
vim /root/nezha_backup.sh
```

### 2. 粘贴以下内容（⚠️ 替换标注内容）

```bash
#!/bin/bash

### ====== 需要修改的地方 ======
GITHUB_USER="XXXXX"        # 修改成你的 GitHub 用户名
GITHUB_REPO="nezha-backup"       # 修改成你的仓库名
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxx"  # 修改成你的 GitHub Token（需要有 repo 权限）
BOT_TOKEN="XXXXX:XXXXXXXXXX"   # 修改成你的 Telegram Bot Token
CHAT_ID="XXXXX"             # 修改成你的 Telegram Chat ID
BACKUP_DIR="/opt/nezha"          # Nezha 安装路径
KEEP_DAYS=7                      # 保留天数（超过就自动删除）
### ====== 后面还有两处需要修改的地方 ======


WORKDIR="/root/nezha-backup"
DATE=$(date +%F)
TARFILE="nezha-backup-$DATE.tar.gz"

send_telegram() {
    local msg="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=Markdown" \
        -d "text=${msg}" >/dev/null
}

echo "[INFO] 初始化仓库..."
if [ ! -d "$WORKDIR/.git" ]; then
    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"
    git clone "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git" "$WORKDIR" || {
        send_telegram "⚠️ *Nezha 备份失败*：无法克隆仓库"
        exit 1
    }
    cd "$WORKDIR" || exit 1
    git config user.name "$GITHUB_USER"
    git config user.email "${GITHUB_USER}@users.noreply.github.com"

    # 检查仓库是否为空
    if [ -z "$(ls -A "$WORKDIR")" ]; then
        echo "# Nezha Backup Repo" > README.md
        git add README.md
        git commit -m "init repo"
        git branch -M main
        git push -u origin main
        echo "[INFO] 已完成 GitHub 仓库初始化"
    fi
else
    cd "$WORKDIR" || exit 1
    git pull origin main >/dev/null 2>&1 || true
fi

echo "[INFO] 打包 $BACKUP_DIR..."
tar --warning=no-file-changed -czf "/tmp/$TARFILE" -C "$BACKUP_DIR" . || {
    send_telegram "⚠️ *Nezha 备份失败*：打包错误"
    exit 1
}
mv "/tmp/$TARFILE" "$WORKDIR/"

git add .

# 删除超过 KEEP_DAYS 的旧备份
echo "[INFO] 删除超过 $KEEP_DAYS 天的旧备份..."
find "$WORKDIR" -name "nezha-backup-*.tar.gz" -type f -mtime +$KEEP_DAYS -exec git rm -f {} \; >/dev/null 2>&1

# 提交并推送（只有变更时才提交）
if git diff --cached --quiet; then
    echo "[INFO] 没有新的备份文件需要提交"
else
    git commit -m "Backup on $DATE"
    git push origin main || {
        send_telegram "⚠️ *Nezha 备份失败*：推送错误"
        exit 1
    }
    send_telegram "🎉 *Nezha 备份成功！* 已保存：$DATE，已自动清理超过 ${KEEP_DAYS} 天的旧备份"
    echo "[INFO] 备份成功"
fi
```

---

## 第三步：设置权限

```bash
chmod +x /root/nezha_backup.sh
```

---

## 第四步：添加定时任务（每天北京时间早上 6 点）

```bash
crontab -e
```

添加以下内容（凌晨 3 点 ）：

```cron
0 3 * * * env -i HOME=/root /bin/bash /root/nezha_backup.sh >/dev/null 2>&1
```

保存并退出（vim：:wq；nano：Ctrl+O → Ctrl+X）

---

## 第五步：手动测试

手动运行
```bash
bash /root/nezha_backup.sh
```

假装corn运行
```bash
env -i /bin/bash -c 'HOME=/root /bin/bash /root/nezha_backup.sh'
```


✔️ 检查点
GitHub 仓库出现 nezha-backup-YYYY-MM-DD.tar.gz
Telegram 收到「备份成功」通知
