class BookmarksController < ApplicationController
  def index
    limit = params[:limit] || 10
    offset = params[:offset] || 0
    q = params[:q].presence

    @bookmarks = LinkdingClient.new.list_bookmarks({
      limit: limit,
      offset: offset,
      q: q
    }.compact_blank).to_a
  end

  def autotag
    LinkdingAutotagJob.perform_later(params[:id])
  end
end
