
class LinkdingSearchJob < ApplicationJob
  queue_as :default

  BRAVE_API_KEY = Rails.application.credentials.brave&.api_key || ENV["BRAVE_API_KEY"]
  BRAVE_SEARCH_URL = "https://api.search.brave.com/res/v1/web/search"

  def perform(bookmark_id)
    return unless BRAVE_API_KEY.present?

    bookmark = LinkdingClient.new.get_bookmark(bookmark_id)
    return if bookmark.is_archived.present?
    return if Event.searched.where(bookmark_id: bookmark_id).exists?

    Rails.logger.info "Processing saved search for bookmark #{bookmark_id}"

    # Extract search query from URL
    search_query = extract_search_query(bookmark.url)
    return unless search_query.present?

    # Perform search
    search_result = perform_search(search_query)
    return unless search_result.present?

    # Update the bookmark with the search result
    update_bookmark(bookmark, search_result)

    # Create event to track the search processing
    Event.create!(
      bookmark_id: bookmark_id,
      action: :searched,
      occurred_at: Time.current,
      extra: {
        query: search_query,
        original_url: bookmark.url
      }
    )

    # Queue up processing jobs for the updated bookmark
    LinkdingAutotagJob.perform_later(bookmark_id)
    LinkdingReadabilityJob.perform_later(bookmark_id)
    LinkdingSummarizeJob.perform_later(bookmark_id)

    Rails.logger.info "Successfully processed saved search for bookmark #{bookmark_id}"
  end

  private

  def extract_search_query(url)
    return nil unless url.present?

    uri = URI.parse(url)
    return nil unless uri.query.present?

    params = CGI.parse(uri.query)
    params["q"]&.first
  rescue URI::InvalidURIError => e
    Rails.logger.error "Invalid URL format: #{e.message}"
    nil
  end

  def perform_search(query)
    return nil unless BRAVE_API_KEY.present?

    response = Faraday.get(BRAVE_SEARCH_URL) do |req|
      req.headers["X-Subscription-Token"] = BRAVE_API_KEY
      req.headers["Accept"] = "application/json"
      req.params["q"] = query
    end

    return nil unless response.success?

    data = JSON.parse(response.body)
    web_results = data["web"]["results"]
    return nil if web_results.empty?

    first_result = web_results.first
    {
      url: first_result["url"],
      title: first_result["title"],
      description: first_result["description"]
    }
  rescue => e
    Rails.logger.error "Error performing search: #{e.message}"
    nil
  end

  def update_bookmark(bookmark, result)
    client = LinkdingClient.new

    # Preserve the original search query in notes
    original_notes = bookmark.notes
    updated_notes = [
      original_notes,
      "\n\nLast searched: #{Time.current.iso8601}\n",
      "Original search URL: #{bookmark.url}"
    ].join

    # Update the bookmark with the search result
    client.update_bookmark(
      bookmark.id,
      bookmark.to_h.merge(
        url: result[:url],
        title: result[:title],
        description: result[:description],
        notes: updated_notes,
        tag_names: bookmark.tag_names + [ "from-search" ]
      )
    )
  rescue => e
    Rails.logger.error "Error updating bookmark: #{e.message}"
  end
end
