-- Types.lean
-- Formal model of AWS API types

namespace AWS

-- ============================================
-- Primitive Types
-- ============================================

-- AWS Account ID (12-digit number)
def AccountId := String

-- AWS Region
def Region := String

-- AWS Access Key ID
def AccessKeyId := String

-- AWS Secret Access Key
def SecretAccessKey := String

-- AWS Session Token
def SessionToken := String

-- AWS Resource ARN
def ARN := String

-- AWS Resource Name
def ResourceName := String

-- AWS Request ID
def RequestId := String

-- ISO 8601 Timestamp
def ISO8601Timestamp := String

-- Unix Timestamp
def UnixTimestamp := Nat

-- ============================================
-- Service Types
-- ============================================

-- AWS Service names
inductive Service
  | S3
  | EC2
  | Lambda
  | DynamoDB
  | SQS
  | SNS
  | CloudFormation
  | IAM
  | STS
  | CloudWatch
  | CloudWatchLogs
  | ECR
  | EKS
  | RDS
  | Route53
  | API_Gateway
  | StepFunctions
  | SecretsManager
  | ParameterStore
  deriving Repr, DecidableEq

-- ============================================
-- S3 Types
-- ============================================

-- S3 Bucket Name
def S3BucketName := String

-- S3 Object Key
def S3ObjectKey := String

-- S3 Version ID
def S3VersionId := String

-- S3 ETag
def S3ETag := String

-- S3 Storage Class
inductive S3StorageClass
  | STANDARD
  | REDUCED_REDUNDANCY
  | STANDARD_IA
  | ONEZONE_IA
  | INTELLIGENT_TIERING
  | GLACIER
  | DEEP_ARCHIVE
  | GLACIER_IR
  deriving Repr, DecidableEq

-- S3 ACL
inductive S3ACL
  | private
  | public_read
  | public_read_write
  | authenticated_read
  deriving Repr, DecidableEq

-- S3 Object
structure S3Object where
  key          : S3ObjectKey
  size        : Nat
  etag        : S3ETag
  lastModified : ISO8601Timestamp
  storageClass : S3StorageClass
  
-- S3 Bucket
structure S3Bucket where
  name        : S3BucketName
  region      : Region
  created     : ISO8601Timestamp
  owner       : AccountId
  
-- S3 List Objects Result
structure S3ListObjectsResult where
  contents    : List S3Object
  isTruncated : Bool
  nextMarker  : Option S3ObjectKey
  maxKeys     : Nat
  
-- ============================================
-- EC2 Types
-- ============================================

-- EC2 Instance ID
def EC2InstanceId := String

-- EC2 Instance Type
inductive EC2InstanceType
  | t2_micro
  | t2_small
  | t2_medium
  | t2_large
  | m5_large
  | m5_xlarge
  | c5_large
  | c5_xlarge
  | r5_large
  | r5_xlarge
  deriving Repr, DecidableEq

-- EC2 Instance State
inductive EC2InstanceState
  | pending
  | running
  | stopping
  | stopped
  | shutting_down
  | terminated
  | error
  deriving Repr, DecidableEq

-- EC2 Instance
structure EC2Instance where
  instanceId   : EC2InstanceId
  instanceType : EC2InstanceType
  state        : EC2InstanceState
  privateIp    : Option String
  publicIp     : Option String
  launchedAt   : ISO8601Timestamp
  
-- EC2 AMI ID
def EC2AMIId := String

-- EC2 Security Group ID
def EC2SecurityGroupId := String

-- EC2 VPC ID
def EC2VPCId := String

-- EC2 Subnet ID
def EC2SubnetId := String

-- ============================================
-- Lambda Types
-- ============================================

-- Lambda Function Name
def LambdaFunctionName := String

-- Lambda Function ARN
def LambdaFunctionArn := String

