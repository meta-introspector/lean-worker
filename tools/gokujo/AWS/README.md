# AWS API Integration for Gokujo

This directory contains formal Lean 4 models of Amazon Web Services (AWS) API for integration with the Gokujo build system.

## Structure

```
tools/gokujo/AWS/
├── Types.lean          # Core AWS primitive types
├── API.lean            # AWS API endpoints and types
├── Integration.lean    # Gokujo-AWS integration for build pipelines
└── README.md           # This file
```

## Types Modeled

### Primitive Types (`Types.lean`)
- **Identifiers**: `AccountId`, `RequestId`, `ARN`, `ResourceName`
- **Authentication**: `AccessKeyId`, `SecretAccessKey`, `SessionToken`
- **Regions**: `Region`
- **Timestamps**: `ISO8601Timestamp`, `UnixTimestamp`
- **Services**: `Service` (enum of 18 AWS services)

### S3 Types
- **Resources**: `S3BucketName`, `S3ObjectKey`, `S3VersionId`, `S3ETag`
- **Enums**: `S3StorageClass`, `S3ACL`
- **Data Structures**: `S3Object`, `S3Bucket`, `S3ListObjectsResult`

### EC2 Types
- **Resources**: `EC2InstanceId`, `EC2AMIId`, `EC2SecurityGroupId`, `EC2VPCId`, `EC2SubnetId`
- **Enums**: `EC2InstanceType`, `EC2InstanceState`
- **Data Structures**: `EC2Instance`, `Reservation`

### Lambda Types
- **Resources**: `LambdaFunctionName`, `LambdaFunctionArn`, `LambdaHandler`
- **Enums**: `LambdaRuntime`, `LambdaFunctionState`
- **Data Structures**: `LambdaFunctionConfig`, `LambdaEnvironment`, `LambdaFunctionCode`, `LambdaFunction`, `LambdaInvocationResult`

### DynamoDB Types
- **Resources**: `DynamoDBTableName`, `DynamoDBAttributeName`
- **Enums**: `DynamoDBTableStatus`, `DynamoDBKeyType`, `DynamoDBAttributeType`
- **Data Structures**: `DynamoDBAttribute`, `DynamoDBAttributeValue`, `DynamoDBTable`, `DynamoDBQueryResult`

### SQS Types
- **Resources**: `SQSQueueName`, `SQSQueueUrl`, `SQSMessage`
- **Data Structures**: `SQSMessageAttribute`, `SQSQueue`, `SQSSendMessageResult`, `SQSReceiveMessageResult`

### IAM Types
- **Resources**: `IAMUserName`, `IAMUserArn`, `IAMPolicyName`, `IAMPolicyArn`, `IAMRoleName`, `IAMRoleArn`
- **Data Structures**: `IAMPolicyDocument`, `IAMUser`, `IAMPolicy`, `IAMRole`

### STS Types
- **Data Structures**: `STSCredentials`

### CloudWatch Types
- **Resources**: `CloudWatchMetricName`, `CloudWatchNamespace`
- **Data Structures**: `CloudWatchDimension`, `CloudWatchMetricDatum`

### API Types (`API.lean`)
- **Configuration**: `AWSConfig`
- **Endpoints**: All major AWS API endpoints modeled as `Endpoint` records
- **Services**: S3, EC2, Lambda, DynamoDB, SQS, IAM, STS, CloudWatch, CloudWatchLogs, ECR, EKS, RDS, Route53, API Gateway, Step Functions, Secrets Manager, Parameter Store
- **Request/Response**: `APIRequest`, `APIResponse`

### Integration Types (`Integration.lean`)
- **Configuration**: `GokujoAWSConfig`
- **Operations**: `GokujoAWSOperation`
- **Resources**: `GokujoS3Bucket`, `GokujoLambdaFunction`, `GokujoDynamoDBTable`, `GokujoSQSQueue`
- **Project**: `GokujoAWSProject`
- **Commands**: `GokujoAWSS3Command`, `GokujoAWSLambdaCommand`, `GokujoAWSDynamoDBCommand`, `GokujoAWSSQSCommand`, `GokujoAWSIAMCommand`, `GokujoAWSSTSCommand`
- **CloudFormation**: `GokujoCloudFormationStack`, `GokujoCloudFormationCommand`
- **Results**: `GokujoAWSResult`, `GokujoAWSS3Result`, `GokujoAWSLambdaResult`, `GokujoAWSDynamoDBResult`, `GokujoAWSSQSResult`

## Usage

### Import the AWS module

```lean
import AWS.Types
import AWS.API
import AWS.GokujoIntegration
```

### Create an AWS project

```lean
open AWS

def myProject : GokujoIntegration.GokujoAWSProject :=
  { projectName := "my-aws-project"
  , region := "us-east-1"
  , s3Buckets := []
  , lambdaFunctions := []
  , dynamoDBTables := []
  , sqsQueues := []
  }
```

