# frozen_string_literal: true

class TextifyController < ApplicationController
  skip_before_action :check_xhr
  before_action :ensure_plugin_enabled
  before_action :ensure_logged_in, unless: :allow_anonymous?

  def show
    topic_id = params[:topic_id].to_i

    # Find the topic
    @topic = Topic.find_by(id: topic_id)
    raise Discourse::NotFound unless @topic

    # Check permissions
    guardian.ensure_can_see!(@topic)

    # Rate limiting (similar to print view)
    if SiteSetting.textify_rate_limit_per_hour > 0 && !guardian.is_admin?
      rate_limit_key = current_user ? current_user : request.remote_ip
      RateLimiter.new(
        rate_limit_key,
        "textify-topic-per-hour",
        SiteSetting.textify_rate_limit_per_hour,
        1.hour
      ).performed!
    end

    # Fetch ALL posts in the topic, ordered by post number
    @posts = Post.where(topic_id: topic_id)
                 .where(post_type: Post.types[:regular])
                 .where(deleted_at: nil)
                 .order(:post_number)
                 .includes(:user)

    # Convert raw markdown to clean, portable markdown
    @posts_data = @posts.map do |post|
      {
        author: post.user&.username || "Unknown",
        author_name: post.user&.name || post.user&.username || "Unknown",
        date: post.created_at,
        content: clean_markdown(post.raw)
      }
    end

    respond_to do |format|
      format.html { render "textify/show", layout: "textify" }
    end
  end

  private

  def ensure_plugin_enabled
    raise Discourse::NotFound unless SiteSetting.textify_enabled
  end

  def allow_anonymous?
    SiteSetting.textify_allow_anonymous
  end

  def clean_markdown(raw)
    return "" if raw.blank?

    text = raw.dup

    # Strip HTML anchor tags (e.g., <a name="anchor"></a>)
    text = text.gsub(/<a\s+name=["'][^"']*["']\s*><\/a>/i, "")

    # Strip any other self-closing or empty anchor tags
    text = text.gsub(/<a\s+[^>]*>\s*<\/a>/i, "")

    # Convert HTML anchor links to just the text
    # [Text](#anchor) → Text
    text = text.gsub(/\[([^\]]+)\]\(#[^)]*\)/, '\1')

    # Strip Discourse heading anchors: [](#p-123-heading-text)Heading Text → Heading Text
    # These appear before headings in raw markdown
    text = text.gsub(/\[\]\(#p-\d+-[^)]*\)/, '')

    # Strip HTML entities that might appear in raw markdown
    text = text.gsub(/&mdash;/, "—")
    text = text.gsub(/&ndash;/, "–")
    text = text.gsub(/&nbsp;/, " ")
    text = text.gsub(/&amp;/, "&")
    text = text.gsub(/&lt;/, "<")
    text = text.gsub(/&gt;/, ">")
    text = text.gsub(/&quot;/, '"')

    # Convert Discourse quote blocks to standard markdown blockquotes
    # [quote="username, post:1, topic:123"]content[/quote] → > content
    text = text.gsub(/\[quote[^\]]*\]\s*/i, "")
    text = text.gsub(/\[\/quote\]\s*/i, "\n")

    # Handle nested quotes by prefixing lines within quote context
    # This is a simplified approach - just removes the tags

    # Strip Discourse upload references (they won't resolve externally)
    # ![image|600x400](upload://xyz123) → [Image removed]
    text = text.gsub(/!\[[^\]]*\]\(upload:\/\/[^)]+\)/, "[Image]")

    # Strip other Discourse-specific upload syntax
    # ![image](#{Discourse.base_url}/uploads/...) - keep if absolute URL
    # But upload:// scheme won't work externally

    # Convert relative URLs to absolute URLs
    base_url = Discourse.base_url
    # [text](/t/slug/123) → [text](https://forum.example.com/t/slug/123)
    text = text.gsub(/\]\(\/([^)]+)\)/, "](#{base_url}/\\1)")

    # Strip Discourse-specific BBCode that might remain
    text = text.gsub(/\[details=[^\]]*\]\s*/i, "")
    text = text.gsub(/\[\/details\]\s*/i, "\n")
    text = text.gsub(/\[poll[^\]]*\].*?\[\/poll\]/mi, "[Poll removed]")

    # Convert :emoji: to unicode where possible, or leave as-is
    # This is optional - leaving as-is for now since most editors handle :emoji:

    # Normalize whitespace
    text = text.gsub(/\r\n?/, "\n")           # Normalize line endings
    text = text.gsub(/[ \t]+$/, "")           # Remove trailing whitespace on lines
    text = text.gsub(/^\s+$/, "")             # Remove whitespace-only lines
    text = text.gsub(/\n{3,}/, "\n\n")        # Max 2 consecutive newlines
    text = text.strip

    text
  end
end
