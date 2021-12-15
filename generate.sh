#!/bin/sh

mkdir -p Sources/MicroSwitch/Model/generated &&
    protoc main.proto --swift_out=./Sources/MicroSwitch/Model/generated --grpc-swift_opt=Client=false,Server=true --grpc-swift_out=./Sources/MicroSwitch/Model/generated &&
    echo "MicroSwitch done"


mkdir -p Sources/MicroClient/Model/generated &&
    protoc main.proto --swift_out=./Sources/MicroClient/Model/generated --grpc-swift_opt=Client=true,Server=false --grpc-swift_out=./Sources/MicroClient/Model/generated &&
    echo "MicroClient done"
