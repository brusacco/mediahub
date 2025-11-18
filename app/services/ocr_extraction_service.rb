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

    # Verify ImageMagick is available
    unless system('which convert > /dev/null 2>&1') || system('which magick > /dev/null 2>&1')
      error_msg = 'ImageMagick is not installed. Install with: sudo apt-get install imagemagick'
      Rails.logger.error("OcrExtractionService: #{error_msg}")
      return handle_error(error_msg)
    end

    Rails.logger.debug("OcrExtractionService: Processing #{File.basename(@image_path)}")
    Rails.logger.debug("OcrExtractionService: File size: #{File.size(@image_path)} bytes")
    Rails.logger.debug("OcrExtractionService: Lower third only: #{@extract_lower_third_only}")
    Rails.logger.debug("OcrExtractionService: Language: #{@language}")

    extracted_text = extract_text_from_image
    Rails.logger.debug("OcrExtractionService: Raw extracted text (#{extracted_text&.length || 0} chars): '#{extracted_text&.[](0..200)}'")
    
    cleaned_text = clean_text(extracted_text)
    Rails.logger.debug("OcrExtractionService: Cleaned text (#{cleaned_text&.length || 0} chars): '#{cleaned_text&.[](0..200)}'")

    if cleaned_text.present?
      Rails.logger.info("OcrExtractionService: Successfully extracted #{cleaned_text.length} characters")
      handle_success(cleaned_text)
    else
      Rails.logger.warn("OcrExtractionService: No text extracted from #{File.basename(@image_path)}")
      handle_success('') # Return empty string if no text found (not an error)
    end
  rescue StandardError => e
    error_msg = e.message
    if error_msg.include?('ImageMagick') || error_msg.include?('GraphicsMagick')
      error_msg = 'ImageMagick is not installed. Install with: sudo apt-get install imagemagick'
    end
    Rails.logger.error("OcrExtractionService error: #{error_msg}")
    Rails.logger.error(e.backtrace.join("\n"))
    handle_error(error_msg)
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
    begin
      Rails.logger.info("OcrExtractionService: Opening image: #{@image_path}")
      image = MiniMagick::Image.open(@image_path)
      width = image.width
      height = image.height

      Rails.logger.info("OcrExtractionService: Original image size: #{width}x#{height}")

      # Calculate lower third region (bottom 30% of image)
      y_offset = (height * LOWER_THIRD_REGION[:y_offset]).to_i
      crop_height = (height * LOWER_THIRD_REGION[:height]).to_i

      Rails.logger.info("OcrExtractionService: Cropping region: #{width}x#{crop_height} at y=#{y_offset}")

      # Crop to lower third region
      cropped_image = image.crop("#{width}x#{crop_height}+0+#{y_offset}")

      Rails.logger.info("OcrExtractionService: Cropped image size: #{cropped_image.width}x#{cropped_image.height}")

      # Enhance image for better OCR
      enhanced_image = enhance_image_for_ocr(cropped_image)

      # Extract text using Tesseract
      extract_text(enhanced_image)
    rescue StandardError => e
      Rails.logger.error("OcrExtractionService: ERROR in extract_from_lower_third: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      raise
    end
  end

  def extract_from_full_image
    image = MiniMagick::Image.open(@image_path)
    enhanced_image = enhance_image_for_ocr(image)
    extract_text(enhanced_image)
  end

  def enhance_image_for_ocr(image)
    # Advanced image enhancement for better OCR recognition
    # Techniques optimized for text extraction from video frames
    begin
      # Step 1: Convert to grayscale
      enhanced = image.colorspace('Gray')
      
      # Step 2: Upscale image for better OCR (2x or 3x depending on size)
      # Tesseract works better with larger images (at least 300 DPI equivalent)
      current_width = enhanced.width
      target_width = if current_width < 800
                       current_width * 3  # 3x upscale for small images
                     elsif current_width < 1200
                       current_width * 2  # 2x upscale for medium images
                     else
                       current_width      # Keep original size for large images
                     end
      
      if target_width > current_width
        Rails.logger.debug("OcrExtractionService: Upscaling from #{current_width}px to #{target_width}px")
        enhanced = enhanced.resize("#{target_width}x")
      end
      
      # Step 3: Enhance contrast and brightness
      # Use normalize to stretch contrast and improve text visibility
      enhanced = enhanced.normalize
      
      # Step 4: Apply adaptive thresholding (very effective for text on video)
      # This converts to pure black/white which Tesseract handles better
      enhanced = enhanced.threshold('50%')
      
      # Step 5: Apply aggressive sharpening for text clarity
      # Unsharp mask is better than regular sharpen for text
      enhanced = enhanced.unsharp('0x1+1.0+0.05')
      
      # Step 6: Increase contrast further
      enhanced = enhanced.contrast
      
      Rails.logger.debug("OcrExtractionService: Image enhancement successful (final size: #{enhanced.width}x#{enhanced.height})")
      enhanced
    rescue StandardError => e
      Rails.logger.error("OcrExtractionService: ERROR enhancing image: #{e.class} - #{e.message}")
      Rails.logger.error("OcrExtractionService: Trying fallback enhancement...")
      
      # Fallback: simpler enhancement if advanced techniques fail
      begin
        enhanced = image.colorspace('Gray')
                       .normalize
                       .contrast
                       .sharpen('0x1')
        enhanced
      rescue StandardError => e2
        Rails.logger.error("OcrExtractionService: Fallback enhancement also failed: #{e2.message}")
        Rails.logger.error("OcrExtractionService: Using original image without enhancement")
        image
      end
    end
  end

  def extract_text(image)
    # Save enhanced image to temporary file
    temp_file = Tempfile.new(['ocr', '.png'])
    temp_file.binmode
    
    Rails.logger.info("OcrExtractionService: Writing temp image to #{temp_file.path}")
    start_time = Time.now
    
    image.write(temp_file.path)
    temp_file.close

    file_size = File.size(temp_file.path)
    Rails.logger.info("OcrExtractionService: Temp file saved: #{temp_file.path} (#{file_size} bytes)")
    
    unless file_size > 0
      Rails.logger.error("OcrExtractionService: ERROR - Temp file is empty!")
      temp_file.unlink
      return ''
    end

    # Verify Tesseract is available
    unless system('which tesseract > /dev/null 2>&1')
      Rails.logger.error("OcrExtractionService: ERROR - Tesseract not found in PATH!")
      temp_file.unlink
      return ''
    end

    # Use Tesseract OCR with optimized configuration
    Rails.logger.info("OcrExtractionService: Running Tesseract with language: #{@language}")
    
    begin
      # Configure Tesseract for better text recognition
      # PSM 6 = Assume a single uniform block of text (good for lower thirds)
      # PSM 7 = Treat the image as a single text line (alternative for zócalos)
      psm_mode = @options.fetch(:psm_mode, 6)
      
      # Create OCR instance - RTesseract uses config hash for options
      ocr = RTesseract.new(temp_file.path, lang: @language)
      
      # Configure Tesseract with optimized settings
      # PSM mode and character whitelist for better accuracy
      ocr.config = {
        'tessedit_pageseg_mode' => psm_mode.to_s,
        'tessedit_char_whitelist' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ÁÉÍÓÚáéíóúÑñÜü.,;:!?\-()/ '
      }
      
      # Force Tesseract to actually run by accessing the text
      Rails.logger.info("OcrExtractionService: Calling Tesseract OCR (PSM mode: #{psm_mode})...")
      text = ocr.to_s.strip
      
      # If no text found with PSM 6, try PSM 7 (single line mode)
      if text.empty? && psm_mode == 6
        Rails.logger.debug("OcrExtractionService: No text with PSM 6, trying PSM 7 (single line)...")
        ocr_alt = RTesseract.new(temp_file.path, lang: @language)
        ocr_alt.config = {
          'tessedit_pageseg_mode' => '7',
          'tessedit_char_whitelist' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ÁÉÍÓÚáéíóúÑñÜü.,;:!?\-()/ '
        }
        text_alt = ocr_alt.to_s.strip
        text = text_alt if text_alt.length > text.length
      end
      
      elapsed = Time.now - start_time
      Rails.logger.info("OcrExtractionService: Tesseract completed in #{elapsed.round(2)}s")
      Rails.logger.info("OcrExtractionService: Tesseract raw output (#{text.length} chars): '#{text[0..300]}'")
      
      if text.empty?
        Rails.logger.warn("OcrExtractionService: WARNING - Tesseract returned empty string")
      end
      
    rescue StandardError => e
      elapsed = Time.now - start_time
      Rails.logger.error("OcrExtractionService: ERROR during Tesseract execution (#{elapsed.round(2)}s): #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      text = ''
    end

    # Clean up temp file
    temp_file.unlink

    text
  rescue StandardError => e
    Rails.logger.error("OcrExtractionService: ERROR in extract_text: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    ''
  ensure
    temp_file&.unlink if temp_file
  end

  def clean_text(text)
    return '' if text.blank?

    original_length = text.length
    original_text = text.dup

    # Remove excessive whitespace
    text = text.gsub(/\s+/, ' ')
    
    # Remove common OCR artifacts
    text = text.gsub(/[^\p{L}\p{N}\s.,;:!?\-()\/]/, '')
    
    # Remove very short "words" that are likely OCR errors (less than 2 characters)
    words = text.split(/\s+/)
    words = words.reject { |word| word.length < 2 && word.match?(/\d/) }
    
    cleaned = words.join(' ').strip

    if cleaned.length < original_length * 0.3 && original_length > 10
      Rails.logger.warn("OcrExtractionService: Text cleaning removed >70% (#{original_length} -> #{cleaned.length} chars)")
      Rails.logger.debug("OcrExtractionService: Original: '#{original_text[0..300]}'")
      Rails.logger.debug("OcrExtractionService: Cleaned: '#{cleaned[0..300]}'")
    end

    cleaned
  end
end

