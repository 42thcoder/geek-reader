class Feed < ActiveRecord::Base
  include FeedsHelper
  after_create :fetch_feed

  belongs_to :user
  has_one :category
  has_many :entries, :dependent => :destroy
  validates_uniqueness_of :feed_url, :scope=>:user_id

  def unread_count
    @unread_entries = entries.where({:is_read=> 0}).count
  end

  def attributes
    super.merge({:unread_count=>nil})
  end

  def entries
    super.order("published DESC")
  end

  def fetch_feed(f=nil)
    logger.info "fetching feed: #{feed_url}"
    if f==nil
      raise "feed url is not valid" unless feed_url =~ /^http/
      if last_modified != nil
        f = Feedzirra::Feed.fetch_and_parse feed_url, {:if_modified_since => last_modified, :timeout=> 30.seconds}
      else
        f = Feedzirra::Feed.fetch_and_parse feed_url, {:timeout=> 30.seconds}
      end
    end

    if f and not f.is_a? Integer
      update_attributes({
        :url            => f.url,
        :title          => f.title,
        :description    => f.description,
        :etag           => f.etag,
        :last_modified  => f.last_modified
      })

      created_entries = []
      f.entries.each do |e|
        hash = {}
        hash[:title]      = e.title
        hash[:url]        = e.url
        hash[:author]     = e.author
        hash[:summary]    = parse_article e.summary, get_domain(f.url)
        hash[:published]  = e.published
        hash[:uuid]       = e.id
        if e.respond_to? :content
          hash[:content]    = parse_article e.content, get_domain(f.url)
        else
          hash[:content]    = ""
        end
        e = entries.new(hash)
        created_entries << e if e.save
      end
      logger.info "done: inserted #{created_entries.count} entries"
      created_entries
    elsif f != 304
      logger.info "done: unchanged"
      # invalid feed
      destroy
    end
  end
end