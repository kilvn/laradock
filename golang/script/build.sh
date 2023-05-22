#!/usr/bin/env bash

cd /go/src/ && \
cd ./financial-master && git pull --no-rebase && go mod tidy && go run ./main.go
