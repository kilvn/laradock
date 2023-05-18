FROM golang:latest
MAINTAINER  逆天西瓜

# 安装 ssh 和 git 工具
RUN apt-get update && \
    apt-get install -y openssh-client git

# 在 GitLab 中生成个人访问令牌，私有库认证
ARG GITLAB_PERSONAL_ACCESS_TOKEN
RUN git config --global credential.helper '!f() { echo "username=oauth2" ; echo "password=$GITLAB_PERSONAL_ACCESS_TOKEN" ; }; f'

CMD ["/bin/bash", "/go/script/build.sh"]

EXPOSE 80 8010 8011
