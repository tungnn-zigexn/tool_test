module TestStepsHelper
  def format_content_with_media_links(content_value)
    return '' if content_value.blank?

    # Sanitize content first (allow basic formatting)
    sanitized = sanitize(content_value, tags: %w(span b i u br div), attributes: %w(style class))

    # Pattern to match URLs that are NOT inside an HTML tag (to avoid breaking existing links or attributes)
    # This is a simple approximation. For robust HTML parsing, Nokogiri is better, but this should suffice for simple rich text.
    url_pattern = %r{(?<!["'=])(https?://[^\s<]+)}

    sanitized.gsub(url_pattern) do |match|
      url = match
      processed_url = url
      processed_url = gyazo_to_image_url(url) if url.include?('gyazo.com')
      type = image_url?(processed_url) ? 'image' : video_url?(processed_url) ? 'video' : 'link'

      link_to url, '#', 
              data: { 
                action: "click->media-preview#open",
                url: processed_url,
                type: type
              },
              class: "text-decoration-none"
    end.html_safe
  end
end
