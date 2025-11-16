# frozen_string_literal: true

namespace :dev do
  namespace :cleanup do
    desc 'Kill all hanging Chrome processes from Selenium (only Selenium instances, not your main Chrome)'
    task chrome: :environment do
      puts 'Cleaning up hanging Chrome processes from Selenium...'
      
      # Only kill Chrome processes with Selenium-specific flags
      # These flags are unique to Chrome instances started by Selenium WebDriver
      selenium_patterns = [
        '--remote-debugging-port',  # Selenium uses this
        '--test-type',              # Selenium flag
        '--disable-background-networking', # Selenium flag
        '--disable-dev-shm-usage',  # Selenium flag
        'chromedriver'              # ChromeDriver process itself
      ]
      
      killed_count = 0
      selenium_patterns.each do |pattern|
        result = system("pkill -f 'chrome.*#{pattern}' 2>/dev/null")
        killed_count += 1 if result
      end
      
      sleep 1
      
      # Count remaining Chrome processes with Selenium flags
      selenium_chrome_count = `ps aux | grep -i chrome | grep -e '--remote-debugging-port' -e '--test-type' -e '--disable-background-networking' | grep -v grep | wc -l`.to_i
      
      if selenium_chrome_count > 0
        puts "Warning: #{selenium_chrome_count} Selenium Chrome processes still running"
        puts "You can manually kill them with: pkill -9 -f 'chrome.*--remote-debugging-port'"
      else
        puts 'All Selenium Chrome processes cleaned up successfully'
        puts 'Your main Chrome browser is safe and untouched'
      end
    end
  end
end

