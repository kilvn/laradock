#!/usr/bin/env bash

cd /go/src/ && \
cd ./financial-master && go mod tidy && go run ./main.go
