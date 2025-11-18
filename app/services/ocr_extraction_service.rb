# frozen_string_literal: true

require 'rtesseract'
require 'mini_magick'

# Service to extract text from video thumbnails using OCR
# Focuses on extracting text from lower thirds (zócalos) in news videos
class OcrExtractionService < ApplicationService
  # Language: Spanish only for news content
  DEFAULT_LANG = 'spa'.freeze
  # Lower third region: bottom 30% of image (where zócalos typically appear)
  LOWER_THIRD_REGION = { y_offset: 0.7, height: 0.3 }.freeze

  def self.call(image_path, options = {})
    new(image_path, options).call
  end

  def initialize(image_path, options = {})
    super()
    @image_path = image_path
    @options = options
    @extract_lower_third_only = options.fetch(:lower_third_only, true)
    @language = options.fetch(:language, DEFAULT_LANG)
    
    # Try to use big thumbnail if available (better quality for OCR)
    if @image_path.include?('.png') && !@image_path.include?('-big.png')
      big_thumbnail_path = @image_path.sub(/\.png\z/, '-big.png')
      @image_path = big_thumbnail_path if File.exist?(big_thumbnail_path)
    end
  end

  def call
    return handle_error('Image path is required') if @image_path.blank?
    return handle_error('Image file does not exist') unless File.exist?(@image_path)

    extracted_text = extract_text_from_image
    cleaned_text = clean_text(extracted_text)

    if cleaned_text.present?
      handle_success(cleaned_text)
    else
      handle_success('') # Return empty string if no text found (not an error)
    end
  rescue StandardError => e
    Rails.logger.error("OcrExtractionService error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    handle_error(e.message)
  end

  private

  def extract_text_from_image
    if @extract_lower_third_only
      extract_from_lower_third
    else
      extract_from_full_image
    end
  end

  def extract_from_lower_third
    # Load image and get dimensions
    image = MiniMagick::Image.open(@image_path)
    width = image.width
    height = image.height

    # Calculate lower third region (bottom 30% of image)
    y_offset = (height * LOWER_THIRD_REGION[:y_offset]).to_i
    crop_height = (height * LOWER_THIRD_REGION[:height]).to_i

    # Crop to lower third region
    cropped_image = image.crop("#{width}x#{crop_height}+0+#{y_offset}")

    # Enhance image for better OCR
    enhanced_image = enhance_image_for_ocr(cropped_image)

    # Extract text using Tesseract
    extract_text(enhanced_image)
  end

  def extract_from_full_image
    image = MiniMagick::Image.open(@image_path)
    enhanced_image = enhance_image_for_ocr(image)
    extract_text(enhanced_image)
  end

  def enhance_image_for_ocr(image)
    # Enhance image for better OCR recognition
    # - Increase contrast
    # - Convert to grayscale
    # - Apply sharpening
    image.colorspace('Gray')
       .modulate('120%') # Increase brightness
       .contrast # Increase contrast
       .sharpen('0x1') # Light sharpening
  end

  def extract_text(image)
    # Save enhanced image to temporary file
    temp_file = Tempfile.new(['ocr', '.png'])
    temp_file.binmode
    image.write(temp_file.path)
    temp_file.close

    # Use Tesseract OCR
    ocr = RTesseract.new(temp_file.path, lang: @language)
    text = ocr.to_s.strip

    # Clean up temp file
    temp_file.unlink

    text
  rescue StandardError => e
    Rails.logger.error("OCR extraction error: #{e.message}")
    ''
  ensure
    temp_file&.unlink
  end

  def clean_text(text)
    return '' if text.blank?

    # Remove excessive whitespace
    text = text.gsub(/\s+/, ' ')
    
    # Remove common OCR artifacts
    text = text.gsub(/[^\p{L}\p{N}\s.,;:!?\-()\/]/, '')
    
    # Remove very short "words" that are likely OCR errors (less than 2 characters)
    words = text.split(/\s+/)
    words = words.reject { |word| word.length < 2 && word.match?(/\d/) }
    
    words.join(' ').strip
  end
end

