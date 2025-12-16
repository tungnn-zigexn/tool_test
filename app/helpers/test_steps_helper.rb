module TestStepsHelper
  # Convert Gyazo page URL to direct image URL
  def gyazo_to_image_url(url)
    return url if url.blank?

    # Convert Gyazo page URL (https://gyazo.com/abc123) to direct image URL (https://i.gyazo.com/abc123.png)
    if url.match?(%r{^https?://gyazo\.com/([a-zA-Z0-9]+)})
      image_id = url.match(%r{gyazo\.com/([a-zA-Z0-9]+)})[1]
      "https://i.gyazo.com/#{image_id}.png"
    elsif url.match?(%r{^https?://i\.gyazo\.com/})
      # Already a direct URL
      url
    else
      # Other URLs, return as-is
      url
    end
  end

  # Check if URL is an image
  def is_image_url?(url)
    (url.present? && url.match?(/\.(png|jpg|jpeg|gif|webp)$/i)) || url.to_s.include?('gyazo.com')
  end

  # Check if URL is a video
  def is_video_url?(url)
    url.present? && url.match?(/\.(mp4|webm|mov)$/i)
  end

  # Get media type from URL or content_type
  def media_type(content)
    return content.content_type if content.content_type != 'link'

    url = content.content_value
    return 'image' if is_image_url?(url)
    return 'video' if is_video_url?(url)

    'link'
  end
end
