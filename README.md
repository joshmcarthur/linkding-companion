# Linkding Companion

A Ruby on Rails application that provides a companion interface to [Linkding](https://linkding.link/), a self-hosted bookmark manager.

## Features

- Faraday-based HTTP client for the Linkding API
- Full API coverage including bookmarks, tags, bundles, and user profile
- Comprehensive error handling
- Support for Rails credentials and environment variable configuration

## Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Configure Linkding API Access

You can configure your Linkding instance connection in two ways:

#### Option A: Rails Credentials (Recommended)

```bash
rails credentials:edit
```

Add your Linkding configuration:

```yaml
linkding:
  host: "https://your-linkding-instance.com"
  api_key: "your-api-key-here"
```

#### Option B: Environment Variables

```bash
export LINKDING_HOST="https://your-linkding-instance.com"
export LINKDING_API_KEY="your-api-key-here"
```

### 3. Get Your API Key

1. Log into your Linkding instance
2. Go to Settings
3. Find your API token in the "REST API" section

## Usage

### Basic Usage

```ruby
# Initialize client (uses credentials or ENV vars automatically)
client = LinkdingClient.new

# Or with explicit configuration
client = LinkdingClient.new(
  host: "https://your-linkding-instance.com",
  api_key: "your-api-key"
)
```

### Bookmarks

```ruby
# List bookmarks
bookmarks = client.list_bookmarks(limit: 10)

# Search bookmarks
results = client.list_bookmarks(q: "rails programming")

# Check if URL is bookmarked
check = client.check_bookmark("https://example.com")

# Create bookmark
bookmark = client.create_bookmark({
  url: "https://example.com",
  title: "Example Site",
  description: "A great example",
  tag_names: ["example", "demo"],
  unread: true
})

# Update bookmark
client.update_bookmark(bookmark['id'], {
  title: "Updated Title",
  tag_names: ["example", "updated"]
})

# Archive/unarchive
client.archive_bookmark(bookmark['id'])
client.unarchive_bookmark(bookmark['id'])

# Delete
client.delete_bookmark(bookmark['id'])
```

### Tags

```ruby
# List tags
tags = client.list_tags

# Create tag
tag = client.create_tag(name: "ruby-on-rails")
```

### Bundles

```ruby
# List bundles
bundles = client.list_bundles

# Create bundle
bundle = client.create_bundle({
  name: "Programming Resources",
  search: "programming",
  any_tags: "ruby rails javascript",
  excluded_tags: "outdated"
})

# Update bundle
client.update_bundle(bundle['id'], { name: "Updated Name" })
```

### User Profile

```ruby
profile = client.get_user_profile
puts "Theme: #{profile['theme']}"
```

### Error Handling

```ruby
begin
  client.get_bookmark(99999)
rescue LinkdingClient::NotFoundError => e
  puts "Bookmark not found: #{e.message}"
rescue LinkdingClient::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue LinkdingClient::ValidationError => e
  puts "Validation error: #{e.message}"
rescue LinkdingClient::Error => e
  puts "API error: #{e.message}"
end
```

## API Coverage

The client provides full coverage of the Linkding REST API:

- **Bookmarks**: List, retrieve, create, update, archive, delete
- **Bookmark Assets**: List, retrieve, download, upload, delete
- **Tags**: List, retrieve, create
- **Bundles**: List, retrieve, create, update, delete
- **User**: Get profile

For detailed API documentation, see: https://linkding.link/api/
