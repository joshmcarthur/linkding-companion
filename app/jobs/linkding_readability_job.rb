require "shellwords"
require "uri"

class LinkdingReadabilityJob < ApplicationJob
  queue_as :default

  def perform(bookmark_id)
    bookmark = LinkdingClient.new.get_bookmark(bookmark_id)
    return if bookmark.is_archived.present?
    return if Event.readability_extracted.where(bookmark_id: bookmark_id).exists?

    Rails.logger.info "Processing readability for bookmark #{bookmark_id}: #{bookmark.url}"

    # Check if page is probably readable and extract content
    readable_content = extract_readable_content(bookmark.url)

    unless readable_content.present?
      Rails.logger.info "No readable content extracted for bookmark #{bookmark_id}"
      return
    end

    # Update bookmark notes with readable content
    update_bookmark_notes(bookmark, readable_content)

    # Upload readable content as bookmark asset
    upload_readable_asset(bookmark_id, readable_content)

    # Create event to track the extraction
    Event.create!(
      bookmark_id: bookmark_id,
      action: :readability_extracted,
      occurred_at: Time.current,
      extra: {
        url: bookmark.url,
        content_length: readable_content.length
      }
    )

    Rails.logger.info "Successfully extracted readable content for bookmark #{bookmark_id}"
  end

  private

  def extract_readable_content(url)
    # Validate URL format to prevent shell injection
    begin
      parsed_url = URI.parse(url)
      unless parsed_url.scheme && parsed_url.host
        Rails.logger.error "Invalid URL format: #{url}"
        return nil
      end
    rescue URI::InvalidURIError
      Rails.logger.error "Invalid URL format: #{url}"
      return nil
    end

    # Use readability-cli via npx to extract readable content
    # --low-confidence=exit will cause the command to exit with non-zero status
    escaped_url = Shellwords.escape(url)
    command = "npx -y readability-cli --properties text-content --low-confidence=exit #{escaped_url}"
    Rails.logger.debug "Running command: #{command}"

    result = `#{command}`
    exit_status = $?.exitstatus

    if exit_status == 0
      result.strip
    else
      Rails.logger.debug "Failed to extract readable content (exit #{exit_status}): #{result}"
      nil
    end
  rescue => e
    Rails.logger.error "Error extracting readable content: #{e.message}"
    nil
  end

  def update_bookmark_notes(bookmark, readable_content)
    current_notes = bookmark.notes || ""
    separator = current_notes.present? ? "\n\n---\n\n" : ""
    updated_notes = current_notes + separator + "Content:\n\n" + readable_content

    LinkdingClient.new.update_bookmark(bookmark.id, bookmark.to_h.merge(notes: updated_notes))
  end

  def upload_readable_asset(bookmark_id, readable_content)
    # Create a temporary file with the readable content
    temp_file = Tempfile.new([ "content", ".txt" ])
    temp_file.write(readable_content)
    temp_file.rewind

    # Upload as bookmark asset
    LinkdingClient.new.upload_bookmark_asset(bookmark_id, temp_file)

    # Clean up temp file
    temp_file.close
    temp_file.unlink
  rescue => e
    Rails.logger.error "Error uploading readable asset: #{e.message}"
  end
end
