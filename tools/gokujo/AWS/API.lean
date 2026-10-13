-- API.lean
-- Formal model of AWS API endpoints

import AWS.Types

namespace AWS
namespace API

-- ============================================
-- API Configuration
-- ============================================

-- AWS API base URLs by service
def getServiceUrl : Types.Service → String
  | .S3 => "https://s3.amazonaws.com"
  | .EC2 => "https://ec2.amazonaws.com"
  | .Lambda => "https://lambda.amazonaws.com"
  | .DynamoDB => "https://dynamodb.amazonaws.com"
  | .SQS => "https://sqs.amazonaws.com"
  | .SNS => "https://sns.amazonaws.com"
  | .CloudFormation => "https://cloudformation.amazonaws.com"
  | .IAM => "https://iam.amazonaws.com"
  | .STS => "https://sts.amazonaws.com"
  | .CloudWatch => "https://monitoring.amazonaws.com"
  | .CloudWatchLogs => "https://logs.amazonaws.com"
  | .ECR => "https://ecr.amazonaws.com"
  | .EKS => "https://eks.amazonaws.com"
  | .RDS => "https://rds.amazonaws.com"
  | .Route53 => "https://route53.amazonaws.com"
  | .API_Gateway => "https://apigateway.amazonaws.com"
  | .StepFunctions => "https://states.amazonaws.com"
  | .SecretsManager => "https://secretsmanager.amazonaws.com"
  | .ParameterStore => "https://ssm.amazonaws.com"

-- AWS API configuration
structure AWSConfig where
  region      : Types.Region
  accessKeyId : Option Types.AccessKeyId
  secretAccessKey : Option Types.SecretAccessKey
  sessionToken : Option Types.SessionToken
  
-- ============================================
-- API Endpoint Types
-- ============================================

-- API endpoint path
def EndpointPath := String

-- API endpoint with method
def Endpoint where
  method : String  -- "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD"
  path   : EndpointPath
  service : Types.Service
  
-- ============================================
-- S3 API Endpoints
-- ============================================

-- List buckets
def s3ListBucketsEndpoint : Types.Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .S3
  }

-- Get bucket location
def s3GetBucketLocationEndpoint : Types.S3BucketName → Endpoint := fun bucket =>
  { method := "GET"
  , path := "/" ++ bucket ++ "?location"
  , service := .S3
  }

-- List objects
def s3ListObjectsEndpoint : Types.S3BucketName → Option String → Endpoint :=
  fun bucket prefix =>
  { method := "GET"
  , path := "/" ++ bucket ++ "?list-type=2" ++ 
            (match prefix with | some p => "&prefix=" ++ p | none => "")
  , service := .S3
  }

-- Get object
def s3GetObjectEndpoint : Types.S3BucketName → Types.S3ObjectKey → Endpoint :=
  fun bucket key =>
  { method := "GET"
  , path := "/" ++ bucket ++ "/" ++ key
  , service := .S3
  }

-- Put object
def s3PutObjectEndpoint : Types.S3BucketName → Types.S3ObjectKey → Endpoint :=
  fun bucket key =>
  { method := "PUT"
  , path := "/" ++ bucket ++ "/" ++ key
  , service := .S3
  }

-- Delete object
def s3DeleteObjectEndpoint : Types.S3BucketName → Types.S3ObjectKey → Endpoint :=
  fun bucket key =>
  { method := "DELETE"
  , path := "/" ++ bucket ++ "/" ++ key
  , service := .S3
  }

-- ============================================
-- EC2 API Endpoints
-- ============================================

-- Describe instances
def ec2DescribeInstancesEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .EC2
  }

-- Run instances
def ec2RunInstancesEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .EC2
  }

-- Terminate instances
def ec2TerminateInstancesEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .EC2
  }

-- ============================================
-- Lambda API Endpoints
-- ============================================

-- List functions
def lambdaListFunctionsEndpoint : Types.Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/2021-10-31/functions"
  , service := .Lambda
  }

