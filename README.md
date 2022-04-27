# SRPC初步使用和说明

### 一. RPC介绍和SRPC说明

RPC是一种概念，表示远程过程调用，就是指能够让用户在本地调用远程的方法，调用透明，我们不需要知道调用的方法部署在什么地方。

SRPC目前是搜狗业务线上使用的企业级RPC系统，是一种RPC框架，具有以下的相关优势：

  * 底层基于[Sogou C++ Workflow](https://github.com/sogou/workflow)，兼具：
    * 高性能、低延迟、轻量级
    * 低开发和接入门槛
    * 完美兼容workflow的串并联任务流
    * 对于已有protobuf/thrift描述文件的项目，可以做到一键迁移
    * 支持Linux / MacOS / Windows等多操作系统
  * 支持多种IDL格式，包括：
    * Protobuf
    * Thrift
  * 支持多种数据布局，使用上完全透明，包括：
    * Protobuf serialize
    * Thrift Binary serialize
    * json serialize
  * 支持多种压缩，使用上完全透明，包括：
    * gzip
    * zlib
    * snappy
    * lz4
  * 支持多种通信协议，使用上完全透明，包括：
    * tcp
    * http
	* sctp
	* ssl
	* https
  * 用户可以通过http+json实现跨语言：
    * 如果自己是server提供方，用任何语言的http server接受post请求，解析若干http header即可
    * 如果自己是client调用方，用任何语言的http client发送post请求，添加若干http header即可
  * 内置了可以与其他RPC框架的server/client无缝互通的client/server，包括：
    * SRPC
    * BRPC
    * TRPC (目前唯一的TRPC协议开源实现)
    * Thrift Framed Binary
    * Thrift Http Binary
  * 兼容workflow的使用方式：
    * 提供创建任务的接口来创建一个rpc任务
    * 可以把rpc任务放到任务流图中，回调函数里也可以拿到当前的任务流
    * workflow所支持的其他功能，包括upstream、计算调度、异步文件IO等
  * AOP模块化插件管理：
    * 可对接[OpenTelemetry](https://opentelemetry.io)（tracing链路数据上报）
    * 轻松上报其他云原生系统
  * 支持srpc协议的Envoy-filter，满足Kubernetes用户的使用需求

### 二. 从零开始源码编译安装SRPC

SRPC依赖于Protobuf数据交换协议、Snappy数据压缩库、lz4和workflow等依赖，因此编译SRPC需要在系统中安装上述依赖库。下面进行各个库的安装教程。

#### 2.1. 安装Protobuf

```bash
# 克隆源码
git clone https://gitee.com/zhycheng/protobuf.git
# 编译
cd protobuf
git submodule update --init --recursive
chmod +x autogen.sh 
./autogen.sh
chmod +x configure
./configure
make -j32
make install
ldconfig
# 验证是否安装成功
protoc --version
```

#### 2.2. 安装workflow

```bash
# 克隆源码
git clone https://github.com/sogou/workflow.git
# 编译
cd workflow
mkdir build
cd build
cmake ..
make -j32
make install

```

#### 2.3. 安装lz4

```bash
# 克隆源码
git clone https://github.com/lz4/lz4.git
# 编译
cd lz4
mkdir build
cd build
cmake ..
make -j32
make install

```

#### 2.4. 安装snappy

```bash
# 克隆项目
git clone https://github.com/google/snappy.git
cd snappy
# 这里为了不进行test测试等操作以及规避编译中的bug
# 问题1：如果不关闭test测试，那么将会出现很多的需要适配第三方库的googletest等库
# 问题2：如果不编译动态库，那么后续SRPC使用的时候无法正确链接编译程序
# 问题3：如果编译lz4的动态库，那么将会出现"AdvanceToNextTagX86Optimized函数的inline错误"
# 为了解决问题3，在snappy.cc文本中这里把AdvanceToNextTagX86Optimized的前缀声明SNAPPY_ATTRIBUTE_ALWAYS_INLINE注释掉
sed -i "s/SNAPPY_ATTRIBUTE_ALWAYS_INLINE\nAdvanceToNextTagX86Optimized/AdvanceToNextTagX86Optimized/g" snappy.cc
# 进行编译
mkdir build
cd build
cmake -DSNAPPY_BUILD_BENCHMARKS=OFF -DSNAPPY_BUILD_TESTS=OFF -DBUILD_SHARED_LIBS=ON ..
make -j32
make install

```

#### 2.5. 安装SRPC

```bash
# 克隆项目
git clone  https://github.com/sogou/srpc.git
cd srpc
mkdir build
cd build
cmake ..
make -j32
make install
# 验证样例是否可以编译
cd ../tutorial
make -j32


```


### 三. 实践简单示例

#### 3.1. protobuf数据结构定义

下述内容存放在protofile/example.proto中
```protobuf
syntax = "proto3";//这里proto2和proto3都可以，srpc都支持

message EchoRequest {
    string message = 1;
    string name = 2;
};

message EchoResponse {
    string message = 1;
};

service Example {
    rpc Echo(EchoRequest) returns (EchoResponse);
};
```

#### 3.2. 服务程序和客户端程序代码如下

```c++
//服务端程序src/server.cc
#include <stdio.h>
#include <signal.h>
#include "example.srpc.h"

using namespace srpc;

class ExampleServiceImpl : public Example::Service
{
public:
    void Echo(EchoRequest *request, EchoResponse *response, RPCContext *ctx) override
    {
        response->set_message("Hi, " + request->name());
        printf("get_req:\n%s\nset_resp:\n%s\n",
                request->DebugString().c_str(), response->DebugString().c_str());
    }
};

void sig_handler(int signo) { }

int main()
{
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    SRPCServer server_tcp;
    SRPCHttpServer server_http;

    ExampleServiceImpl impl;
    server_tcp.add_service(&impl);
    server_http.add_service(&impl);

    server_tcp.start(1412);
    server_http.start(8811);
    getchar(); // press "Enter" to end.
    server_http.stop();
    server_tcp.stop();

    return 0;
}

```

```c++
//客户端程序src/client.cc
#include <stdio.h>
#include "example.srpc.h"

using namespace srpc;

int main()
{
    Example::SRPCClient client("127.0.0.1", 1412);
    EchoRequest req;
    req.set_message("Hello, srpc!");
    req.set_name("workflow");

    client.Echo(&req, [](EchoResponse *response, RPCContext *ctx) {
        if (ctx->success())
            printf("%s\n", response->DebugString().c_str());
        else
            printf("status[%d] error[%d] errmsg:%s\n",
                    ctx->get_status_code(), ctx->get_error(), ctx->get_errmsg());
    });

    getchar(); // press "Enter" to end.
    return 0;
}

```

#### 3.3. 编译命令

```bash
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
```

### 四. 实例演示结果

步骤三顺利结束后，我们将会在deploy中发现client和server可执行程序。

演示的时候我们需要用到三个演示终端，三个终端分别执行下述命令

- 终端1：

```bash

cd deploy
./server

```
```bash
# 该终端显示结果如下所示
get_req:
message: "Hello, srpc!"
name: "workflow"

set_resp:
message: "Hi, workflow"

get_req:
message: "from curl"
name: "CURL"

set_resp:
message: "Hi, CURL"

```

- 终端2：

```bash

cd deploy
./client

```
```bash
# 该终端显示结果如下所示
message: "Hi, workflow"
```

- 终端3：

```bash

curl 127.0.0.1:8811/Example/Echo -H 'Content-Type: application/json' -d '{message:"from curl",name:"CURL"}'

```
```bash
# 该终端显示结果如下所示
{"message":"Hi, CURL"}
```

至此，关于SRPC这种RPC框架，就可以完成了初步入门