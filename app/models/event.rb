class Event < ApplicationRecord
  serialize :extra, coder: JSON

  enum :action, {
    bookmark_created: "bookmark_created",
    tagged: "tagged",
    searched: "searched",
    readability_extracted: "readability_extracted",
    summarized: "summarized"
  }
end