-- Get function
def lambdaGetFunctionEndpoint : Types.Region → Types.LambdaFunctionName → Endpoint :=
  fun region name =>
  { method := "GET"
  , path := "/2021-10-31/functions/" ++ name
  , service := .Lambda
  }

-- Create function
def lambdaCreateFunctionEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/2021-10-31/functions"
  , service := .Lambda
  }

-- Update function code
def lambdaUpdateFunctionCodeEndpoint : Types.Region → Types.LambdaFunctionName → Endpoint :=
  fun region name =>
  { method := "PUT"
  , path := "/2021-10-31/functions/" ++ name ++ "/code"
  , service := .Lambda
  }

-- Update function configuration
def lambdaUpdateFunctionConfigEndpoint : Types.Region → Types.LambdaFunctionName → Endpoint :=
  fun region name =>
  { method := "PUT"
  , path := "/2021-10-31/functions/" ++ name ++ "/config"
  , service := .Lambda
  }

-- Delete function
def lambdaDeleteFunctionEndpoint : Types.Region → Types.LambdaFunctionName → Endpoint :=
  fun region name =>
  { method := "DELETE"
  , path := "/2021-10-31/functions/" ++ name
  , service := .Lambda
  }

-- Invoke function
def lambdaInvokeFunctionEndpoint : Types.Region → Types.LambdaFunctionName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/2021-10-31/functions/" ++ name ++ "/invocations"
  , service := .Lambda
  }

-- ============================================
-- DynamoDB API Endpoints
-- ============================================

-- List tables
def dynamoDBListTablesEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Describe table
def dynamoDBDescribeTableEndpoint : Types.Region → Types.DynamoDBTableName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Create table
def dynamoDBCreateTableEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Update table
def dynamoDBUpdateTableEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Delete table
def dynamoDBDeleteTableEndpoint : Types.Region → Types.DynamoDBTableName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Put item
def dynamoDBPutItemEndpoint : Types.Region → Types.DynamoDBTableName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Get item
def dynamoDBGetItemEndpoint : Types.Region → Types.DynamoDBTableName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Query
def dynamoDBQueryEndpoint : Types.Region → Types.DynamoDBTableName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- Scan
def dynamoDBScanEndpoint : Types.Region → Types.DynamoDBTableName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .DynamoDB
  }

-- ============================================
-- SQS API Endpoints
-- ============================================

-- List queues
def sqsListQueuesEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .SQS
  }

-- Create queue
def sqsCreateQueueEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .SQS
  }

-- Get queue URL
def sqsGetQueueUrlEndpoint : Types.Region → Types.SQSQueueName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .SQS
  }

-- Send message
def sqsSendMessageEndpoint : Types.Region → Types.SQSQueueUrl → Endpoint :=
  fun region url =>
  { method := "POST"
  , path := "/"
  , service := .SQS
  }

-- Receive message
def sqsReceiveMessageEndpoint : Types.Region → Types.SQSQueueUrl → Endpoint :=
  fun region url =>
  { method := "POST"
  , path := "/"
  , service := .SQS
  }

-- Delete message
def sqsDeleteMessageEndpoint : Types.Region → Types.SQSQueueUrl → Endpoint :=
  fun region url =>
  { method := "POST"
  , path := "/"
  , service := .SQS
  }

-- ============================================
-- IAM API Endpoints
-- ============================================

-- List users
def iamListUsersEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .IAM
  }

-- Get user
def iamGetUserEndpoint : Types.Region → Types.IAMUserName → Endpoint :=
  fun region name =>
  { method := "POST"
  , path := "/"
  , service := .IAM
  }

-- Create user
def iamCreateUserEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .IAM
  }

-- List policies
def iamListPoliciesEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .IAM
  }

-- Get policy
def iamGetPolicyEndpoint : Types.Region → Types.IAMPolicyArn → Endpoint :=
  fun region arn =>
  { method := "POST"
  , path := "/"
  , service := .IAM
  }

