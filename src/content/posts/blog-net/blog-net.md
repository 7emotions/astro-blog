---
title: AtomGit Pages 使用自定义域名
published: 2025-03-19
description: "采用nginx与caddy反向代理，为AtomGit Pages设置自定义域名"
image: ""
tags: [静态博客, nginx, caddy, 反向代理, 域名]
category: "建站"
draft: false
lang: ""
---

# 前置条件

1. 已经备案的域名
2. 已经配置Docker的云服务器

# 域名解析配置

为域名添加A记录，解析值为云服务器的IP地址。

# 云服务器配置

为云服务添加出站规则，开放`443`端口与`80`端口。

# `Caddy`配置

新建`Caddyfile`，并写入

```
yours.domain.com {
    reverse_proxy nginx:80
}
```

> [!NOTE]
> 请修改`yours.domain.com`为你的域名。

# `Nginx`配置

新建`nginx.conf`，并写入

```
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name yours.domain.com;

        location / {
            proxy_pass https://you.atomgit.net/your-blog/;
            proxy_set_header Host you.atomgit.net;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header User-Agent $http_user_agent;
            proxy_ssl_server_name on;
            proxy_ssl_protocols TLSv1.2 TLSv1.3;
            proxy_ssl_ciphers 'HIGH:!aNULL:!MD5';
        }
    }
}
```
> [!NOTE]
> 请修改`yours.domain.com`为你的域名，`you.atomgit.net`为你的AtomGit Pages的域名，`your-blog`为你的博客的目录。

# `Docker`配置

```yaml
version: '3.8'

services:
    nginx:
        container_name: blog-nginx
        image: nginx:latest
        ports:
            - "80:80" 
        volumes:
            - ./nginx.conf:/etc/nginx/nginx.conf
        networks:
            - blognetwork

    caddy:
        container_name: blog-caddy
        image: caddy:latest
        ports:
            - "443:443"
        volumes:
            - ./Caddyfile:/etc/caddy/Caddyfile
        networks:
            - blognetwork

networks:
  blognetwork:
```

# 构建容器

运行以下指令构建容器

```shell
docker-compose up -d
```

访问`https://yours.domain.com/`以查看博客。
