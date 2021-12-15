#!/bin/sh

swift build -c release

mkdir -p bin
BIN_PATH=$(swift build -c release --show-bin-path)
cp $BIN_PATH/mswitch bin/
cp $BIN_PATH/mclient bin/
