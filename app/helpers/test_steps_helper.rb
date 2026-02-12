module TestStepsHelper
  def format_content_with_media_links(content_value)
    return '' if content_value.blank?

    # Sanitize content first (allow basic formatting)
    sanitized = sanitize(content_value, tags: %w(span b i u br div strong em font), attributes: %w(style class color size))

    # Pattern to match URLs that are NOT inside an HTML tag attribute (like href="..." or src="...")
    # This improved regex captures common URL characters and uses lookahead to exclude trailing punctuation and HTML tags
    url_pattern = %r{(?<!["'=])(https?://[a-zA-Z0-9\-\._~:/?#\[\]@!$&'()*+,;=%]+)(?=[.,;:]?(\s|$|<))}

    sanitized.gsub(url_pattern) do |match|
      url = match
      processed_url = url
      is_gyazo = url.include?('gyazo.com')
      processed_url = gyazo_to_image_url(url) if is_gyazo
      
      is_media = image_url?(processed_url) || video_url?(processed_url)

      if is_gyazo || is_media
        link_to url, '#', 
                data: { 
                  action: "click->media-preview#open",
                  url: processed_url,
                  type: image_url?(processed_url) ? 'image' : video_url?(processed_url) ? 'video' : 'link'
                },
                class: "text-decoration-none"
      else
        # Standard link: open in a new tab
        link_to url, url, target: '_blank', class: "text-primary", style: "word-break: break-all;"
      end
    end.html_safe
  end
end