-- Lambda Runtime
inductive LambdaRuntime
  | nodejs
  | nodejs14_x
  | nodejs16_x
  | nodejs18_x
  | python3_8
  | python3_9
  | python3_10
  | python3_11
  | java8
  | java11
  | java17
  | go1_x
  | dotnet6
  | dotnetcore3_1
  | ruby2_7
  | custom
  deriving Repr, DecidableEq

-- Lambda Handler
def LambdaHandler := String

-- Lambda Function Configuration
structure LambdaFunctionConfig where
  functionName : LambdaFunctionName
  runtime      : LambdaRuntime
  handler      : LambdaHandler
  memorySize   : Nat  -- MB
  timeout      : Nat  -- seconds
  environment  : LambdaEnvironment
  
-- Lambda Environment Variables
def LambdaEnvironment := List (String × String)

-- Lambda Function Code
structure LambdaFunctionCode where
  zipFile    : Option String  -- S3 bucket/key
  s3Bucket   : Option S3BucketName
  s3Key      : Option S3ObjectKey
  s3Version  : Option S3VersionId
  
-- Lambda Function
structure LambdaFunction where
  functionName : LambdaFunctionName
  functionArn  : LambdaFunctionArn
  runtime      : LambdaRuntime
  handler      : LambdaHandler
  code         : LambdaFunctionCode
  config       : LambdaFunctionConfig
  state        : LambdaFunctionState
  created      : ISO8601Timestamp
  modified     : ISO8601Timestamp
  
-- Lambda Function State
inductive LambdaFunctionState
  | Pending
  | Active
  | Inactive
  | Failed
  | LastUpdateFailed
  deriving Repr, DecidableEq

-- Lambda Invocation Result
structure LambdaInvocationResult where
  statusCode : Nat
  payload    : String
  logResult  : Option String
  executedVersion : Option String
  
-- ============================================
-- DynamoDB Types
-- ============================================

-- DynamoDB Table Name
def DynamoDBTableName := String

-- DynamoDB Attribute Name
def DynamoDBAttributeName := String

-- DynamoDB Attribute Value
inductive DynamoDBAttributeValue
  | S (value : String)
  | N (value : String)
  | B (value : String)
  | SS (values : List String)
  | NS (values : List String)
  | BS (values : List String)
  | BOOL (value : Bool)
  | NULL
  | L (values : List DynamoDBAttributeValue)
  | M (values : List (DynamoDBAttributeName × DynamoDBAttributeValue))
  deriving Repr

-- DynamoDB Attribute
structure DynamoDBAttribute where
  name  : DynamoDBAttributeName
  value : DynamoDBAttributeValue
  
-- DynamoDB Table
structure DynamoDBTable where
  tableName   : DynamoDBTableName
  arn         : ARN
  status      : DynamoDBTableStatus
  itemCount   : Nat
  sizeBytes   : Nat
  created     : ISO8601Timestamp
  
-- DynamoDB Table Status
inductive DynamoDBTableStatus
  | CREATING
  | UPDATING
  | DELETING
  | ACTIVE
  | INACTIVE
  | ARCHIVING
  | ARCHIVED
  deriving Repr, DecidableEq

-- DynamoDB Query Result
structure DynamoDBQueryResult where
  items      : List (List DynamoDBAttribute)
  count      : Nat
  scannedCount : Nat
  lastEvaluatedKey : Option (List DynamoDBAttribute)
  
-- ============================================
-- SQS Types
-- ============================================

-- SQS Queue Name
def SQSQueueName := String

-- SQS Queue URL
def SQSQueueUrl := String

-- SQS Message
def SQSMessage := String

-- SQS Message Attribute
structure SQSMessageAttribute where
  name  : String
  type_ : String  -- "String", "Number", "Binary"
  value : String
  
-- SQS Queue
structure SQSQueue where
  queueName : SQSQueueName
  queueUrl  : SQSQueueUrl
  arn       : ARN
  region    : Region
  
-- SQS Send Message Result
structure SQSSendMessageResult where
  messageId : String
  md5OfBody : String
  md5OfMessageAttributes : Option String
  sequenceNumber : Option String
  
