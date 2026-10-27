desc 'Tag newly transcribed videos once; use REPROCESS=1 only after changing tag definitions'
task tagger: :environment do
  scope = ENV['REPROCESS'] == '1' ? Video.has_transcription : Video.pending_tagging
  scope = scope.order(:id)
  limit = ENV['TAGGING_LIMIT'].to_i
  scope = scope.limit(limit) if limit.positive?

  total = scope.count
  completed = 0
  no_matches = 0
  failures = 0

  puts "Tagging #{total} video(s)#{ENV['REPROCESS'] == '1' ? ' (explicit reprocess)' : ''}"

  scope.find_each do |video|
    begin
      result = TaggerServices::ExtractTags.call(video.id)
      now = Time.current

      if result.success?
        video.update!(tag_list: result.data, tags_processed_at: now, tagging_error: nil,
                      tagging_attempts: video.tagging_attempts + 1)
        completed += 1
      elsif result.error == 'No tags found'
        # No matching tag is a valid result. Mark it complete so the timer
        # does not scan the same clip indefinitely.
        video.update!(tag_list: [], tags_processed_at: now, tagging_error: nil,
                      tagging_attempts: video.tagging_attempts + 1)
        no_matches += 1
      else
        video.update!(tagging_error: result.error, tagging_attempts: video.tagging_attempts + 1)
        failures += 1
        Rails.logger.warn("Tagging failed for video #{video.id}: #{result.error}")
      end
    rescue StandardError => e
      # Preserve prior tags on an operational failure. The next timer can retry.
      video.update_columns(tagging_error: e.message, tagging_attempts: video.tagging_attempts + 1,
                           updated_at: Time.current)
      failures += 1
      Rails.logger.error("Tagging exception for video #{video.id}: #{e.class}: #{e.message}")
    end
  end

  puts "Tagging complete. Tagged: #{completed}, no matching tags: #{no_matches}, failed: #{failures}"
  abort('Tagging completed with failures') if failures.positive?
end
