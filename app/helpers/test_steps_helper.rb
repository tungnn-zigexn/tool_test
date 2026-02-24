module TestStepsHelper
  def format_content_with_media_links(content_value)
    return '' if content_value.blank?

    # Unescape HTML entities.
    unescaped_content = CGI.unescapeHTML(content_value.to_s)

    # Sanitize content first (allow basic formatting and links via a tags)
    sanitized = sanitize(unescaped_content, tags: %w[span b i u br div strong em font a], attributes: %w(style class color size href target rel))

    # Pattern to match URLs that are NOT inside an HTML tag attribute (like href="..." or src="...")
    # This improved regex captures common URL characters and uses lookahead to exclude trailing punctuation and HTML tags
    url_pattern = %r{(?<!["'=])(https?://[a-zA-Z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+)(?=[.,;:]?(\s|$|<))}

    sanitized = sanitized.gsub(url_pattern) do |match|
      url = match
      processed_url = url
      is_gyazo = url.include?('gyazo.com')
      processed_url = gyazo_to_image_url(url) if is_gyazo

      is_media = image_url?(processed_url) || video_url?(processed_url)

      if is_gyazo || is_media
        link_to url, '#',
                data: {
                  action: 'click->media-preview#open',
                  url: processed_url,
                  type: if image_url?(processed_url)
                          'image'
                        else
                          video_url?(processed_url) ? 'video' : 'link'
                        end
                },
                class: 'text-decoration-none'
      else
        # Standard link: open in a new tab
        link_to url, url, target: '_blank', class: 'text-primary', style: 'word-break: break-all;'
      end
    end

    # Finally, decode any stray HTML entities like &quot; &amp; that sanitize might have protected, and mark HTML safe.
    CGI.unescapeHTML(sanitized).html_safe
  end
end
