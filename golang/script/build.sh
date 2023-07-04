#!/usr/bin/env bash

cd /go/src/financial-data-center && git pull --no-rebase && go mod tidy && nohup go run ./main.go 2>&1 &

echo 'financial-data-center started.'

cd /go/src/financial-master && git pull --no-rebase && go mod tidy && go run ./main.go
