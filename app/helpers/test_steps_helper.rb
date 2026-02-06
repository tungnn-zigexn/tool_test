module TestStepsHelper
  # Convert Gyazo page URL to direct image URL
  def gyazo_to_image_url(url)
    return url if url.blank?

    # Convert Gyazo page URL (https://gyazo.com/abc123) to direct image URL (https://i.gyazo.com/abc123.png)
    if url.match?(%r{^https?://gyazo\.com/([a-zA-Z0-9]+)})
      image_id = url.match(%r{gyazo\.com/([a-zA-Z0-9]+)})[1]
      "https://i.gyazo.com/#{image_id}.png"
    else
      # Already a direct URL or other URLs, return as-is
      url
    end
  end

  # Check if URL is an image
  def image_url?(url)
    (url.present? && url.match?(/\.(png|jpg|jpeg|gif|webp)$/i)) || url.to_s.include?('gyazo.com')
  end

  # Check if URL is a video
  def video_url?(url)
    url.present? && url.match?(/\.(mp4|webm|mov)$/i)
  end

  # Get media type from URL or content_type
  def media_type(content)
    return content.content_type if content.content_type != 'link'

    url = content.content_value
    return 'image' if image_url?(url)
    return 'video' if video_url?(url)

    'link'
  end

  # Render media from URL (Image or Video)
  def render_media(url)
    return if url.blank?

    # Process potential rich text containing links
    return unless url.match?(%r{https?://[^\s<]+})

    processed_url = url.match(%r{https?://[^\s<]+})[0]

    processed_url = gyazo_to_image_url(processed_url) if processed_url.include?('gyazo.com')

    if image_url?(processed_url)
      link_to processed_url, target: '_blank', class: 'd-block mt-2' do
        image_tag processed_url, class: 'img-fluid rounded border shadow-sm', style: 'max-height: 150px;'
      end
    elsif video_url?(processed_url)
      content_tag :div, class: 'mt-2' do
        video_tag processed_url, controls: true, class: 'img-fluid rounded border shadow-sm',
                                 style: 'max-height: 150px;'
      end
    else
      link_to processed_url, processed_url, target: '_blank', class: 'small text-primary d-block mt-1'
    end
  end
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
