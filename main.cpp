#include <aws/core/Aws.h>
#include <aws/core/platform/Environment.h>
#include <aws/core/client/ClientConfiguration.h>
#include <aws/core/utils/json/JsonSerializer.h>
#include <aws/s3/S3Client.h>
#include <aws/s3/model/GetObjectRequest.h>
#include <aws/s3/model/PutObjectRequest.h>
#include <aws/lambda-runtime/runtime.h>
#include <thread>

using namespace std;
using namespace Aws;
using namespace aws::lambda_runtime;
using namespace Aws::Utils::Json;

const string SSL_CERTIFICATE = "/etc/pki/tls/certs/ca-bundle.crt";

bool get_s3_object(Aws::S3::S3Client const s3_client, const Aws::String object, const Aws::String bucket, string &object_content);
bool put_s3_object(Aws::S3::S3Client const s3_client, const Aws::String object, const Aws::String bucket, const string object_content);
string process_content(const string object_content);

invocation_response handler(invocation_request const &req)
{
   JsonValue reqJson(req.payload);
   auto reqView = reqJson.View();
   auto body = reqView.GetString("body");
   JsonValue bodyJson(body);
   auto bodyView = bodyJson.View();
   if (!reqJson.WasParseSuccessful() || !bodyJson.WasParseSuccessful())
   {
      return invocation_response::failure("Failed to parse input JSON", "application/json");
   }

   Client::ClientConfiguration config;
   config.region = Aws::Environment::GetEnv("AWS_REGION");
   config.caFile = SSL_CERTIFICATE;
   S3::S3Client s3_client(config);

   auto files = bodyView.GetArray("files");
   Aws::String bucket = Aws::Environment::GetEnv("BUCKET_NAME");
   Aws::Utils::Array<Aws::String> presignedUrls(files.GetLength());

   auto thread_function = [&](int i) {
      auto fileView = files.GetItem(i);
      string object_content;
      Aws::String object_in = fileView.GetString("input");
      Aws::String object_out = fileView.GetString("output");
      if (get_s3_object(s3_client, object_in, bucket, object_content))
      {
         const string object_content_processed = process_content(object_content);
         if (put_s3_object(s3_client, object_out, bucket, object_content_processed))
         {
            presignedUrls[i] = s3_client.GeneratePresignedUrl(bucket, object_out, Aws::Http::HttpMethod::HTTP_GET, 60 * 5);
         }
      }
   };

   for (int i = 0; i < files.GetLength(); i++)
   {
      thread thread_object(thread_function, i);
      thread_object.join();
   }

   Aws::Utils::Json::JsonValue resp, headers, urls;
   headers.WithString("Access-Control-Allow-Origin", "*");
   urls.WithArray("presignedUrls", presignedUrls);
   resp.WithObject("headers", headers);
   resp.WithInteger("statusCode", 200);
   resp.WithString("body", urls.View().WriteCompact());
   return invocation_response::success(resp.View().WriteCompact(), "application/json");
}

int main()
{
   Aws::SDKOptions options;
   Aws::InitAPI(options);
   {
      run_handler(handler);
   }
   Aws::ShutdownAPI(options);
   return 0;
}

bool get_s3_object(Aws::S3::S3Client const s3_client, const Aws::String object, const Aws::String bucket, string &object_content)
{
   Aws::S3::Model::GetObjectRequest object_request;
   object_request.SetBucket(bucket);
   object_request.SetKey(object);

   Aws::S3::Model::GetObjectOutcome outcome = s3_client.GetObject(object_request);
   if (outcome.IsSuccess())
   {
      auto &retrieved_file = outcome.GetResultWithOwnership().GetBody();
      string line;
      while (getline(retrieved_file, line))
      {
         object_content = object_content.append(line + "\n");
      }
      return true;
   }
   return false;
}

bool put_s3_object(Aws::S3::S3Client const s3_client, const Aws::String object, const Aws::String bucket, const string object_content)
{
   const shared_ptr<Aws::IOStream> input_data = Aws::MakeShared<Aws::StringStream>("");
   *input_data << object_content.c_str();

   Aws::S3::Model::PutObjectRequest request;
   request.SetBucket(bucket);
   request.SetKey(object);
   request.SetBody(input_data);

   Aws::S3::Model::PutObjectOutcome outcome = s3_client.PutObject(request);
   return outcome.IsSuccess();
}

string process_content(const string object_content)
{
   string new_content;
   string delim = " ";
   auto start = 0U;
   auto end = object_content.find(delim);
   while (end != string::npos)
   {
      new_content.append(object_content.substr(start, end - start) + "\n");
      start = end + delim.length();
      end = object_content.find(delim, start);
   }
   new_content.append(object_content.substr(start, end) + "\n");
   return new_content;
}