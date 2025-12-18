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

    # Strip content to text only
    @posts_data = @posts.map do |post|
      {
        author: post.user&.username || "Unknown",
        author_name: post.user&.name || post.user&.username || "Unknown",
        date: post.created_at,
        content: strip_to_text(post.cooked)
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

  def strip_to_text(html)
    return "" if html.blank?

    doc = Nokogiri::HTML.fragment(html)

    # Remove images
    doc.css("img").remove

    # Remove videos and audio
    doc.css("video, audio, source").remove

    # Remove embedded media (iframes, embeds, objects)
    doc.css("iframe, embed, object").remove

    # Remove lightbox wrappers
    doc.css(".lightbox-wrapper, .lightbox").remove

    # Remove file attachments
    doc.css(".attachment, .onebox, .lazyYT").remove

    # Remove quotes that reference other posts (optional - keep quote content)
    doc.css("aside.quote .title").remove

    # Remove like/reaction elements if any exist in content
    doc.css(".reactions, .likes, .post-links").remove

    # Remove any inline link previews / oneboxes
    doc.css(".onebox-body, .onebox-metadata").remove

    # Convert links to text with URL in parentheses
    doc.css("a").each do |link|
      href = link["href"]
      text = link.text.strip

      if href.present? && text.present? && text != href
        # Show both text and URL: "link text (https://example.com)"
        link.replace("#{text} (#{href})")
      elsif href.present?
        # Link text is same as URL, just show once
        link.replace(href)
      else
        # No href, just show text
        link.replace(text)
      end
    end

    # Get text content, normalize whitespace
    text = doc.text

    # Clean up excessive whitespace while preserving paragraph breaks
    text = text.gsub(/\r\n?/, "\n")           # Normalize line endings
    text = text.gsub(/[ \t]+/, " ")            # Collapse horizontal whitespace
    text = text.gsub(/\n[ \t]+/, "\n")         # Remove leading whitespace on lines
    text = text.gsub(/[ \t]+\n/, "\n")         # Remove trailing whitespace on lines
    text = text.gsub(/\n{3,}/, "\n\n")         # Max 2 consecutive newlines
    text = text.strip

    text
  end
end
