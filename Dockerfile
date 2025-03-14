FROM node:20-alpine AS builder
LABEL authors="Lorenzo Feng"


RUN apk add --no-cache git

WORKDIR /app

COPY package.json pnpm-lock.yaml ./

RUN npm install -g pnpm

RUN pnpm install

COPY . .

RUN pnpm run build

FROM builder AS uploader


ARG USER
ARG TOKEN
ARG REPO_PATH

ENV USER=$USER
ENV TOKEN=$TOKEN
ENV REPO_PATH=$REPO_PATH

RUN git config --global user.name "Docker Build" && \
    git config --global user.email "docker@example.com"

RUN git clone "https://$USER:$TOKEN@atomgit.com/$REPO_PATH.git" --branch atom_pages --single-branch pages_deploy && \
    rm -rf pages_deploy/* && \
    cp -r dist/* pages_deploy/ && \
    cd pages_deploy && \
    git add . && \
    git commit -m "Deploy to Pages from Dockerfile" && \
    git push --force "https://$USER:$TOKEN@atomgit.com/$REPO_PATH.git" atom_pages

SHELL ["sh", "-c"]