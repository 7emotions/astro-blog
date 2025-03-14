---
title: 国内自动化静态博客搭建
published: 2025-03-14
description: "采用Github Action向AtomGit部署Fuwari静态博客"
image: "images/blog-guide/1.png"
tags: [静态博客, Github Action, Fuwari]
category: "建站"
draft: false
lang: ""
---

# 前言

最近在搭建静态博客，发现国内访问`Github Pages`的速度很慢，于是想通过国内的服务器来部署静态博客。经过一番搜索，发现`AtomGit`是一个很好的选择，它支持`Pages`服务，并且在国内有较好的访问速度。

# 准备

##  AtomGit

[AtomGit](https://atomgit.com/)是国内由开放原子基金会运营的`Git`托管平台，它支持`Pages`服务，并且具有良好的访问速度。

你需要先在`AtomGit`上注册一个账号，并创建一个仓库，用于部署静态博客的站点构建文件。并且，该仓库需要开启`Pages`服务。参考[AtomGit Pages](https://docs.atomgit.com/app/pageshelp)。

> 开启Pages服务后，AtomGit会自动为你的仓库分配一个uri，例如`https://<username>.atomgit.net/<repo-name>`。你可以通过这个url来访问你的静态博客。

## Github

你需要一个`Github`账号，并且需要创建一个仓库，用于存放静态博客的源文件。这个仓库不需要开启`Pages`服务。从该仓库中，你可以通过`Github Action`来生成静态博客的站点文件，并将其部署到`AtomGit`上。

## Node.js （可选）

`Node.js` 是`Astro`的运行环境，你需要安装`Node.js 20`。你可以从[Node.js官网](https://nodejs.org/)下载并安装。

# 开始

## 1. Fork Fuwari

首先，你需要Fork [Fuwari](https://github.com/saicaca/fuwari) 到你的Github账号下。`Fuwari`是基于[Astro](https://astro.build/)的静态博客模板。


:sparkle: 功能特性
- [x] 基于 `Astro` 和 `Tailwind CSS` 开发
- [x] 流畅的动画和页面过渡
- [x] 亮色 / 暗色模式
- [x] 自定义主题色和横幅图片
- [x] 响应式设计
- [ ] 评论
- [x] 搜索
- [ ] 文内目录

## 2. 修改配置文件

你可以通过配置文件 `src/config.ts` 自定义博客。以我的配置文件为例。

```ts
import type {
  LicenseConfig,
  NavBarConfig,
  ProfileConfig,
  SiteConfig,
} from './types/config'
import { LinkPreset } from './types/config'

export const siteConfig: SiteConfig = {
  title: 'Lorenzo Feng',
  subtitle: 'Blog Site',
  lang: 'zh_CN',         // 'en', 'zh_CN', 'zh_TW', 'ja', 'ko', 'es', 'th'
  themeColor: {
    hue: 250,         // Default hue for the theme color, from 0 to 360. e.g. red: 0, teal: 200, cyan: 250, pink: 345
    fixed: false,     // Hide the theme color picker for visitors
  },
  banner: {
    enable: true,
    src: 'assets/images/demo-banner.png',   // Relative to the /src directory. Relative to the /public directory if it starts with '/'
    position: 'center',      // Equivalent to object-position, only supports 'top', 'center', 'bottom'. 'center' by default
    credit: {
      enable: false,         // Display the credit text of the banner image
      text: '',              // Credit text to be displayed
      url: ''                // (Optional) URL link to the original artwork or artist's page
    }
  },
  toc: {
    enable: true,           // Display the table of contents on the right side of the post
    depth: 2                // Maximum heading depth to show in the table, from 1 to 3
  },
  favicon: [    // Leave this array empty to use the default favicon
    // {
    //   src: '/favicon/icon.png',    // Path of the favicon, relative to the /public directory
    //   theme: 'light',              // (Optional) Either 'light' or 'dark', set only if you have different favicons for light and dark mode
    //   sizes: '32x32',              // (Optional) Size of the favicon, set only if you have favicons of different sizes
    // }
  ]
}

export const navBarConfig: NavBarConfig = {
  links: [
    LinkPreset.Home,
    LinkPreset.Archive,
    LinkPreset.About,
    {
      name: 'GitHub',
      url: 'https://github.com/7emotions/astro-blog/',     // Internal links should not include the base path, as it is automatically added
      external: true,                               // Show an external link icon and will open in a new tab
    },
  ],
}

export const profileConfig: ProfileConfig = {
  avatar: 'assets/images/demo-avatar.png',  // Relative to the /src directory. Relative to the /public directory if it starts with '/'
  name: 'Lorenzo Feng',
  bio: 'An algorithm engineer of Alliance, NJUST',
  links: [
    {
        name: 'Telegram',
        icon: 'logos:telegram',
        url: 'https://t.me/lorenzofeng'
    },
    {
      name: 'QQ',
      icon: 'mdi:qqchat',
      url: 'https://qm.qq.com/q/gszht217Fu',
    },
    {
      name: 'GitHub',
      icon: 'fa6-brands:github',
      url: 'https://github.com/7emotions',
    },
  ],
}

export const licenseConfig: LicenseConfig = {
  enable: true,
  name: 'CC BY-NC-SA 4.0',
  url: 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
}

```

## 3. 创建文章

`Astro`框架是基于`Markdown`的，所以你可以在`src/content/posts/`目录中创建新的`Markdown`文件，编辑文章内容。 你也可以在终端中执行 `pnpm new-post <filename>` 创建新文章，并在` src/content/posts/ `目录中编辑。

**文章头格式**如下

```markdown
---
title: My First Blog Post //文章标题
published: 2023-09-09 //文章发布日期
description: This is the first post of my new Astro blog.  //文章描述
image: ./cover.jpg  //这是文章封面，路径可以是相对路径，也可以是绝对路径
tags: [Foo, Bar] //文章标签
category: Front-end //文章分类
draft: false //是否为草稿
lang: jp      //仅当文章语言与 `config.ts` 中的网站语言不同时需要设置
---

```

## 4. 本地构建（可选）

安装依赖

``` shell
npm install -g pnpm
pnpm install && pnpm add sharp
```

运行以下命令，可以在本地[https://localhost:4321/](https://localhost:4321/)预览博客
```shell
pnpm dev
```

构建博客

```shell
pnpm run build
```


## 5. 部署

修改在根目录下的 `astro.config.mjs` 

```js
export default defineConfig({
    site: "https://7emotions.atomgit.net", // <username>.atomgit.net
    base: "/blog", // <repo-name>
    trailingSlash: "always"
    // ...
})
```
将 `base` 修改为你的仓库名称，将 `site` 修改为你的用户名。例如，如果你的用户名是 `lorenzofeng`，仓库名称是 `blog`，那么 `base` 应该是 `/blog`，`site` 应该是 `https://lorenzofeng.atomgit.net`。

在根目录新建 `.github/workflows/astro.yml`， 并写入以下内容

```yaml
name: Deploy to AtomGit Pages

on:
  push:
    branches: [main] # 修改为Github源码仓库的分支名
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deployment:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout your repository using git
        uses: actions/checkout@v4
        with:
          ref: main # 修改为Github源码仓库的分支名
      - name: Setup node
        uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install dependence
        run: |
          npm install -g pnpm
          pnpm install
          pnpm add sharp
      - name: Build dist
        run: pnpm run build
      - name: Publish branch
        uses: 7emotions/branch-pub@v4
        with:
          token: ${{ secrets.ATOM_TOKEN }} 
          user: 7emotions # 修改为你的AtomGit用户名
          repo: 7emotions/blog # 修改为AtomGit的仓库路径
          github_domain: atomgit.com
          branch: pages # 要部署的分支名称
          folder: dist 
```

在`AtomGit`的[**访问令牌**](https://atomgit.com/-/profile/tokens)中创建个人令牌（`Personal Access Token`），权限为`repo`。

在`Github`仓库`Settings`中，找到`Secrets and variables`，选择`Action`。点击`New repository secret`，添加`ATOM_TOKEN`，值为你的`AtomGit`的`Personal Access Token`。

推送代码到`Github`仓库，等待`Github Action`执行完成，即可在`AtomGit`上看到新发布的分支。

在`AtomGit`的仓库中，点击设置->`Pages`，选择`pages`分支，即可在`https://<username>.atomgit.net/<repo-name>`访问你的博客。

# 参考

- [新一代静态博客框架Astro的部署优化指南与使用体验](https://www.lapis.cafe/posts/technicaltutorials/%E6%96%B0%E4%B8%80%E4%BB%A3%E9%9D%99%E6%80%81%E5%8D%9A%E5%AE%A2%E6%A1%86%E6%9E%B6astro%E7%9A%84%E9%83%A8%E7%BD%B2%E4%BC%98%E5%8C%96%E6%8C%87%E5%8D%97%E4%B8%8E%E4%BD%BF%E7%94%A8%E4%BD%93%E9%AA%8C/)
- [AtomGit Pages](https://docs.atomgit.com/app/pageshelp)