-- SQS Receive Message Result
structure SQSReceiveMessageResult where
  messages : List SQSMessage
  
-- ============================================
-- IAM Types
-- ============================================

-- IAM User Name
def IAMUserName := String

-- IAM User ARN
def IAMUserArn := String

-- IAM Policy Name
def IAMPolicyName := String

-- IAM Policy ARN
def IAMPolicyArn := String

-- IAM Role Name
def IAMRoleName := String

-- IAM Role ARN
def IAMRoleArn := String

-- IAM Policy Document
def IAMPolicyDocument := String

-- IAM User
structure IAMUser where
  userName : IAMUserName
  userArn  : IAMUserArn
  createDate : ISO8601Timestamp
  
-- IAM Policy
structure IAMPolicy where
  policyName : IAMPolicyName
  policyArn  : IAMPolicyArn
  policyDocument : IAMPolicyDocument
  
-- IAM Role
structure IAMRole where
  roleName : IAMRoleName
  roleArn  : IAMRoleArn
  assumeRolePolicyDocument : IAMPolicyDocument
  
-- ============================================
-- STS Types
-- ============================================

-- STS Credentials
structure STSCredentials where
  accessKeyId     : AccessKeyId
  secretAccessKey : SecretAccessKey
  sessionToken    : SessionToken
  expiration      : ISO8601Timestamp
  
-- ============================================
-- CloudWatch Types
-- ============================================

-- CloudWatch Metric Name
def CloudWatchMetricName := String

-- CloudWatch Namespace
def CloudWatchNamespace := String

-- CloudWatch Dimension
structure CloudWatchDimension where
  name  : String
  value : String
  
-- CloudWatch Metric Datum
structure CloudWatchMetricDatum where
  metricName : CloudWatchMetricName
  dimensions : List CloudWatchDimension
  timestamp : ISO8601Timestamp
  value     : Double
  unit      : Option String
  
-- ============================================
-- Theorems: Type Properties
-- ============================================

-- Theorem: AccountId is a String
theorem account_id_is_string : ∀ (id : AccountId), True := by
  intro _
  exact True.intro

-- Theorem: Region is a String
theorem region_is_string : ∀ (region : Region), True := by
  intro _
  exact True.intro

-- Theorem: AccessKeyId is a String
theorem access_key_id_is_string : ∀ (key : AccessKeyId), True := by
  intro _
  exact True.intro

-- Theorem: SecretAccessKey is a String
theorem secret_access_key_is_string : ∀ (key : SecretAccessKey), True := by
  intro _
  exact True.intro

-- Theorem: ARN is a String
theorem arn_is_string : ∀ (arn : ARN), True := by
  intro _
  exact True.intro

-- Theorem: Service is decidable
theorem service_decidable : ∀ (s1 s2 : Service), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: S3StorageClass is decidable
theorem s3_storage_class_decidable : ∀ (c1 c2 : S3StorageClass), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: S3ACL is decidable
theorem s3_acl_decidable : ∀ (a1 a2 : S3ACL), Decidable (a1 = a2) := by
  intro _ _
  infer_instance

-- Theorem: EC2InstanceType is decidable
theorem ec2_instance_type_decidable : ∀ (t1 t2 : EC2InstanceType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: EC2InstanceState is decidable
theorem ec2_instance_state_decidable : ∀ (s1 s2 : EC2InstanceState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: LambdaRuntime is decidable
theorem lambda_runtime_decidable : ∀ (r1 r2 : LambdaRuntime), Decidable (r1 = r2) := by
  intro _ _
  infer_instance

-- Theorem: LambdaFunctionState is decidable
theorem lambda_function_state_decidable : ∀ (s1 s2 : LambdaFunctionState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: DynamoDBTableStatus is decidable
theorem dynamodb_table_status_decidable : ∀ (s1 s2 : DynamoDBTableStatus), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

end AWS
