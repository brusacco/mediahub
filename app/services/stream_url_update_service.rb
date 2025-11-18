# frozen_string_literal: true

require 'selenium-webdriver'

class StreamUrlUpdateService < ApplicationService
  PAGE_LOAD_TIMEOUT = 120
  IMPLICIT_WAIT_TIMEOUT = 20
  SCRIPT_TIMEOUT = 60
  NAVIGATION_WAIT_TIME = 10
  USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'.freeze
  MITMPROXY_LOG_PATH = '/tmp/mitm_m3u8.log'.freeze
  MITMPROXY_HOST = '127.0.0.1:8080'.freeze

  def self.call(station)
    new(station).call
  end

  def initialize(station)
    super()
    @station = station
    @reference_url = station.stream_url
    @reference_pattern = extract_reference_pattern(@reference_url) if @reference_url.present?
  end

  def call
    return handle_error('Station is required') unless @station
    return handle_error('Station stream_source is blank') if @station.stream_source.blank?

    # Check if mitmproxy is running before starting
    unless mitmproxy_running?
      error_msg = "Mitmproxy is not running on #{MITMPROXY_HOST}. Please start it with: mitmproxy --listen-port 8080 --mode regular -s capture_m3u8.py"
      Rails.logger.error(error_msg)
      return handle_error(error_msg)
    end

    # Clear mitmproxy log before starting
    clear_mitmproxy_log

    # Clean up any existing Chrome processes and old user data directories before starting
    cleanup_old_chrome_processes

    driver = nil
    begin
      driver = create_driver
      configure_timeouts(driver)
      
      # Navigate to the stream source
      puts "🚀 Navigating to: #{@station.stream_source}"
      Rails.logger.info("Navigating to: #{@station.stream_source}")
      driver.navigate.to(@station.stream_source)
      
      # Wait for page to load and allow time for stream URLs to be captured
      wait_for_page_load(driver)
      
      # Click play button if configured (some players require explicit click)
      if @station.play_button_selector.present?
        begin
          puts "🎬 Looking for play button with selector: #{@station.play_button_selector}"
          wait = Selenium::WebDriver::Wait.new(timeout: 5)
          play_button = wait.until { driver.find_element(:css, @station.play_button_selector) }
          play_button.click
          puts "✓ Clicked play button"
          sleep 2 # Wait a bit after clicking
        rescue Selenium::WebDriver::Error::TimeoutError
          Rails.logger.debug("Play button not found with selector: #{@station.play_button_selector}")
        rescue StandardError => e
          Rails.logger.debug("Could not click play button: #{e.message}")
        end
      end
      
      # Mute video to allow autoplay (fallback for players that don't need explicit click)
      # Don't mutate read-only properties like visibilityState
      begin
        driver.execute_script(<<~JS)
          (function() {
            const muteAndPlay = () => {
              const vids = document.querySelectorAll("video");
              vids.forEach(v => {
                v.muted = true;
                try { v.play().catch(() => {}) } catch(e) {}
              });
            };
            if (document.readyState === 'loading') {
              document.addEventListener("DOMContentLoaded", muteAndPlay);
            } else {
              muteAndPlay();
            }
          })();
        JS
      rescue StandardError => e
        Rails.logger.debug("Could not mute/play video: #{e.message}")
      end
      
      # Wait for mitmproxy to capture stream URLs
      puts "⏳ Waiting up to 15 seconds for stream URLs to be captured..."
      15.times do |i|
        sleep 1
        puts "  Waiting... (#{i + 1}/15 seconds)" if (i + 1) % 5 == 0
      end
      
      # Read captured URLs from mitmproxy log
      m3u8_urls = read_mitmproxy_log
      
      if m3u8_urls.any?
        # Select the best URL (longest/most complete, or matches reference pattern)
        best_url = select_best_url(m3u8_urls)
        
        @station.update!(stream_url: best_url)
        puts "✅ Successfully updated stream URL: #{best_url}"
        Rails.logger.info("Updated stream URL for station #{@station.id}: #{best_url}")
        handle_success(best_url)
      else
        puts "❌ No .m3u8 URLs found in mitmproxy log"
        Rails.logger.warn("No .m3u8 URLs found for station #{@station.id}")
        handle_error('No .m3u8 URLs found via mitmproxy')
      end
    rescue StandardError => e
      Rails.logger.error("StreamUrlUpdateService error for station #{@station&.id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      handle_error(e.message)
    ensure
      if driver
        begin
          driver.switch_to.default_content
        rescue StandardError
          # Ignore errors when switching back
        end
        
        begin
          driver.quit
        rescue StandardError => e
          Rails.logger.warn("Error closing Chrome driver: #{e.message}")
        end
        
        # Wait a moment for Chrome to fully terminate
        sleep 0.5
        
        # Kill any remaining Chrome/Chromium processes that might be orphaned
        begin
          # Kill Chrome processes with remote debugging (Selenium WebDriver instances)
          system("pkill -f 'chrome.*--remote-debugging-port' 2>/dev/null")
          system("pkill -f 'chromium.*--remote-debugging-port' 2>/dev/null")
          # Kill Chrome processes with test-type flag (headless Chrome)
          system("pkill -f 'chrome.*--test-type' 2>/dev/null")
          system("pkill -f 'chromium.*--test-type' 2>/dev/null")
        rescue StandardError => e
          Rails.logger.debug("Error killing Chrome processes: #{e.message}")
        end
      end
    end
  end

  private

  def create_driver
    proxy_ip = MITMPROXY_HOST

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-prompt-on-repost')
    options.add_argument('--ignore-certificate-errors')
    options.add_argument('--ignore-ssl-errors=yes')
    options.add_argument('--disable-web-security')
    options.add_argument('--disable-site-isolation-trials')
    options.add_argument('--disable-popup-blocking')
    options.add_argument('--disable-translate')
    options.add_argument('--log-level=3')
    options.add_argument("--user-agent=#{USER_AGENT}")
    options.add_argument("--proxy-server=http://#{proxy_ip}")
    options.add_argument('--timeout=60')

    driver = Selenium::WebDriver.for(:chrome, options: options)
    driver.manage.timeouts.implicit_wait = 10
    driver
  end

  def configure_timeouts(driver)
    driver.manage.timeouts.page_load = PAGE_LOAD_TIMEOUT
    driver.manage.timeouts.implicit_wait = IMPLICIT_WAIT_TIMEOUT
    driver.manage.timeouts.script_timeout = SCRIPT_TIMEOUT
  end

  def clear_mitmproxy_log
    begin
      File.write(MITMPROXY_LOG_PATH, '')
      puts "✓ Cleared mitmproxy log"
    rescue StandardError => e
      Rails.logger.warn("Could not clear mitmproxy log: #{e.message}")
    end
  end

  def mitmproxy_running?
    # Check if mitmproxy is listening on port 8080
    begin
      require 'socket'
      socket = Socket.tcp(MITMPROXY_HOST.split(':').first, MITMPROXY_HOST.split(':').last.to_i, connect_timeout: 2)
      socket.close
      true
    rescue StandardError => e
      Rails.logger.debug("Mitmproxy check failed: #{e.message}")
      false
    end
  end

  def read_mitmproxy_log
    return [] unless File.exist?(MITMPROXY_LOG_PATH)

    begin
      urls = File.read(MITMPROXY_LOG_PATH)
                .split("\n")
                .map(&:strip)
                .reject(&:empty?)
                .uniq
      
      puts "📡 Found #{urls.length} .m3u8 URL(s) in mitmproxy log"
      urls.each { |url| puts "  → #{url}" }
      
      urls
    rescue StandardError => e
      Rails.logger.error("Error reading mitmproxy log: #{e.message}")
      []
    end
  end

  def select_best_url(urls)
    return urls.first if urls.length == 1

    # Filter by reference pattern if available
    if @reference_url || @reference_pattern
      matching_urls = urls.select { |url| stream_url_matches_reference?(url) }
      urls = matching_urls if matching_urls.any?
    end

    # Prioritize URLs with authentication parameters
    urls_with_auth = urls.select { |url| (url.include?('k=') && url.include?('exp=')) || url.include?('auth=') }
    
    # Prioritize playlist.m3u8 over chunklist
    playlist_urls = (urls_with_auth.any? ? urls_with_auth : urls).select { |url| url.include?('playlist.m3u8') }
    
    # Select: playlist with auth > playlist > longest URL with auth > longest URL
    if playlist_urls.any?
      playlist_urls.max_by(&:length)
    elsif urls_with_auth.any?
      urls_with_auth.max_by(&:length)
    else
      urls.max_by(&:length)
    end
  end

  def stream_url_matches_reference?(url)
    return false unless url.include?('.m3u8')
    
    # If we have a reference URL, extract path patterns and match against ANY domain
    if @reference_url
      # Extract key path segments from reference URL (e.g., "megacadena1/megacadena1")
      path_segments = @reference_url.scan(%r{/([^/]+/[^/]+)/playlist\.m3u8})
      if path_segments.any?
        path_pattern = path_segments.first.first
        return url.include?(path_pattern) && url.include?('playlist.m3u8') if path_pattern
      end
      
      # Also check for single segment patterns
      single_segment = @reference_url.scan(%r{/([^/]+)/playlist\.m3u8})
      if single_segment.any?
        path_pattern = single_segment.first.first
        return url.include?(path_pattern) && url.include?('playlist.m3u8') if path_pattern
      end
      
      # If we have a reference pattern, also check domain match as fallback
      if @reference_pattern
        domain_match = url.include?(@reference_pattern[:domain])
        path_match = @reference_pattern[:path_base].blank? || url.include?(@reference_pattern[:path_base])
        return domain_match && path_match
      end
    end
    
    # Fallback: if no reference URL, accept any playlist.m3u8
    url.include?('playlist.m3u8')
  end

  def extract_reference_pattern(reference_url)
    return nil unless reference_url.present?
    
    begin
      uri = URI.parse(reference_url)
      domain = uri.host
      
      path_parts = uri.path.split('/').reject(&:empty?)
      
      if path_parts.length > 1
        path_base = path_parts[0..-2].join('/')
      else
        path_base = path_parts.first || ''
      end
      
      {
        domain: domain,
        path_base: path_base
      }
    rescue URI::InvalidURIError
      domain_match = reference_url.match(%r{https?://([^/]+)})
      
      path_base = ''
      path_match = reference_url.match(%r{https?://[^/]+/([^/?]+/)?([^/?]+/)?([^/?]+)})
      if path_match
        path_segments = reference_url.scan(%r{https?://[^/]+/([^/?]+)}).flatten
        path_base = path_segments[0..-2].join('/') if path_segments.length > 1
        path_base = path_segments.first if path_base.empty? && path_segments.any?
      end
      
      {
        domain: domain_match ? domain_match[1] : '',
        path_base: path_base
      }
    end
  end

  def cleanup_old_chrome_processes
    # Kill any existing Chrome/Chromium processes that might be orphaned
    begin
      # Kill Chrome processes with remote debugging (Selenium WebDriver instances)
      # Support both 'chrome' and 'chromium' binary names (Ubuntu often uses chromium)
      system("pkill -f 'chrome.*--remote-debugging-port' 2>/dev/null")
      system("pkill -f 'chromium.*--remote-debugging-port' 2>/dev/null")
      # Kill Chrome processes with test-type flag (headless Chrome)
      system("pkill -f 'chrome.*--test-type' 2>/dev/null")
      system("pkill -f 'chromium.*--test-type' 2>/dev/null")
      # Wait a moment for processes to terminate
      sleep 0.5
    rescue StandardError => e
      Rails.logger.debug("Error during Chrome cleanup: #{e.message}")
    end
  end

  def wait_for_page_load(driver)
    wait = Selenium::WebDriver::Wait.new(timeout: NAVIGATION_WAIT_TIME)
    begin
      wait.until { driver.execute_script('return document.readyState') == 'complete' }
    rescue Selenium::WebDriver::Error::TimeoutError
      # Ignore timeout - continue anyway
    end
    
    begin
      wait.until do
        jquery_ready = driver.execute_script('return typeof jQuery === "undefined" || jQuery.active === 0')
        doc_ready = driver.execute_script('return document.readyState') == 'complete'
        jquery_ready && doc_ready
      end
    rescue Selenium::WebDriver::Error::TimeoutError
      # Ignore timeout - continue anyway
    end
    
    sleep 1
  end
end
