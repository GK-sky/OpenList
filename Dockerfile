# 基础镜像标签参数，支持 base(默认)、aria2、ffmpeg、aio
ARG BASE_IMAGE_TAG=base

# 第一阶段：Go 应用编译阶段
FROM alpine:edge AS builder
LABEL stage=go-builder
WORKDIR /app/
# 安装编译依赖
RUN apk add --no-cache bash curl jq gcc git go musl-dev
# 复制 Go 模块依赖文件并下载
COPY go.mod go.sum ./
RUN go mod download
# 复制项目所有文件
COPY ./ ./
# 执行编译脚本
RUN bash build.sh release docker

# 第二阶段：应用运行阶段
FROM openlistteam/openlist-base-image:${BASE_IMAGE_TAG}
# 维护者信息：关联你的 GitHub 仓库
LABEL MAINTAINER="GK-sky <https://github.com/GK-sky/OpenList>"
# 可选组件安装参数
ARG INSTALL_FFMPEG=false
ARG INSTALL_ARIA2=false
# 运行用户及权限参数
ARG USER=openlist
ARG UID=1001
ARG GID=1001

# 设置应用工作目录
WORKDIR /opt/openlist/

# 创建用户组和用户，避免 root 运行
RUN addgroup -g ${GID} ${USER} && \
    adduser -D -u ${UID} -G ${USER} ${USER} && \
    mkdir -p /opt/openlist/data

# 从编译阶段复制编译好的应用程序（设置权限）
COPY --from=builder --chmod=755 --chown=${UID}:${GID} /app/bin/openlist ./
# 复制入口脚本（设置权限）
COPY --chmod=755 --chown=${UID}:${GID} entrypoint.sh /entrypoint.sh

# 切换到非 root 用户
USER ${USER}
# 验证版本（非必需，用于确认应用可执行）
RUN /entrypoint.sh version

# 环境变量配置
ENV UMASK=022 RUN_ARIA2=${INSTALL_ARIA2}
# 数据卷：用于持久化存储
VOLUME /opt/openlist/data/
# 暴露应用端口
EXPOSE 5244 5245
# 容器启动命令
CMD [ "/entrypoint.sh" ]
