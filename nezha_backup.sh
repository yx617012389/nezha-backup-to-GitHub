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