-- ============================================
-- STS API Endpoints
-- ============================================

-- Get caller identity
def stsGetCallerIdentityEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .STS
  }

-- Get session token
def stsGetSessionTokenEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .STS
  }

-- Assume role
def stsAssumeRoleEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .STS
  }

-- ============================================
-- CloudWatch API Endpoints
-- ============================================

-- Put metric data
def cloudWatchPutMetricDataEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .CloudWatch
  }

-- Get metric statistics
def cloudWatchGetMetricStatisticsEndpoint : Types.Region → Endpoint := fun region =>
  { method := "POST"
  , path := "/"
  , service := .CloudWatch
  }

-- ============================================
-- API Request/Response Types
-- ============================================

-- API request structure
structure APIRequest (T : Type) where
  endpoint : Endpoint
  headers : List (String × String)
  body    : Option T
  params  : List (String × String)
  
-- API response structure
structure APIResponse (T : Type) where
  status  : Nat
  headers : List (String × String)
  body    : Option T
  success : Bool
  errors  : List String
  requestId : Option Types.RequestId
  
-- ============================================
-- S3 Request/Response Types
-- ============================================

-- List buckets response
structure S3ListBucketsResponse where
  buckets : List Types.S3Bucket
  owner   : Types.AccountId
  
-- List objects response
structure S3ListObjectsResponse where
  contents : List Types.S3Object
  isTruncated : Bool
  nextMarker : Option Types.S3ObjectKey
  maxKeys : Nat
  
-- Get object response
structure S3GetObjectResponse where
  body        : String
  contentType : Option String
  contentLength : Nat
  etag        : Types.S3ETag
  lastModified : Types.ISO8601Timestamp
  
-- ============================================
-- EC2 Request/Response Types
-- ============================================

-- Run instances request
structure EC2RunInstancesRequest where
  imageId      : Types.EC2AMIId
  instanceType : Types.EC2InstanceType
  minCount     : Nat
  maxCount     : Nat
  securityGroupIds : Option (List Types.EC2SecurityGroupId)
  subnetId     : Option Types.EC2SubnetId
  
-- Describe instances response
structure EC2DescribeInstancesResponse where
  reservations : List Reservation
  
-- EC2 Reservation
structure Reservation where
  reservationId : String
  instances    : List Types.EC2Instance
  
-- ============================================
-- Lambda Request/Response Types
-- ============================================

-- Create function request
structure LambdaCreateFunctionRequest where
  functionName : Types.LambdaFunctionName
  runtime      : Types.LambdaRuntime
  handler      : Types.LambdaHandler
  role         : Types.IAMRoleArn
  code         : Types.LambdaFunctionCode
  description  : Option String
  timeout      : Option Nat
  memorySize   : Option Nat
  environment  : Option Types.LambdaEnvironment
  
-- Function response
structure LambdaFunctionResponse where
  functionName : Types.LambdaFunctionName
  functionArn  : Types.LambdaFunctionArn
  runtime      : Types.LambdaRuntime
  handler      : Types.LambdaHandler
  codeSha256   : String
  codeSize     : Nat
  state        : Types.LambdaFunctionState
  lastModified : Types.ISO8601Timestamp
  
-- Invoke function response
structure LambdaInvokeFunctionResponse where
  statusCode : Nat
  payload    : String
  logResult  : Option String
  executedVersion : Option String
  
-- ============================================
-- DynamoDB Request/Response Types
-- ============================================

-- Create table request
structure DynamoDBCreateTableRequest where
  tableName   : Types.DynamoDBTableName
  keySchema   : List DynamoDBKeySchema
  attributeDefinitions : List DynamoDBAttributeDefinition
  provisionedThroughput : DynamoDBProvisionedThroughput
  
-- DynamoDB Key Schema
structure DynamoDBKeySchema where
  attributeName : Types.DynamoDBAttributeName
  keyType      : DynamoDBKeyType
  
