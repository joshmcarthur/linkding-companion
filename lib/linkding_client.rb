require "faraday"
require "json"
require "ostruct"

class LinkdingClient
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class NotFoundError < Error; end
  class ValidationError < Error; end
  class UnconfiguredError < Error; end

  def initialize(host: nil, api_key: nil)
    @host = host || config_host
    @api_key = api_key || config_api_key

    raise UnconfiguredError, "Linkding host is required. Please configure in credentials or environment variables." if @host.blank?
    raise UnconfiguredError, "Linkding API key is required. Please configure in credentials or environment variables." if @api_key.blank?

    @connection = build_connection
  end

  # Bookmarks API
  def list_bookmarks(params = {})
    get("/api/bookmarks/", params)
  end

  def list_archived_bookmarks(params = {})
    get("/api/bookmarks/archived/", params)
  end

  def get_bookmark(id)
    get("/api/bookmarks/#{id}/")
  end

  def check_bookmark(url)
    get("/api/bookmarks/check/", { url: url })
  end

  def create_bookmark(bookmark_data)
    post("/api/bookmarks/", bookmark_data)
  end

  def update_bookmark(id, bookmark_data)
    put("/api/bookmarks/#{id}/", bookmark_data)
  end

  def patch_bookmark(id, bookmark_data)
    patch("/api/bookmarks/#{id}/", bookmark_data)
  end

  def archive_bookmark(id)
    post("/api/bookmarks/#{id}/archive/")
  end

  def unarchive_bookmark(id)
    post("/api/bookmarks/#{id}/unarchive/")
  end

  def delete_bookmark(id)
    delete("/api/bookmarks/#{id}/")
  end

  # Bookmark Assets API
  def list_bookmark_assets(bookmark_id, params = {})
    get("/api/bookmarks/#{bookmark_id}/assets/", params)
  end

  def get_bookmark_asset(bookmark_id, asset_id)
    get("/api/bookmarks/#{bookmark_id}/assets/#{asset_id}/")
  end

  def download_bookmark_asset(bookmark_id, asset_id)
    response = @connection.get("/api/bookmarks/#{bookmark_id}/assets/#{asset_id}/download/")
    handle_response(response, raw: true)
  end

  def upload_bookmark_asset(bookmark_id, file)
    file_path = if file.respond_to?(:path) && file.path
      file.path
    elsif file.is_a?(String) && File.exist?(file)
      file
    else
      raise ArgumentError, "Invalid file object. Expected file with path, uploaded file, or file path string."
    end

    content_type = Marcel::MimeType.for(file_path)

    # Create a custom multipart request
    boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"

    body = []
    body << "--#{boundary}"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file_path)}\""
    body << "Content-Type: #{content_type}"
    body << ""
    body << File.read(file_path)
    body << "--#{boundary}--"
    body << ""

    response = @connection.post("/api/bookmarks/#{bookmark_id}/assets/upload/") do |req|
      req.headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      req.body = body.join("\r\n")
    end

    handle_response(response)
  end

  def delete_bookmark_asset(bookmark_id, asset_id)
    delete("/api/bookmarks/#{bookmark_id}/assets/#{asset_id}/")
  end

  # Tags API
  def list_tags(params = {})
    get("/api/tags/", params)
  end

  def get_tag(id)
    get("/api/tags/#{id}/")
  end

  def create_tag(tag_data)
    post("/api/tags/", tag_data)
  end

  # Bundles API
  def list_bundles(params = {})
    get("/api/bundles/", params)
  end

  def get_bundle(id)
    get("/api/bundles/#{id}/")
  end

  def create_bundle(bundle_data)
    post("/api/bundles/", bundle_data)
  end

  def update_bundle(id, bundle_data)
    put("/api/bundles/#{id}/", bundle_data)
  end

  def patch_bundle(id, bundle_data)
    patch("/api/bundles/#{id}/", bundle_data)
  end

  def delete_bundle(id)
    delete("/api/bundles/#{id}/")
  end

  # User API
  def get_user_profile
    get("/api/user/profile/")
  end

  private

  def build_connection
    Faraday.new(url: @host) do |conn|
      conn.request :json
      conn.request :multipart
      conn.response :json, content_type: /\bjson$/, parser_options: { object_class: OpenStruct }
      conn.headers["Authorization"] = "Token #{@api_key}"
      conn.headers["User-Agent"] = "linkding-companion/#{version}"
      conn.adapter Faraday.default_adapter
    end
  end

  def get(path, params = {})
    response = @connection.get(path, params)
    handle_response(response)
  end

  def post(path, data = {})
    response = @connection.post(path, data)
    handle_response(response)
  end

  def put(path, data = {})
    response = @connection.put(path, data)
    handle_response(response)
  end

  def patch(path, data = {})
    response = @connection.patch(path, data)
    handle_response(response)
  end

  def delete(path)
    response = @connection.delete(path)
    handle_response(response)
  end

  def handle_response(response, raw: false)
    case response.status
    when 200..299
      return response.body unless raw
      return JSON.parse(response.body) if response.body.present?
      true
    when 401
      raise AuthenticationError, "Authentication failed. Check your API key."
    when 404
      raise NotFoundError, "Resource not found."
    when 400, 422
      error_message = extract_error_message(response.body)
      raise ValidationError, "Validation error: #{error_message}"
    else
      raise Error, "HTTP #{response.status}: #{response.body}"
    end
  end

  def extract_error_message(body)
    return body unless body.is_a?(Hash)

    if body["detail"]
      body["detail"]
    elsif body["errors"]
      body["errors"].is_a?(Array) ? body["errors"].join(", ") : body["errors"]
    else
      body.to_s
    end
  end

  def config_host
    Rails.application.credentials.linkding&.host ||
      ENV["LINKDING_HOST"]
  end

  def config_api_key
    Rails.application.credentials.linkding&.api_key ||
      ENV["LINKDING_API_KEY"]
  end

  def version
    # Try to get version from app, fallback to a default
    Rails.application.config.try(:version) || "1.0.0"
  end
end
