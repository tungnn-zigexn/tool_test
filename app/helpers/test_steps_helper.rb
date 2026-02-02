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
end
