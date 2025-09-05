RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai&.api_key || ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = Rails.application.credentials.anthropic&.api_key || ENV["ANTHROPIC_API_KEY"]

  # config.default_model = "gpt-4.1-nano"
end
