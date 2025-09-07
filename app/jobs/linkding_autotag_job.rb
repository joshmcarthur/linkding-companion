class LinkdingAutotagJob < ApplicationJob
  queue_as :default

  def perform(bookmark_id)
    bookmark = LinkdingClient.new.get_bookmark(bookmark_id)
    tags = LinkdingClient.new.list_tags(bookmark_id: bookmark_id)
    return if bookmark.is_archived.present?

    chat = RubyLLM.chat
    response = chat.ask <<~PROMPT
      You are a content analyst that tags bookmarks for clustering.
      Please tag the bookmark with the appropriate tags.
      Only add tags that are not already present and cannot be approximated by existing tags.

      #{bookmark.to_h.to_xml(skip_instruct: true, root: :bookmark)}

      The available tags are:

      #{tags.pluck(:name).to_xml(skip_instruct: true, root: :tags, children: :tag, skip_types: true)}

      Return the tags as a JSON array with no other formatting. The response MUST be valid JSON.
    PROMPT

    tags = JSON.parse(response.content)
    return if tags.blank?

    LinkdingClient.new.update_bookmark(bookmark_id, bookmark.to_h.merge(tag_names: tags))

    Event.create!(bookmark_id: bookmark_id, action: :tagged, occurred_at: bookmark.created_at, extra: { tags: tags.to_json })
  end
end
