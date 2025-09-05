# Linkding API Configuration
#
# Configuration can be done in two ways:
#
# 1. Rails credentials (recommended for production):
#    Run: rails credentials:edit
#    Add:
#    linkding:
#      host: "https://your-linkding-instance.com"
#      api_key: "your-api-key-here"
#
# 2. Environment variables:
#    LINKDING_HOST=https://your-linkding-instance.com
#    LINKDING_API_KEY=your-api-key-here
#
# The client will automatically pick up configuration from either source,
# with credentials taking precedence over environment variables.

# Optionally, you can create a global client instance
# Rails.application.config.linkding_client = LinkdingClient.new
