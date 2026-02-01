# LLM PROVIDER SPECIFICATION
# Интерфейс для подключения Божественного Интеллекта

## 1. Provider Interface

```vibee
interface LLMProvider {
    // Основной метод генерации
    fn chat_completion(request: ChatRequest) -> Result<ChatResponse, ProviderError>;
    
    // Проверка доступности
    fn ping() -> bool;
}
```

## 2. Data Structures

```vibee
struct Message {
    role: String, // "system", "user", "assistant"
    content: String,
}

struct ChatRequest {
    model: String, // "glm-4", "claude-3-5-sonnet", "gpt-4o"
    messages: List<Message>,
    temperature: Float, // 0.0 - 1.0
    max_tokens: Int,
    stream: Bool,
}

struct ChatResponse {
    content: String,
    usage: TokenUsage,
    finish_reason: String, // "stop", "length", "filter"
}

struct TokenUsage {
    prompt_tokens: Int,
    completion_tokens: Int,
    total_tokens: Int,
}
```

## 3. Configuration

```vibee
struct ProviderConfig {
    api_key: String, // Must be encrypted at rest
    base_url: String, // e.g. "https://open.bigmodel.cn/api/paas/v4/"
    provider_type: Enum<Zhipu, OpenAI, Anthropic>,
}
```

## 4. Zhipu (GLM-4) Specifics

- Endpoint: `https://open.bigmodel.cn/api/paas/v4/chat/completions`
- Auth: JWT or Bearer (Standard API Key usually works as Bearer for many proxies, but Zhipu uses JWT generation for direct SDK, or API Key directly).
- *Decision*: We will use standard "Bear <API_KEY>" if supported by endpoint, otherwise implement simple JWT generation if Zig supports it easily. 
- *Update*: Zhipu API Key structure is `id.secret`. JWT payload needs `api_key` id and expiry.
- *Alternative*: Use an OpenAI-compatible proxy or verify if Zhipu supports direct API Key in header? Zhipu V4 supports OpenAI SDK, so standard Bearer might work with correct base URL?
- *Verdict*: Implement OpenAI-compatible generic client first. It covers Zhipu (via V4 API) and DeepSeek.

## 5. Divine Mandate Adaptation

" The Provider is the Oracle. The Codex is the Receiver. The Code is the Message. "
