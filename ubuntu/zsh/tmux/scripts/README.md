# 具体用法见 ~/.tmux.conf
```bash
# tmp
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux source ~/.tmux.conf
Ctrl+s   # 松开后按 I（大写 i）

mkdir -p ~/.config/tmux/scripts
cp *.sh ~/.config/tmux/scripts
chmod +x ~/.config/tmux/scripts/*.sh
```
