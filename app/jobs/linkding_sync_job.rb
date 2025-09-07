class LinkdingSyncJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "LinkdingSyncJob started"
    each_bookmark do |bookmark|
      Rails.logger.info "Bookmark: #{bookmark.inspect}"
      next if Event.bookmark_created.where(bookmark_id: bookmark.id).exists?
      next if bookmark.is_archived.present?

      LinkdingAutotagJob.perform_later(bookmark.id)
      LinkdingReadabilityJob.perform_later(bookmark.id)

      Event.create!(bookmark_id: bookmark.id, action: :bookmark_created, occurred_at: bookmark.created_at, extra: bookmark.to_json)
    end
    Rails.logger.info "LinkdingSyncJob finished"
  end

  private

  def each_bookmark(params = {})
    next_url = nil
    loop do
      response = next_url ? client.get(next_url) : client.list_bookmarks(params)

      response.results.each do |bookmark|
        yield bookmark
      end

      break unless response.next.present?
      next_url = response.next
    end
  end

  def client
    @client ||= LinkdingClient.new
  end
end
