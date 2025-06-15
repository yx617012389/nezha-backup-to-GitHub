#!/bin/bash

# === 配置项 ===
BACKUP_DIR="/opt/nezha"
GIT_REPO_DIR="/root/nezha-backup"
GIT_REMOTE="origin"
GIT_BRANCH="main"
GITHUB_REPO="github.com/你的用户名/nezha-backup.git"       # ⚠️ 替换为你的仓库地址
GITHUB_TOKEN="ghp_xxx你的GitHubToken"                       # ⚠️ 替换为你的 GitHub Token
MAX_DAYS=7

# === Telegram 配置 ===
TG_BOT_TOKEN="123456789:ABC-你的BotToken"                   # ⚠️ 替换为你的 Bot Token
TG_CHAT_ID="你的ChatID"                                     # ⚠️ 替换为你的 Chat ID

# === 发送 Telegram 通知函数 ===
send_telegram() {
  curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
    -d chat_id="$TG_CHAT_ID" \
    -d text="$1" \
    -d parse_mode="Markdown"
}

# 时间戳与归档名
TODAY=$(date +"%Y-%m-%d")
ARCHIVE_NAME="nezha-backup-$TODAY.tar.gz"

# 切换到仓库目录
mkdir -p "$GIT_REPO_DIR"
cd "$GIT_REPO_DIR" || exit 1

# 第一次初始化 Git 仓库
if [ ! -d ".git" ]; then
  git clone "https://$GITHUB_TOKEN@$GITHUB_REPO" .
fi

# 清理本地超期归档
find . -name "nezha-backup-*.tar.gz" -type f -mtime +$MAX_DAYS -exec rm -f {} \;

# 同步远程
git pull "$GIT_REMOTE" "$GIT_BRANCH"

# 清理 Git 超期归档记录
git ls-files | grep 'nezha-backup-.*\.tar\.gz' | while read -r file; do
  FILE_DATE=$(echo "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [[ $(date -d "$FILE_DATE" +%s) -lt $(date -d "$MAX_DAYS days ago" +%s) ]]; then
    git rm -f "$file"
  fi
done

# 创建新归档
tar -czf "$ARCHIVE_NAME" "$BACKUP_DIR"

# 提交并推送
git add "$ARCHIVE_NAME"
git commit -m "Backup on $TODAY"
if git push "$GIT_REMOTE" "$GIT_BRANCH"; then
  send_telegram "🎉 *Nezha 备份成功！"
else
  send_telegram "⚠️ *Nezha 备份失败！*"
fi
