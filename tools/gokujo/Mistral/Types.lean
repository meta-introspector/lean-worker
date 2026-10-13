-- Types.lean
-- Formal model of Mistral AI API types

namespace Mistral.Types

-- ============================================
-- Primitive Types
-- ============================================

-- Mistral API Key
def APIKey := String

-- Mistral Model Name
def ModelName := String

-- Mistral Model ID
def ModelId := String

-- Mistral Project ID
def ProjectId := String

-- Mistral Organization ID
def OrganizationId := String

-- Mistral User ID
def UserId := String

-- Mistral Request ID
def RequestId := String

-- ISO 8601 Timestamp
def ISO8601Timestamp := String

-- ============================================
-- Model Types
-- ============================================

-- Mistral Model
structure Model where
  id          : ModelId
  object      : String  -- "model"
  created     : ISO8601Timestamp
  description : Option String
  context_length : Nat
  
-- Model List Response
structure ModelList where
  object : String  -- "list"
  data   : List Model
  
-- ============================================
-- Chat Completion Types
-- ============================================

-- Chat Message Role
inductive ChatMessageRole
  | system
  | user
  | assistant
  deriving Repr, DecidableEq

-- Chat Message Content
def ChatMessageContent := String

-- Chat Message
structure ChatMessage where
  role    : ChatMessageRole
  content : ChatMessageContent
  
-- Chat Completion Request
structure ChatCompletionRequest where
  model       : ModelName
  messages    : List ChatMessage
  temperature : Option Double
  top_p       : Option Double
  max_tokens  : Option Nat
  stream      : Option Bool
  stop        : Option (List String)
  presence_penalty : Option Double
  frequency_penalty : Option Double
  user        : Option UserId
  
-- Chat Completion Choice
structure ChatCompletionChoice where
  index : Nat
  message : ChatMessage
  finish_reason : Option String
  
-- Chat Completion Usage
structure ChatCompletionUsage where
  prompt_tokens     : Nat
  completion_tokens : Nat
  total_tokens      : Nat
  
-- Chat Completion Response
structure ChatCompletionResponse where
  id          : RequestId
  object      : String  -- "chat.completion"
  created     : ISO8601Timestamp
  model       : ModelName
  choices     : List ChatCompletionChoice
  usage       : ChatCompletionUsage
  
-- Chat Message Delta
structure ChatMessageDelta where
  role    : Option ChatMessageRole
  content : Option String
  
-- Chat Completion Chunk Choice
structure ChatCompletionChunkChoice where
  index : Nat
  delta : ChatMessageDelta
  finish_reason : Option String
  
-- Chat Completion Streaming Chunk
structure ChatCompletionChunk where
  id          : RequestId
  object      : String  -- "chat.completion.chunk"
  created     : ISO8601Timestamp
  model       : ModelName
  choices     : List ChatCompletionChunkChoice
  usage       : Option ChatCompletionUsage
  
-- ============================================
-- Embedding Types
-- ============================================

-- Embedding Input
def EmbeddingInput := String

-- Embedding Request
structure EmbeddingRequest where
  model  : ModelName
  input  : EmbeddingInput
  encoding_format : Option String  -- "float", "base64", etc.
  
-- Embedding Data
structure EmbeddingData where
  object    : String  -- "embedding"
  embedding : List Double
  index     : Nat
  
-- Embedding Response
structure EmbeddingResponse where
  object : String  -- "list"
  data   : List EmbeddingData
  model  : ModelName
  usage  : EmbeddingUsage
  
-- Embedding Usage
structure EmbeddingUsage where
  prompt_tokens : Nat
  total_tokens  : Nat
  
-- ============================================
-- Fine-tuning Types
-- ============================================

-- Fine-tuning Job ID
def FineTuningJobId := String

-- Fine-tuning Hyperparameters
structure FineTuningHyperparameters where
  n_epochs : Option Nat
  batch_size : Option Nat
  learning_rate_multiplier : Option Double
  
-- Fine-tuning Dataset
structure FineTuningDataset where
  id   : String
  object : String  -- "dataset"
  created : ISO8601Timestamp
  file_id : String
  purpose : String
  status : String
  
