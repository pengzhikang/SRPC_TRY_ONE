#代码生成
cd protofile
protoc example.proto --cpp_out=./ --proto_path=./
cd ..
srpc_generator protobuf protofile/example.proto ./
mv protofile/*.cc src
mv protofile/*.h include
mv *.cc src/
mv *.h include/

# 示例编译
# g++ -o server src/server.cc src/example.pb.cc -std=c++11 -lsrpc -I include
# g++ -o client src/client.cc src/example.pb.cc -std=c++11 -lsrpc -I include
if [ ! -d "./deploy" ]; then
	mkdir deploy
fi
if [ ! -d "./build" ]; then
	mkdir build
fi
# 客户端应用
cd build
rm -rf *
cmake ..
make -j32
cd ..
cp build/release/test deploy/client

cd build
rm -rf *
cmake -DBuild_Client=OFF ..
make -j32
cd ..
cp build/release/test deploy/server
