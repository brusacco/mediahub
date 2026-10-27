# frozen_string_literal: true

# Temporary capture material must not be web-accessible. Finished archive files
# remain under public/videos for the existing Rails player.
class CaptureStorageService
  def self.staging_directory(station)
    Rails.root.join('storage', 'capture', station.directory, 'temp')
  end

  def self.legacy_staging_directory(station)
    Rails.public_path.join('videos', station.directory, 'temp')
  end

  def self.pending_directories(station)
    [staging_directory(station), legacy_staging_directory(station)].uniq
  end
end
