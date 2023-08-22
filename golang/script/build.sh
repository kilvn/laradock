#!/usr/bin/env bash

# 修复Windows下的 0500 too open 权限错误问题
chmod 400 /root/.ssh/id_rsa

cd /go/src/financial-data-center && git pull --no-rebase && go mod tidy && nohup go run ./main.go 2>&1 &

echo 'financial-data-center started.'

cd /go/src/financial-master && git pull --no-rebase && go mod tidy && go run ./main.go