-- DynamoDB Key Type
inductive DynamoDBKeyType
  | HASH
  | RANGE
  deriving Repr, DecidableEq

-- DynamoDB Attribute Definition
structure DynamoDBAttributeDefinition where
  attributeName : Types.DynamoDBAttributeName
  attributeType : DynamoDBAttributeType
  
-- DynamoDB Attribute Type
inductive DynamoDBAttributeType
  | S
  | N
  | B
  deriving Repr, DecidableEq

-- DynamoDB Provisioned Throughput
structure DynamoDBProvisionedThroughput where
  readCapacityUnits  : Nat
  writeCapacityUnits : Nat
  
-- Describe table response
structure DynamoDBDescribeTableResponse where
  table : Types.DynamoDBTable
  
-- Put item request
structure DynamoDBPutItemRequest where
  tableName : Types.DynamoDBTableName
  item      : List Types.DynamoDBAttribute
  
-- Get item request
structure DynamoDBGetItemRequest where
  tableName : Types.DynamoDBTableName
  key       : List Types.DynamoDBAttribute
  
-- Query request
structure DynamoDBQueryRequest where
  tableName : Types.DynamoDBTableName
  keyConditionExpression : String
  filterExpression : Option String
  expressionAttributeValues : Option (List Types.DynamoDBAttribute)
  limit : Option Nat
  
-- ============================================
-- Theorems: API Endpoint Properties
-- ============================================

-- Theorem: S3 list buckets is GET
theorem s3_list_buckets_is_get (region : Types.Region) :
  (s3ListBucketsEndpoint region).method = "GET" := rfl

-- Theorem: S3 get object is GET
theorem s3_get_object_is_get (bucket : Types.S3BucketName) (key : Types.S3ObjectKey) :
  (s3GetObjectEndpoint bucket key).method = "GET" := rfl

-- Theorem: S3 put object is PUT
theorem s3_put_object_is_put (bucket : Types.S3BucketName) (key : Types.S3ObjectKey) :
  (s3PutObjectEndpoint bucket key).method = "PUT" := rfl

-- Theorem: EC2 describe instances is POST
theorem ec2_describe_instances_is_post (region : Types.Region) :
  (ec2DescribeInstancesEndpoint region).method = "POST" := rfl

-- Theorem: Lambda list functions is GET
theorem lambda_list_functions_is_get (region : Types.Region) :
  (lambdaListFunctionsEndpoint region).method = "GET" := rfl

-- Theorem: Lambda create function is POST
theorem lambda_create_function_is_post (region : Types.Region) :
  (lambdaCreateFunctionEndpoint region).method = "POST" := rfl

-- Theorem: Lambda invoke function is POST
theorem lambda_invoke_function_is_post (region : Types.Region) (name : Types.LambdaFunctionName) :
  (lambdaInvokeFunctionEndpoint region name).method = "POST" := rfl

-- Theorem: DynamoDB list tables is POST
theorem dynamodb_list_tables_is_post (region : Types.Region) :
  (dynamoDBListTablesEndpoint region).method = "POST" := rfl

-- Theorem: SQS send message is POST
theorem sqs_send_message_is_post (region : Types.Region) (url : Types.SQSQueueUrl) :
  (sqsSendMessageEndpoint region url).method = "POST" := rfl

-- Theorem: IAM list users is POST
theorem iam_list_users_is_post (region : Types.Region) :
  (iamListUsersEndpoint region).method = "POST" := rfl

-- Theorem: STS get caller identity is POST
theorem sts_get_caller_identity_is_post (region : Types.Region) :
  (stsGetCallerIdentityEndpoint region).method = "POST" := rfl

-- Theorem: CloudWatch put metric data is POST
theorem cloudwatch_put_metric_data_is_post (region : Types.Region) :
  (cloudWatchPutMetricDataEndpoint region).method = "POST" := rfl

end API
end AWS
