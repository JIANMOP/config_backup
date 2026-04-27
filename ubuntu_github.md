# Ubuntu 22.04 GitHub SSH 配置与 Git 命令大全
本文涵盖SSH 密钥配置、本地仓库关联 GitHub、代码提交推送、分支管理全套命令，适配 Ubuntu 22.04 系统
## 一、SSH 密钥配置（仅首次操作）
1. 生成 SSH 密钥
替换为GitHub 注册邮箱，全程回车（不设置密钥密码）
```bash
ssh-keygen -t ed25519 -C "你的GitHub注册邮箱"
```

2. 启动 SSH 代理并添加私钥
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

3. 复制公钥（粘贴到 GitHub）
```bash
# 输出公钥全文，复制所有内容
cat ~/.ssh/id_ed25519.pub
```

4. GitHub 添加公钥

    GitHub 右上角头像 → Settings → SSH and GPG keys
    点击New SSH key，Title 填写设备名（如 Ubuntu22.04）
    粘贴复制的公钥，点击Add SSH key

5. 测试 SSH 连接
```bash
ssh -T git@github.com
```

提示yes/no输入yes，出现成功认证提示即配置完成。

## 二、Git 全局配置（仅首次操作）
配置 GitHub 用户名和邮箱，所有仓库通用
```bash
git config --global user.name "GitHub用户名"
git config --global user.email "GitHub注册邮箱"
```

## 三、本地仓库同步 GitHub（核心流程）
1. 新建本地仓库
进入项目文件夹，初始化 Git 仓库
```bash
# 进入项目目录（替换为你的项目路径）
cd 项目文件夹路径
# 初始化本地Git仓库
git init
```

2. 关联 GitHub 远程仓库

    GitHub 网页新建空仓库（不勾选 README、LICENSE）
    复制仓库 SSH 地址（格式：git@github.com:用户名/仓库名.git）
    本地执行关联命令：

```bash
git remote add origin git@github.com:用户名/仓库名.git
```

3. 首次提交并推送主分支
```bash
# 暂存所有文件
git add .
# 提交代码（自定义提交备注）
git commit -m "初始化仓库"
# 重命名主分支为main（GitHub默认分支）
git branch -M main
# 首次推送并绑定上游分支
git push -u origin main
```

4. 后续常规提交推送
绑定上游分支后，无需额外参数，直接执行：
```bash
# 暂存文件
git add .
# 提交代码
git commit -m "本次更新备注"
# 推送至GitHub
git push
```

5. 已有 HTTPS 仓库切换为 SSH
```bash
# 查看当前远程地址
git remote -v
# 移除原有HTTPS远程地址
git remote remove origin
# 重新添加SSH远程地址
git remote add origin git@github.com:用户名/仓库名.git
```

## 四、分支管理全套命令
1. 查看分支
```bash
# 查看本地分支
git branch
# 查看本地+远程所有分支
git branch -a
```

2. 新建并切换分支
```bash
# 创建新分支并自动切换（替换为分支名，如dev）
git checkout -b 分支名
```

3. 切换已有分支
```bash
git checkout 分支名
```

4. 新分支首次推送 GitHub
```bash
# 新分支首次推送，绑定上游分支
git push -u origin 分支名
```

5. 新分支后续推送
```bash
git push
```

6. 删除本地分支
```bash
git branch -d 分支名
```

7. 删除远程分支
```bash
git push origin --delete 分支名
```

8. 合并分支（例：dev 合并到 main）
```bash
# 切换到主分支
git checkout main
# 合并dev分支到main
git merge 分支名
# 推送合并结果到GitHub
git push
```

## 五、常用辅助命令
1. 查看 Git 状态
```bash
git status
```

2. 查看提交日志
```bash
git log
```

3. 拉取 GitHub 远程最新代码
```bash
git pull
```

4. 取消文件暂存
```bash
git reset 文件名
# 取消所有文件暂存
git reset .
```

5. 撤销最近一次提交（保留代码）
```bash
git reset --soft HEAD^
```

## 六、LazyGit 可视化操作（替代命令）
无需记命令，可视化完成所有 Git 操作
```bash
# 启动LazyGit（进入Git仓库目录执行）
lazygit
```

核心快捷键：

    空格：暂存文件
    c：提交代码
    Shift+P：推送代码
    p：拉取代码
    b：分支管理
    n：新建分支
    q：退出 LazyGit


# GitHub 仓库改名教程（远程仓库名 \+ 本地文件夹 \+ Git地址 全套修改）

一次性改好：**GitHub网页仓库名** \+ **本地文件夹名** \+ **Git远程连接地址**，SSH正常使用，不用重新配置密钥。

---

## 一、第一步：网页修改 GitHub 远程仓库名

1. 打开你的 GitHub 仓库主页

2. 下滑找到 **Settings（设置 ⚙️）**

3. 最上方 **Repository name** 修改成新仓库名

4. 点 **Rename** 确认改名

> 改名后 GitHub 自动跳转，不用重新配置 SSH。
> 
> 新仓库 SSH 地址格式：`git@github\.com:你的用户名/新仓库名\.git`
> 
> 

---

## 二、第二步：本地修改仓库文件夹名称

终端执行（把名字换成你自己的）：

```bash
# 先退出仓库目录
cd ~

# 修改本地文件夹名 旧仓库名 → 新仓库名
mv 旧仓库名 新仓库名

# 进入改名后的新文件夹
cd 新仓库名

```

---

## 三、第三步：修改本地 Git 远程关联地址（最重要）

```bash
# 查看当前旧远程地址（确认一下）
git remote -v

# 修改为新仓库 SSH 地址（替换成你自己的用户名和新仓库名）
git remote set-url origin git@github.com:你的用户名/新仓库名.git

# 检查是否修改成功
git remote -v

```

看到显示**新仓库名**就改好了。

---

## 四、第四步：测试是否正常推拉

```bash
# 测试拉取（不报错就成功）
git pull

# 随便改点东西测试推送
git add .
git commit -m "改名完成测试"
git push

```

---

## 五、LazyGit 使用说明

改名之后直接进入新文件夹正常使用：

```bash
lazygit

```

**不需要任何额外配置，直接正常提交、推送、分支都能用。**

---

