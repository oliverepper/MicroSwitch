#!/bin/bash

set -ex

if [ -d swift-protobuf ]
then
	pushd swift-protobuf
	git reset --hard 1.20.3
	popd
else	
	git -c advice.detachedHead=false clone --depth 1 --branch 1.20.3 https://github.com/apple/swift-protobuf.git
fi

pushd swift-protobuf
swift build -c release
popd

if [ -d grpc-swift ]
then
	pushd grpc-swift
	git reset --hard 1.5.0
	popd
else	
	git -c advice.detachedHead=false clone --depth 1 --branch 1.5.0 https://github.com/grpc/grpc-swift.git
fi

pushd grpc-swift
swift build -c release
popd

mkdir -p Sources/MicroSwitch/Model/generated &&
    protoc main.proto --swift_out=./Sources/MicroSwitch/Model/generated --grpc-swift_opt=Client=false,Server=true --grpc-swift_out=./Sources/MicroSwitch/Model/generated --plugin=./swift-protobuf/.build/release/protoc-gen-swift --plugin=./grpc-swift/.build/release/protoc-gen-grpc-swift &&
    echo "MicroSwitch done"


mkdir -p Sources/MicroClient/Model/generated &&
    protoc main.proto --swift_out=./Sources/MicroClient/Model/generated --grpc-swift_opt=Client=true,Server=false --grpc-swift_out=./Sources/MicroClient/Model/generated &&

#    protoc main.proto --swift_out=./Sources/MicroClient/Model/generated --grpc-swift_opt=Client=true,Server=false --grpc-swift_out=./Sources/MicroClient/Model/generated --plugin=./swift-protobuf/.build/release/protoc-gen-swift --plugin=./grpc-swift/.build/release/protoc-gen-grpc-swift &&
    echo "MicroClient done"
