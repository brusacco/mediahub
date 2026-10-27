# frozen_string_literal: true

require 'ferrum'

# Discovers a manifest requested by the real player through Chrome DevTools
# Protocol. It is deliberately independent from Selenium and mitmproxy so it
# can be enabled as an isolated recovery method while the legacy path stays
# available.
class FerrumStreamDiscoveryService < ApplicationService
  BROWSER_TIMEOUT = 20
  MANIFEST_WAIT_SECONDS = 12
  USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'.freeze
  MANIFEST_URL_PATTERN = %r{\Ahttps?://.+\.(?:m3u8|mpd)(?:\?.*)?\z}i.freeze

  def initialize(station)
    super()
    @station = station
  end

  def call
    return handle_error('Station is required') unless @station
    return handle_error('Station stream_source is blank') if @station.stream_source.blank?

    browser = build_browser
    page = browser.create_page
    page.network.clear(:traffic)

    begin
      page.go_to(@station.stream_source)
    rescue Ferrum::TimeoutError, Ferrum::PendingConnectionsError => e
      # Live players often keep a connection open indefinitely. Traffic
      # collected before the timeout is still useful for manifest discovery.
      Rails.logger.debug("Ferrum navigation timed out for station #{@station.id}: #{e.message}")
    end

    click_play_button(page)
    play_video_elements(page)
    manifest_urls = wait_for_manifest_urls(page)

    return handle_error('No .m3u8 or .mpd URL found via Ferrum') if manifest_urls.empty?

    best_url = select_best_url(manifest_urls)
    promotion = StreamSourcePromotionService.call(
      @station, best_url, resolver: 'ferrum',
      headers: { 'Referer' => @station.stream_source, 'User-Agent' => USER_AGENT }
    )
    return promotion unless promotion.success?

    @station.add_log_entry("Ferrum renewed stream URL: #{redacted_url(best_url)}")
    Rails.logger.info("Ferrum renewed stream URL for station #{@station.id}")
    handle_success(best_url)
  rescue Ferrum::Error, StandardError => e
    Rails.logger.warn("Ferrum discovery failed for station #{@station&.id}: #{e.class}: #{e.message}")
    handle_error("Ferrum discovery failed: #{e.message}")
  ensure
    browser&.quit
  end

  private

  def build_browser
    Ferrum::Browser.new(
      browser_path: chrome_binary,
      timeout: BROWSER_TIMEOUT,
      process_timeout: BROWSER_TIMEOUT,
      window_size: [1280, 720],
      browser_options: {
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil,
        'ignore-certificate-errors' => nil,
        'autoplay-policy' => 'no-user-gesture-required',
        'user-agent' => USER_AGENT
      }
    )
  end

  def chrome_binary
    ENV['FERRUM_BROWSER_PATH'].presence || %w[/usr/bin/google-chrome /usr/bin/google-chrome-stable /usr/bin/chromium /usr/bin/chromium-browser].find { |path| File.executable?(path) }
  end

  def click_play_button(page)
    return if @station.play_button_selector.blank?

    selector = @station.play_button_selector
    button = wait_for_selector(page, selector)
    if button
      # This goes through CDP's mouse input rather than HTMLElement#click(),
      # giving players the trusted user gesture required to begin playback.
      button.click
      Rails.logger.info("Ferrum sent native play click for station #{@station.id}")
      return
    end

    # Closed or nested shadow roots cannot be located through page.at_css.
    # Fall back to an in-page click for the stations that expose an open root.
    clicked = page.evaluate(<<~JS, selector: selector)
      (selector) => {
        const findDeep = (root) => {
          const direct = root.querySelector(selector);
          if (direct) return direct;
          for (const element of root.querySelectorAll('*')) {
            if (element.shadowRoot) {
              const match = findDeep(element.shadowRoot);
              if (match) return match;
            }
          }
          return null;
        };
        const element = findDeep(document);
        if (!element) return false;
        element.click();
        return true;
      }
    JS
    Rails.logger.info("Ferrum clicked play selector for station #{@station.id}") if clicked
  rescue Ferrum::Error, StandardError => e
    Rails.logger.debug("Ferrum could not click play selector for station #{@station.id}: #{e.message}")
  end

  def wait_for_selector(page, selector)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
    loop do
      element = page.at_css(selector)
      return element if element
      return nil if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.5
    end
  rescue Ferrum::Error => e
    Rails.logger.debug("Ferrum could not locate #{selector.inspect} for station #{@station.id}: #{e.message}")
    nil
  end

  def play_video_elements(page)
    page.evaluate(<<~JS)
      document.querySelectorAll('video').forEach((video) => {
        video.muted = true;
        video.play().catch(() => {});
      });
    JS
  rescue Ferrum::Error, StandardError => e
    Rails.logger.debug("Ferrum could not start video elements for station #{@station.id}: #{e.message}")
  end

  def wait_for_manifest_urls(page)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MANIFEST_WAIT_SECONDS
    loop do
      urls = manifest_urls_from_traffic(page)
      return urls if urls.any?
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 1
    end
    []
  end

  def manifest_urls_from_traffic(page)
    page.network.traffic.filter_map do |exchange|
      url = exchange.request&.url || exchange.url
      url if url&.match?(MANIFEST_URL_PATTERN)
    end.uniq
  end

  def select_best_url(urls)
    StreamUrlUpdateService.new(@station).send(:select_best_url, urls)
  end

  def redacted_url(url)
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}#{uri.path}"
  rescue URI::InvalidURIError
    '[unparseable manifest URL]'
  end
end
