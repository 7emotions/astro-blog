---
title: 国内静态博客一键部署
published: 2025-03-14
description: "Docker或Github Action一键部署Fuwari静态博客"
image: "images/blog-guide/1.png"
tags: [静态博客, Github Action, Fuwari，Docker]
category: "建站"
draft: false
lang: ""
---

# 前言

手动部署以及博客配置参考[国内自动化静态博客搭建](../blog-guide/)。


# 准备

##  AtomGit

[AtomGit](https://atomgit.com/)是国内由开放原子基金会运营的`Git`托管平台，它支持`Pages`服务，并且具有良好的访问速度。

1. **一个账号与一个空仓库**

你需要先在`AtomGit`上注册一个账号，并创建一个**空仓库**，用于部署静态博客的站点构建文件。

2. **Pages服务申请**

该仓库需要开启`Pages`服务。参考[AtomGit Pages](https://docs.atomgit.com/app/pageshelp)。

- [点击此处申请Pages服务](https://atomgit.com/atomgit_operate/feedback/issues/create?name=3.Apply_Pages&dirType=1&page=issueTemplate)
- [点击此处安装Pages应用](https://atomgit.com/marketplace/pages?ref_app_id=4005817059772432)

> 开启Pages服务后，AtomGit会自动为你的仓库分配一个uri，例如`https://<username>.atomgit.net/<repo-name>`。你可以通过这个url来访问你的静态博客。

3. **访问令牌**

你需要创建一个访问令牌（`Personal Access Token`，`PAT`），用于`Github Action`访问你的仓库。[点击此处生成](https://atomgit.com/-/profile/tokens)。

> **注意**: 访问令牌需要勾选`repo`权限，否则`Github Action`无法访问你的仓库。

## Github

1. **一个账号**
你需要一个`Github`账号，并且需要创建一个仓库，用于存放静态博客的源文件。这个仓库不需要开启`Pages`服务。从该仓库中，你可以通过`Github Action`来生成静态博客的站点文件，并将其部署到`AtomGit`上。


# Github Action 部署

## 1. Fork 7emotions/Fuwari

首先，你需要Fork 我的[Fuwari](https://github.com/7emotions/fuwari) 到你的Github账号下。

- [如何Fork仓库](https://docs.github.com/zh/get-started/quickstart/fork-a-repo)

## 2. 配置Secret
在Fork后的仓库中，点击`Settings`，然后点击`Secrets and variables`，选择`Actions`，点击`New repository secret`，添加以下三个`Secret`。

- `TOKEN`：AtomGit的访问令牌(`PAT`)，用于`Github Action`访问你的AtomGit仓库。
- `USER`：AtomGit的用户名，用于`Github Action`访问你的AtomGit仓库。
- `REPO`：AtomGit的仓库名，用于`Github Action`访问你的AtomGit仓库。

> 例如，我的AtomGit仓库的uri为`https://atomgit.com/<username>/<repo-name>`，那么`USER`为`<username>`，`REPO`为`<repo-name>`。

## 3. 启用Actions

在`Github`仓库中，点击`Actions`，选择`Deploy Pages`，点击`Run workflow`，选择分支为`main`，点击`Run workflow`。

![alt text](images/onetap/1.png)

刷新页面，可以看到`Github Action`正在运行。

![alt text](images/onetap/2.png)

约莫1分钟后，出现如下提示，说明`Github Action`运行完成。

![alt text](images/onetap/3.png)

当`Github Action`运行完成后，你可以访问`https://<username>.atomgit.net/<repo-name>`查看你的静态博客。

> 例如，我的AtomGit仓库的uri为`https://atomgit.com/7emotions/blog`，那么我的静态博客的访问地址为`https://7emotions.atomgit.net/blog`。

# Docker 部署

## 1. Fork 7emotions/Fuwari

首先，你需要Fork 我的[Fuwari](https://github.com/7emotions/fuwari) 到你的Github账号下。

- [如何Fork仓库](https://docs.github.com/zh/get-started/quickstart/fork-a-repo)

## 2. Clone 仓库

在本地，使用`git clone`命令克隆你的Fork仓库。

```bash
git clone https://github.com/<username>/fuwari.git
```

## 3. 配置环境变量

在`fuwari`目录下，创建一个`.env`文件，并添加以下内容。

```bash
TOKEN=<AtomGit-Token>
USER=<username>
REPO=<repo-name>
GIT_DOMAIN=atomgit.com
BRANCH=pages
```

> 文中`<AtomGit-Token>`、`<username>`、`<repo-name>`分别代表AtomGit的访问令牌(`PAT`)、AtomGit的用户名、AtomGit的仓库名。


## 4. 构建与运行

在`fuwari`目录下，使用以下命令构建与运行。

```bash
docker-compose up -d
```

## 5. 访问博客

当`Docker`容器运行完成后，你可以访问`https://<username>.atomgit.net/<repo-name>`查看你的静态博客。

# 博文发布

无论是`Github Action`部署还是`Docker`部署，每次向远端推送博文，会自动触发`Github Action`，生成静态博客的站点文件，并将其部署到`AtomGit`上。