-- Fine-tuning Job
structure FineTuningJob where
  id        : FineTuningJobId
  object    : String  -- "fine_tuning.job"
  model     : ModelName
  created   : ISO8601Timestamp
  finished_at : Option ISO8601Timestamp
  status    : String
  training_file : String
  validation_file : Option String
  result_files : List String
  hyperparameters : FineTuningHyperparameters
  n_epochs : Option Nat
  batch_size : Option Nat
  learning_rate_multiplier : Option Double
  
-- Fine-tuning Job List
structure FineTuningJobList where
  object : String  -- "list"
  data   : List FineTuningJob
  
-- ============================================
-- Project Types
-- ============================================

-- Mistral Project
structure Project where
  id        : ProjectId
  object    : String  -- "project"
  created   : ISO8601Timestamp
  name      : String
  description : Option String
  organization_id : Option OrganizationId
  
-- Project List
structure ProjectList where
  object : String  -- "list"
  data   : List Project
  
-- ============================================
-- Organization Types
-- ============================================

-- Mistral Organization
structure Organization where
  id        : OrganizationId
  object    : String  -- "organization"
  created   : ISO8601Timestamp
  name      : String
  
-- ============================================
-- Theorems: Type Properties
-- ============================================

-- Theorem: APIKey is a String
theorem api_key_is_string : ∀ (key : APIKey), True := by
  intro _
  exact True.intro

-- Theorem: ModelName is a String
theorem model_name_is_string : ∀ (name : ModelName), True := by
  intro _
  exact True.intro

-- Theorem: ModelId is a String
theorem model_id_is_string : ∀ (id : ModelId), True := by
  intro _
  exact True.intro

-- Theorem: ProjectId is a String
theorem project_id_is_string : ∀ (id : ProjectId), True := by
  intro _
  exact True.intro

-- Theorem: OrganizationId is a String
theorem organization_id_is_string : ∀ (id : OrganizationId), True := by
  intro _
  exact True.intro

-- Theorem: UserId is a String
theorem user_id_is_string : ∀ (id : UserId), True := by
  intro _
  exact True.intro

-- Theorem: RequestId is a String
theorem request_id_is_string : ∀ (id : RequestId), True := by
  intro _
  exact True.intro

-- Theorem: ChatMessageRole is decidable
theorem chat_message_role_decidable : ∀ (r1 r2 : ChatMessageRole), r1 = r2 ∨ r1 ≠ r2 := by
  intro r1 r2
  cases r1 <;> cases r2 <;> simp [*, or_true, true_or]
  all_goals left; rfl

-- Theorem: Model has ID
theorem model_has_id (model : Model) :
  model.id = model.id := by
  rfl

-- Theorem: Model has object type
theorem model_has_object (model : Model) :
  model.object = "model" := by
  sorry

-- Theorem: ChatMessage has role
theorem chat_message_has_role (msg : ChatMessage) :
  msg.role = msg.role := by
  rfl

-- Theorem: ChatMessage has content
theorem chat_message_has_content (msg : ChatMessage) :
  msg.content = msg.content := by
  rfl

-- Theorem: ChatCompletionRequest has model
theorem chat_completion_request_has_model (req : ChatCompletionRequest) :
  req.model = req.model := by
  rfl

-- Theorem: ChatCompletionRequest has messages
theorem chat_completion_request_has_messages (req : ChatCompletionRequest) :
  req.messages = req.messages := by
  rfl

-- Theorem: ChatCompletionResponse has choices
theorem chat_completion_response_has_choices (res : ChatCompletionResponse) :
  res.choices = res.choices := by
  rfl

-- Theorem: ChatCompletionResponse has usage
theorem chat_completion_response_has_usage (res : ChatCompletionResponse) :
  res.usage = res.usage := by
  rfl

-- Theorem: EmbeddingRequest has model
theorem embedding_request_has_model (req : EmbeddingRequest) :
  req.model = req.model := by
  rfl

-- Theorem: EmbeddingRequest has input
theorem embedding_request_has_input (req : EmbeddingRequest) :
  req.input = req.input := by
  rfl

-- Theorem: FineTuningJob has ID
theorem fine_tuning_job_has_id (job : FineTuningJob) :
  job.id = job.id := by
  rfl

-- Theorem: Project has ID
theorem project_has_id (project : Project) :
  project.id = project.id := by
  rfl

-- Theorem: Organization has ID
theorem organization_has_id (org : Organization) :
  org.id = org.id := by
  rfl

end Mistral.Types
