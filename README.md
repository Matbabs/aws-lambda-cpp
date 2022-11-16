# AWS Lambda in C++

## Installs

### Build the AWS C++ SDK

[https://github.com/aws/aws-sdk-cpp](https://github.com/aws/aws-sdk-cpp)

```bash
cd ~
mkdir ~/install
git clone https://github.com/aws/aws-sdk-cpp.git
cd aws-sdk-cpp
mkdir build
cd build
cmake .. -DBUILD_ONLY="s3" \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_INSTALL_PREFIX=~/install
make && make install
```

**You can build the entire AWS SDK if you delete `-DBUILD_ONLY="s3"` from the command.**

> WARNING I had to do this before
>
> ```
> cd aws-sdk-cpp
> git checkout main
> git pull origin main
> git submodule update --init --recursive
> ```
>
> - Ubuntu 20.04.3 LTS x86_64
> - cmake version 3.16.3

### Build the Custom Runtime

```bash
cd ~
git clone https://github.com/awslabs/aws-lambda-cpp-runtime.git
cd aws-lambda-cpp-runtime
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
-DBUILD_SHARED_LIBS=OFF \
-DCMAKE_INSTALL_PREFIX=~/install
make && make install
```

## Deploy the lambda

`./lambda-cpp/deploy.sh -l <lambda_name> -p <aws_profile>`

### Resources

[https://aws.amazon.com/fr/blogs/compute/introducing-the-c-lambda-runtime/](https://aws.amazon.com/fr/blogs/compute/introducing-the-c-lambda-runtime)

[https://docs.aws.amazon.com/sdk-for-cpp/v1/developer-guide/basic-use.html](https://docs.aws.amazon.com/sdk-for-cpp/v1/developer-guide/basic-use.html)

[https://docs.aws.amazon.com/sdk-for-cpp/v1/developer-guide/examples-s3-objects.html](https://docs.aws.amazon.com/sdk-for-cpp/v1/developer-guide/examples-s3-objects.html)

[https://github.com/awslabs/aws-lambda-cpp/tree/master/examples/s3](https://github.com/awslabs/aws-lambda-cpp/tree/master/examples/s3)

[https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/cpp/example_code](https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/cpp/example_code)
