class LinkdingSummarizeJob < ApplicationJob
  queue_as :default

  def perform(bookmark_id)
    bookmark = LinkdingClient.new.get_bookmark(bookmark_id)
    return if bookmark.is_archived.present?
    return if Event.summarized.where(bookmark_id: bookmark_id).exists?

    Rails.logger.info "Processing summary for bookmark #{bookmark_id}: #{bookmark.url}"

    # Try to get the content from the bookmark asset
    content = get_bookmark_content(bookmark_id)

    unless content.present?
      Rails.logger.info "No content available for bookmark #{bookmark_id}, using existing description"
      return
    end

    # Generate summary using RubyLLM
    summary = generate_summary(content)

    unless summary.present?
      Rails.logger.info "Failed to generate summary for bookmark #{bookmark_id}"
      return
    end

    # Update bookmark description
    update_bookmark_description(bookmark, summary)

    # Create event to track the summarization
    Event.create!(
      bookmark_id: bookmark_id,
      action: :summarized,
      occurred_at: Time.current,
      extra: {
        url: bookmark.url,
        original_description: bookmark.description,
        summary_length: summary.length
      }
    )

    Rails.logger.info "Successfully summarized content for bookmark #{bookmark_id}"
  end

  private

  def get_bookmark_content(bookmark_id)
    begin
      assets = LinkdingClient.new.list_bookmark_assets(bookmark_id)
      content_asset = assets.find do |asset|
        asset.asset_type == "upload" && asset.display_name == "content.txt"
      end

      return nil unless content_asset

      # Download the content
      asset = LinkdingClient.new.download_bookmark_asset(bookmark_id, content_asset.id)
      asset.to_s
    rescue => e
      raise e
      Rails.logger.error "Error downloading content asset: #{e.message}"
      nil
    end
  end

  def generate_summary(content)
    chat = RubyLLM.chat
    response = chat.ask <<~PROMPT
      You are a content summarizer. Please provide a concise summary of the following content.
      The summary should be 2-3 sentences that capture the main points and purpose of the content.
      Focus on what would be most useful in a bookmark description.

      Content:
      #{content.truncate(4000)} # Limit content length to avoid token limits

      Return only the summary text with no additional formatting or explanation.
    PROMPT

    response.content.strip
  rescue => e
    Rails.logger.error "Error generating summary: #{e.message}"
    nil
  end

  def update_bookmark_description(bookmark, summary)
    LinkdingClient.new.update_bookmark(
      bookmark.id,
      bookmark.to_h.merge(description: summary)
    )
  rescue => e
    Rails.logger.error "Error updating bookmark description: #{e.message}"
  end
end
