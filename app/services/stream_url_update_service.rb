# frozen_string_literal: true

require 'selenium-webdriver'
require 'open3'
require 'json'
require 'uri'

class StreamUrlUpdateService < ApplicationService
  PAGE_LOAD_TIMEOUT = 120
  IMPLICIT_WAIT_TIMEOUT = 20
  SCRIPT_TIMEOUT = 60
  NAVIGATION_WAIT_TIME = 10
  USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'.freeze
  MITMPROXY_LOG_PATH = '/tmp/mitm_m3u8.log'.freeze
  MITMPROXY_HOST = '127.0.0.1:8080'.freeze
  DISCOVERY_LOCK_PATH = '/tmp/mediahub-stream-discovery.lock'.freeze

  def self.call(station)
    new(station).call
  end

  def initialize(station)
    super()
    @station = station
    @reference_url = station.stream_url
    @reference_pattern = extract_reference_pattern(@reference_url) if @reference_url.present?
    @user_data_dir = nil
  end

  def call
    return handle_error('Station is required') unless @station
    return handle_error('Station stream_source is blank') if @station.stream_source.blank?

    with_discovery_lock { discover_with_configured_method }
  end

  private

  # The default remains the proven Selenium + mitmproxy path. Ferrum can be
  # exercised independently or used as a recovery path without changing the
  # listener code or its systemd unit.
  #
  # STREAM_DISCOVERY_METHOD=legacy             # default
  # STREAM_DISCOVERY_METHOD=ferrum             # trial Ferrum only
  # STREAM_DISCOVERY_METHOD=ferrum_then_legacy # Ferrum, then legacy fallback
  # STREAM_DISCOVERY_METHOD=legacy_then_ferrum # legacy, then Ferrum fallback
  def discover_with_configured_method
    case ENV.fetch('STREAM_DISCOVERY_METHOD', 'legacy')
    when 'legacy'
      discover
    when 'ferrum'
      FerrumStreamDiscoveryService.call(@station)
    when 'ferrum_then_legacy'
      ferrum_result = FerrumStreamDiscoveryService.call(@station)
      ferrum_result.success? ? ferrum_result : discover
    when 'legacy_then_ferrum'
      legacy_result = discover
      legacy_result.success? ? legacy_result : FerrumStreamDiscoveryService.call(@station)
    else
      handle_error("Unknown STREAM_DISCOVERY_METHOD: #{ENV['STREAM_DISCOVERY_METHOD']}")
    end
  end

  def discover
    # Check if mitmproxy is running before starting
    unless mitmproxy_running?
      error_msg = "Mitmproxy is not running on #{MITMPROXY_HOST}. Please start it with: mitmproxy --listen-port 8080 --mode regular -s capture_m3u8.py"
      Rails.logger.error(error_msg)
      return handle_error(error_msg)
    end

    # Clear mitmproxy log before starting
    clear_mitmproxy_log

    # A configuration-only embedded player can publish the fresh manifest
    # without a browser navigation or a play gesture. Resolve that path first:
    # it avoids Chrome startup plus the fixed capture wait on every renewal.
    embedded_manifest_urls = manifest_urls_from_embedded_players
    return promote_manifest_urls(embedded_manifest_urls) if embedded_manifest_urls.any?

    # Clean up any existing Chrome processes and old user data directories before starting
    cleanup_old_chrome_processes

    driver = nil
    begin
      driver = create_driver
      configure_timeouts(driver)
      
      # Navigate to the stream source
      puts "🚀 Navigating to: #{@station.stream_source}"
      Rails.logger.info("Navigating to: #{@station.stream_source}")
      begin
        driver.navigate.to(@station.stream_source)
      rescue Selenium::WebDriver::Error::WebDriverError => e
        # Some video pages close or replace the initial window after the stream
        # request is sent. Continue because mitmproxy may have captured it.
        Rails.logger.debug("Navigation ended early: #{e.message}")
      end
      
      # Wait for page to load and allow time for stream URLs to be captured
      wait_for_page_load(driver)
      @browser_request_headers = request_headers_from(driver)
      
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

      # Some broadcasters publish an HLS source in their page configuration,
      # but do not request it until a real user interaction occurs. Read that
      # configuration before falling back to a second browser navigation.
      if m3u8_urls.empty?
        m3u8_urls = manifest_urls_from_page(driver)
      end

      # Selenium's rendered DOM can omit inline configuration scripts. Fetch
      # the original response as a second source of truth for those players.
      if m3u8_urls.empty?
        m3u8_urls = manifest_urls_from_source
      end

      # Several broadcasters expose the player as a cross-origin iframe. Its
      # manifest is consequently absent from the parent DOM and source HTML;
      # clicking the iframe element itself also does not produce a play event
      # inside the embedded player. Read the declared player configuration
      # with the parent page as Referer instead.
      if m3u8_urls.empty?
        m3u8_urls = manifest_urls_from_embedded_players
      end

      # Trece is embedded through Dailymotion. Its player gets the temporary
      # HLS URL from Dailymotion's metadata endpoint rather than directly
      # loading it on the broadcaster's page.
      if m3u8_urls.empty?
        m3u8_urls = dailymotion_manifest_urls(driver)
      end

      # Some broadcaster pages close Selenium's initial window before the
      # player starts. Retrying with Chrome's headless DOM renderer still
      # traverses the page through mitmproxy and captures autoplay streams.
      if m3u8_urls.empty?
        capture_with_headless_chrome
        sleep 3
        m3u8_urls = read_mitmproxy_log
      end
      
      if m3u8_urls.any?
        promote_manifest_urls(m3u8_urls)
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
        sleep 1
        
        # Kill any remaining Chrome/Chromium processes that might be orphaned
        begin
          # Kill Chrome processes with remote debugging (Selenium WebDriver instances)
          system("pkill -9 -f 'chrome.*--remote-debugging-port' 2>/dev/null")
          system("pkill -9 -f 'chromium.*--remote-debugging-port' 2>/dev/null")
          # Kill Chrome processes with test-type flag (headless Chrome)
          system("pkill -9 -f 'chrome.*--test-type' 2>/dev/null")
          system("pkill -9 -f 'chromium.*--test-type' 2>/dev/null")
          # Kill any Chrome processes using our specific user data directory
          if @user_data_dir
            system("pkill -9 -f 'chrome.*--user-data-dir=#{@user_data_dir}' 2>/dev/null")
            system("pkill -9 -f 'chromium.*--user-data-dir=#{@user_data_dir}' 2>/dev/null")
          end
        rescue StandardError => e
          Rails.logger.debug("Error killing Chrome processes: #{e.message}")
        end
        
        # Clean up user data directory after Chrome processes are killed
        if @user_data_dir
          begin
            # Remove lock files first
            # FileUtils.rm_f handles non-existent files gracefully
            lock_file = File.join(@user_data_dir, 'SingletonLock')
            FileUtils.rm_f(lock_file)
            
            # Wait a bit more for any remaining file handles to close
            sleep 0.5
            
            # Remove the directory
            # FileUtils.rm_rf handles non-existent directories gracefully
            FileUtils.rm_rf(@user_data_dir)
            Rails.logger.debug("Cleaned up Chrome user data directory: #{@user_data_dir}")
          rescue StandardError => e
            Rails.logger.warn("Could not clean up Chrome user data directory #{@user_data_dir}: #{e.message}")
            # Try once more after a delay
            begin
              sleep 1
              FileUtils.rm_rf(@user_data_dir)
            rescue StandardError => e2
              Rails.logger.warn("Second cleanup attempt also failed: #{e2.message}")
            end
          end
        end
      end
    end
  end

  def create_driver
    proxy_ip = MITMPROXY_HOST

    # Kill any Chrome processes one more time right before creating the driver
    # This ensures no processes are using directories
    system("pkill -9 -f 'chrome.*--remote-debugging-port' 2>/dev/null")
    system("pkill -9 -f 'chromium.*--remote-debugging-port' 2>/dev/null")
    system("pkill -9 -f 'chrome.*--test-type' 2>/dev/null")
    system("pkill -9 -f 'chromium.*--test-type' 2>/dev/null")
    system("pkill -9 -f 'chrome.*--user-data-dir=/tmp/chrome_profile_' 2>/dev/null")
    system("pkill -9 -f 'chromium.*--user-data-dir=/tmp/chrome_profile_' 2>/dev/null")
    sleep 0.5

    # Create a unique user data directory with timestamp and random suffix
    # This ensures uniqueness even if multiple instances run simultaneously
    timestamp = Time.now.to_i
    random_suffix = SecureRandom.hex(8)
    @user_data_dir = "/tmp/chrome_profile_#{@station.id}_#{timestamp}_#{random_suffix}"
    
    # Ensure directory doesn't exist and create it fresh
    # FileUtils.rm_rf handles non-existent directories gracefully
    FileUtils.rm_rf(@user_data_dir)
    
    # Create the directory
    FileUtils.mkdir_p(@user_data_dir)
    
    # Remove any lock files that might exist
    # FileUtils.rm_f handles non-existent files gracefully
    lock_file = File.join(@user_data_dir, 'SingletonLock')
    FileUtils.rm_f(lock_file)

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
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
    options.add_argument("--user-data-dir=#{@user_data_dir}")
    # Disable Chrome's user data directory locking to prevent "directory already in use" errors
    options.add_argument('--disable-features=ChromeUserDataDirLocking')

    driver = Selenium::WebDriver.for(:chrome, options: options)
    driver.manage.timeouts.implicit_wait = 10
    driver
  end

  def with_discovery_lock
    File.open(DISCOVERY_LOCK_PATH, File::RDWR | File::CREAT, 0o600) do |lock_file|
      begin
        lock_file.flock(File::LOCK_EX)
        yield
      ensure
        lock_file.flock(File::LOCK_UN)
      end
    end
  end

  def capture_with_headless_chrome
    command = [
      'timeout', '45', 'google-chrome', '--headless=new', '--no-sandbox',
      '--disable-dev-shm-usage', '--disable-gpu', '--ignore-certificate-errors',
      "--user-agent=#{USER_AGENT}", "--proxy-server=http://#{MITMPROXY_HOST}",
      '--dump-dom', @station.stream_source
    ]
    _stdout, stderr, status = Open3.capture3(*command)
    Rails.logger.debug("Headless Chrome fallback exited #{status.exitstatus}: #{stderr}") unless status.success?
  rescue StandardError => e
    Rails.logger.warn("Headless Chrome fallback failed: #{e.message}")
  end

  def manifest_urls_from_page(driver)
    source = driver.page_source
    urls = extract_manifest_urls(source)
    Rails.logger.info("Found #{urls.length} manifest URL(s) in page source for station #{@station.id}")
    urls
  rescue StandardError => e
    Rails.logger.debug("Could not read manifest URLs from page source: #{e.message}")
    []
  end

  def manifest_urls_from_source
    urls = extract_manifest_urls(source_page_body)
    Rails.logger.info("Found #{urls.length} manifest URL(s) in source HTML for station #{@station.id}")
    urls
  rescue StandardError => e
    Rails.logger.debug("Could not read manifest URLs from source HTML: #{e.message}")
    []
  end

  def manifest_urls_from_embedded_players
    iframe_urls = source_page_body.scan(/<iframe\b[^>]*\bsrc=["']([^"']+)["']/i).flatten.filter_map do |src|
      URI.join(@station.stream_source, src).to_s
    rescue URI::InvalidURIError
      nil
    end.uniq

    urls = iframe_urls.flat_map do |iframe_url|
      extract_manifest_urls(embedded_player_body(iframe_url))
    end.uniq
    Rails.logger.info("Found #{urls.length} manifest URL(s) in embedded player source for station #{@station.id}")
    urls
  rescue StandardError => e
    Rails.logger.debug("Could not read manifest URLs from embedded player: #{e.message}")
    []
  end

  def promote_manifest_urls(urls)
    best_url = select_best_url(urls)
    result = StreamSourcePromotionService.call(
      @station, best_url, resolver: 'legacy',
      headers: request_headers
    )
    return result unless result.success?

    puts "✅ Successfully updated stream URL: #{redacted_url(best_url)}"
    Rails.logger.info("Updated stream URL for station #{@station.id}: #{redacted_url(best_url)}")
    handle_success(best_url)
  end

  # A signed manifest may be bound to the browser session that obtained it.
  # Persist only the cookie header needed by FFmpeg, never the raw URL in logs.
  def request_headers_from(driver)
    cookies = driver.manage.all_cookies.map { |cookie| "#{cookie[:name]}=#{cookie[:value]}" }.join('; ')
    request_headers.merge('Cookie' => cookies.presence).compact
  rescue StandardError => e
    Rails.logger.debug("Could not read browser cookies for station #{@station.id}: #{e.message}")
    request_headers
  end

  def request_headers
    (@browser_request_headers || { 'Referer' => @station.stream_source, 'User-Agent' => USER_AGENT }).compact
  end

  def redacted_url(url)
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}#{uri.path}"
  rescue URI::InvalidURIError
    '[unparseable manifest URL]'
  end

  def dailymotion_manifest_urls(driver)
    # The embedded player can close Selenium's window. The original source is
    # sufficient to identify Dailymotion, so do not let an unavailable browser
    # session prevent the metadata fallback.
    source = source_page_body.dup
    begin
      source << "\n#{driver.page_source}"
    rescue StandardError => e
      Rails.logger.debug("Could not append rendered DOM for Dailymotion: #{e.message}")
    end
    video_id = source[%r{dailymotion\.com/player/[^"']*?[?&]video=([A-Za-z0-9]+)}i, 1]
    return [] if video_id.blank?

    endpoint = "https://www.dailymotion.com/player/metadata/video/#{video_id}?embedder=#{URI.encode_www_form_component(@station.stream_source)}"
    stdout, stderr, status = Open3.capture3(
      'curl', '--fail', '--location', '--silent', '--show-error', '--max-time', '30',
      '--user-agent', USER_AGENT, '--referer', @station.stream_source, endpoint
    )
    unless status.success?
      Rails.logger.debug("Dailymotion metadata request failed: #{stderr}")
      return []
    end

    metadata = JSON.parse(stdout)
    urls = metadata.fetch('qualities', {}).values.flatten.filter_map do |quality|
      url = quality['url']
      url if quality['type'].to_s.include?('mpegURL') && url.present?
    end
    Rails.logger.info("Found #{urls.length} Dailymotion HLS URL(s) for station #{@station.id}")
    urls.uniq
  rescue JSON::ParserError, StandardError => e
    Rails.logger.debug("Could not resolve Dailymotion manifest: #{e.message}")
    []
  end

  def extract_manifest_urls(source)
    normalized = source.to_s
                       .gsub('\\/', '/')
                       .gsub('\\u0026', '&')
                       .gsub('&amp;', '&')
    normalized.scan(%r{https?://[^"'<>\s]+\.(?:m3u8|mpd)(?:\?[^"'<>\s]*)?}i).uniq
  end

  def source_page_body
    return @source_page_body if defined?(@source_page_body)

    @source_page_body = fetch_page_body(@station.stream_source)
  end

  def embedded_player_body(url)
    # Player pages commonly cache the signed manifest for their full cache
    # lifetime. A cache-busting query makes each renewal retrieve the current
    # player configuration rather than a nearly-expired page.
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query.to_s)
    params << ['mediahub_refresh', Time.now.to_i.to_s]
    uri.query = URI.encode_www_form(params)
    fetch_page_body(uri.to_s, referer: @station.stream_source)
  end

  def fetch_page_body(url, referer: nil)
    command = [
      'curl', '--fail', '--location', '--silent', '--show-error', '--max-time', '30',
      '--user-agent', USER_AGENT
    ]
    command.concat(['--referer', referer]) if referer.present?
    command << url

    stdout, stderr, status = Open3.capture3(*command)
    raise "Could not fetch source: #{stderr}" unless status.success?

    stdout
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
      puts "🧹 Cleaning up old Chrome processes..."
      
      # Kill Chrome processes with remote debugging (Selenium WebDriver instances)
      # Support both 'chrome' and 'chromium' binary names (Ubuntu often uses chromium)
      # Use -9 for immediate termination
      system("pkill -9 -f 'chrome.*--remote-debugging-port' 2>/dev/null")
      system("pkill -9 -f 'chromium.*--remote-debugging-port' 2>/dev/null")
      # Kill Chrome processes with test-type flag (headless Chrome)
      system("pkill -9 -f 'chrome.*--test-type' 2>/dev/null")
      system("pkill -9 -f 'chromium.*--test-type' 2>/dev/null")
      # Kill any Chrome processes using /tmp/chrome_profile_*
      system("pkill -9 -f 'chrome.*--user-data-dir=/tmp/chrome_profile_' 2>/dev/null")
      system("pkill -9 -f 'chromium.*--user-data-dir=/tmp/chrome_profile_' 2>/dev/null")
      
      # Wait for processes to terminate
      sleep 1
      
      # Clean up old chrome profile directories in /tmp (older than 1 hour)
      begin
        Dir.glob('/tmp/chrome_profile_*').each do |dir|
          if File.directory?(dir) && (Time.now - File.mtime(dir)) > 3600
            FileUtils.rm_rf(dir)
            Rails.logger.debug("Cleaned up old Chrome profile directory: #{dir}")
          end
        rescue StandardError => e
          Rails.logger.debug("Could not clean up directory #{dir}: #{e.message}")
        end
      rescue StandardError => e
        Rails.logger.debug("Error cleaning up old directories: #{e.message}")
      end
      
      puts "✓ Chrome cleanup complete"
    rescue StandardError => e
      Rails.logger.debug("Error during Chrome cleanup: #{e.message}")
    end
  end

  def wait_for_page_load(driver)
    wait = Selenium::WebDriver::Wait.new(timeout: NAVIGATION_WAIT_TIME)
    begin
      wait.until { driver.execute_script('return document.readyState') == 'complete' }
    rescue Selenium::WebDriver::Error::WebDriverError => e
      # Some embedded players close their window after issuing the media request.
      # The proxy may already have captured the m3u8, so continue to read it.
      Rails.logger.debug("Page readiness check ended early: #{e.message}")
    end
    
    begin
      wait.until do
        jquery_ready = driver.execute_script('return typeof jQuery === "undefined" || jQuery.active === 0')
        doc_ready = driver.execute_script('return document.readyState') == 'complete'
        jquery_ready && doc_ready
      end
    rescue Selenium::WebDriver::Error::WebDriverError => e
      Rails.logger.debug("JavaScript readiness check ended early: #{e.message}")
    end
    
    sleep 1
  end
end
