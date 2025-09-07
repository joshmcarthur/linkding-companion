module Linkding
  class PaginatedCollection
    include Enumerable

    def initialize(client, path, params = {})
      @client = client
      @path = path
      @params = params
      @current_page = nil
    end

    def each(&block)
      return enum_for(:each) unless block_given?

      loop do
        current_page.results.each(&block)
        break unless next_page
        load_next_page
      end
    end

    def total_count
      current_page.count
    end

    def next_page
      current_page.next
    end

    def previous_page
      current_page.previous
    end

    private

    def current_page
      @current_page ||= @client.get(@path, @params)
    end


    def load_next_page
      return unless next_page
      @current_page = @client.get(next_page)
    end
  end
end
