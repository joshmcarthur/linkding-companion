class LinkdingSyncJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "LinkdingSyncJob started"
    client.list_bookmarks.each do |bookmark|
      Rails.logger.info "Bookmark: #{bookmark.inspect}"
      next if Event.bookmark_created.where(bookmark_id: bookmark.id).exists?
      next if bookmark.is_archived.present?

      LinkdingAutotagJob.perform_later(bookmark.id)
      LinkdingReadabilityJob.perform_later(bookmark.id)
      LinkdingSummarizeJob.perform_later(bookmark.id)
      LinkdingSearchJob.perform_later(bookmark.id)

      Event.create!(bookmark_id: bookmark.id, action: :bookmark_created, occurred_at: bookmark.created_at, extra: bookmark.to_json)
    end
    Rails.logger.info "LinkdingSyncJob finished"
  end

  private



  def client
    @client ||= LinkdingClient.new
  end
end