### Add resources to project

```lean
open AWS GokujoIntegration

-- Add S3 bucket
def myProjectWithS3 := addS3Bucket myProject 
  { bucketName := "my-bucket"
  , region := "us-east-1"
  , acl := Types.S3ACL.private
  }

-- Add Lambda function
def myProjectWithLambda := addLambdaFunction myProjectWithS3 
  { functionName := "my-function"
  , region := "us-east-1"
  , runtime := Types.LambdaRuntime.nodejs18_x
  , handler := "index.handler"
  , role := "arn:aws:iam::123456789012:role/lambda-role"
  }

-- Add DynamoDB table
def myProjectWithDynamoDB := addDynamoDBTable myProjectWithLambda 
  { tableName := "my-table"
  , region := "us-east-1"
  , keySchema := [API.DynamoDBKeySchema.mk "id" API.DynamoDBKeyType.HASH]
  }

-- Add SQS queue
def myProjectWithSQS := addSQSQueue myProjectWithDynamoDB 
  { queueName := "my-queue"
  , region := "us-east-1"
  , queueUrl := none
  }
```

### Create commands

```lean
open AWS GokujoIntegration

-- S3 commands
def listBucketsCmd := createS3Command "my-bucket" S3Action.list_buckets
def putObjectCmd := createS3Command "my-bucket" S3Action.put_object

-- Lambda commands
def listFunctionsCmd := createLambdaCommand "my-function" LambdaAction.list_functions
def invokeFunctionCmd := createLambdaCommand "my-function" LambdaAction.invoke_function

-- DynamoDB commands
def queryTableCmd := createDynamoDBCommand "my-table" DynamoDBAction.query

-- SQS commands
def sendMessageCmd := createSQSCommand "my-queue" SQSAction.send_message
```

## API Endpoints Covered

### S3
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | List buckets |
| GET | `/{bucket}?location` | Get bucket location |
| GET | `/{bucket}?list-type=2` | List objects |
| GET | `/{bucket}/{key}` | Get object |
| PUT | `/{bucket}/{key}` | Put object |
| DELETE | `/{bucket}/{key}` | Delete object |

### EC2
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Describe instances |
| POST | `/` | Run instances |
| POST | `/` | Terminate instances |

### Lambda
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/2021-10-31/functions` | List functions |
| GET | `/2021-10-31/functions/{name}` | Get function |
| POST | `/2021-10-31/functions` | Create function |
| PUT | `/2021-10-31/functions/{name}/code` | Update function code |
| PUT | `/2021-10-31/functions/{name}/config` | Update function config |
| DELETE | `/2021-10-31/functions/{name}` | Delete function |
| POST | `/2021-10-31/functions/{name}/invocations` | Invoke function |

### DynamoDB
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | List tables |
| POST | `/` | Describe table |
| POST | `/` | Create table |
| POST | `/` | Update table |
| POST | `/` | Delete table |
| POST | `/` | Put item |
| POST | `/` | Get item |
| POST | `/` | Query |
| POST | `/` | Scan |

### SQS
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | List queues |
| POST | `/` | Create queue |
| POST | `/` | Get queue URL |
| POST | `/` | Send message |
| POST | `/` | Receive message |
| POST | `/` | Delete message |

### IAM
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | List users |
| POST | `/` | Get user |
| POST | `/` | Create user |
| POST | `/` | List policies |
| POST | `/` | Get policy |

### STS
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Get caller identity |
| POST | `/` | Get session token |
| POST | `/` | Assume role |

### CloudWatch
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Put metric data |
| POST | `/` | Get metric statistics |

## Integration with Gokujo

The AWS integration allows Gokujo to:

1. **Manage S3 buckets and objects** - Store and retrieve build artifacts
2. **Deploy Lambda functions** - Run serverless code
3. **Query DynamoDB tables** - Store and retrieve structured data
4. **Send/receive SQS messages** - Communicate between services
5. **Manage IAM policies** - Configure permissions
6. **Assume roles via STS** - Temporary credentials
7. **Monitor with CloudWatch** - Track metrics

## Compilation

```bash
# Compile the AWS module
cd /workspace/github__meta-introspector__lean-worker
. ~/.elan/env
LEAN_PATH=tools/gokujo/AWS lean -R tools/gokujo/AWS Types.lean
LEAN_PATH=tools/gokujo/AWS lean -R tools/gokujo/AWS API.lean
LEAN_PATH=tools/gokujo/AWS lean -R tools/gokujo/AWS Integration.lean
```

## Next Steps

1. Fill in the `sorry` placeholders with actual proofs
2. Add more detailed API response/request types
3. Add pagination handling for list operations
4. Add examples of complete AWS workflows
5. Add validation theorems for AWS configurations
6. Add CloudFormation template modeling
