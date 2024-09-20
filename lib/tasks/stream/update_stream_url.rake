# frozen_string_literal: true

## lib/tasks/extract_stream.rake
require 'selenium-webdriver'

namespace :stream do
  desc 'Process video stream for a station'
  task :update_stream_url, [:station_id] => :environment do |_t, args|
    # Set up Selenium with ChromeDriver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless') # Run Chrome in headless mode (no GUI)
    options.add_argument('--disable-gpu')
    options.add_argument('--log-level=3') # Suppress logging

    # Initialize Chrome Driver with the updated options
    driver = Selenium::WebDriver.for(:chrome, options:)

    driver.intercept do |request, &continue|
      url = request.url
      if url.include?('playlist.m3u8') && @current_station
        puts "Found Stream URL: #{url}"
        puts '---------------------------------------------------------'
        # Update the station's stream_url when the stream URL is found
        @current_station.update(stream_url: url)
      elsif url.include?('paraguaytvhd.m3u8') ||
            url.include?('canalpropy.m3u8') ||
            url.include?('telefuturoparaguay.m3u8')
        puts "Twitch Found Stream URL: #{url}"
        puts '---------------------------------------------------------'
        # Update the station's stream_url when the stream URL is found
        @current_station.update(stream_url: url)
      elsif url.include?('index.m3u8') && @current_station.name == 'C9N'
        puts "Found Stream URL: #{url} C9N"
        puts '---------------------------------------------------------'
        # Update the station's stream_url when the stream URL is found
        @current_station.update(stream_url: url)
      end
      continue.call(request)
    end

    # Set timeouts
    driver.manage.timeouts.page_load = 120 # 60 seconds for page load
    driver.manage.timeouts.implicit_wait = 20 # 10 seconds to find elements
    driver.manage.timeouts.script_timeout = 60 # 30 seconds for scripts

    station = Station.find(args[:station_id])
    puts '---------------------------------------------------------'
    puts "Processing station stream URL: #{station.name}"
    @current_station = station
    # Navigate to the desired webpage
    driver.navigate.to(station.stream_source)

    # Close the browser after extraction
    driver.quit
  end
end
