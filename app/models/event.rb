class Event < ApplicationRecord
  serialize :extra, coder: JSON

  enum :action, {
    bookmark_created: "bookmark_created",
    tagged: "tagged"
  }
end
