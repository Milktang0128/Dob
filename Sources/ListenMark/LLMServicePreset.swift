import Foundation

struct LLMServicePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let baseURL: String
    let model: String
    let keyURL: URL?
    let note: String
}

enum LLMServicePresets {
    static var all: [LLMServicePreset] {
        [
            LLMServicePreset(
                id: "deepseek",
                name: "DeepSeek",
                baseURL: "https://api.deepseek.com",
                model: "deepseek-v4-flash",
                keyURL: URL(string: "https://platform.deepseek.com/api_keys"),
                note: AppFlavor.text("默认推荐，国内访问友好", "Recommended default")
            ),
            LLMServicePreset(
                id: "openai",
                name: "OpenAI",
                baseURL: "https://api.openai.com/v1",
                model: "gpt-5.4-mini",
                keyURL: URL(string: "https://platform.openai.com/api-keys"),
                note: AppFlavor.text("国际通用，模型名可按账号权限调整", "General-purpose provider")
            ),
            LLMServicePreset(
                id: "custom-openai-compatible",
                name: AppFlavor.text("自定义 OpenAI 兼容", "Custom OpenAI-Compatible"),
                baseURL: "",
                model: "",
                keyURL: nil,
                note: AppFlavor.text("手动填写 Base URL 和模型名", "Enter Base URL and model")
            ),
            LLMServicePreset(
                id: "kimi",
                name: AppFlavor.text("Kimi", "Kimi"),
                baseURL: "https://api.moonshot.ai/v1",
                model: "kimi-k2.6",
                keyURL: URL(string: "https://platform.kimi.ai/console/api-keys"),
                note: AppFlavor.text("长上下文和中英文场景", "Long-context Chinese and English")
            ),
            LLMServicePreset(
                id: "qwen",
                name: AppFlavor.text("通义千问 / 百炼", "Qwen / Model Studio"),
                baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                model: "qwen-plus",
                keyURL: URL(string: "https://bailian.console.aliyun.com/?tab=model#/api-key"),
                note: AppFlavor.text("阿里百炼兼容 OpenAI 接口", "Alibaba Cloud OpenAI-compatible API")
            ),
            LLMServicePreset(
                id: "zhipu",
                name: AppFlavor.text("智谱 GLM", "Zhipu GLM"),
                baseURL: "https://open.bigmodel.cn/api/paas/v4",
                model: "glm-5.1",
                keyURL: URL(string: "https://open.bigmodel.cn/usercenter/apikeys"),
                note: AppFlavor.text("GLM 系列模型，模型名以控制台为准", "GLM models; adjust model by account access")
            ),
            LLMServicePreset(
                id: "volcengine-ark",
                name: AppFlavor.text("火山方舟", "Volcengine Ark"),
                baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                model: "doubao-seed-1-8-251228",
                keyURL: URL(string: "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey"),
                note: AppFlavor.text("豆包模型，需先在方舟开通模型权限", "Doubao models; enable model access in Ark first")
            ),
            LLMServicePreset(
                id: "siliconflow",
                name: "SiliconFlow",
                baseURL: "https://api.siliconflow.cn/v1",
                model: "Pro/zai-org/GLM-4.7",
                keyURL: URL(string: "https://cloud.siliconflow.cn/account/ak"),
                note: AppFlavor.text("聚合多模型，适合快速切换", "Multi-model platform")
            ),
            LLMServicePreset(
                id: "gemini",
                name: "Google Gemini",
                baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
                model: "gemini-3.5-flash",
                keyURL: URL(string: "https://aistudio.google.com/apikey"),
                note: AppFlavor.text("Google AI Studio 的 OpenAI 兼容层", "OpenAI-compatible Gemini endpoint")
            ),
            LLMServicePreset(
                id: "openrouter",
                name: "OpenRouter",
                baseURL: "https://openrouter.ai/api/v1",
                model: "openrouter/auto",
                keyURL: URL(string: "https://openrouter.ai/keys"),
                note: AppFlavor.text("一个 Key 路由多家模型", "One API key for many providers")
            )
        ]
    }
}
