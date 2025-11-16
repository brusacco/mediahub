# Code Review: `generate_transcription.rake`

## 📊 Overall Assessment: **Needs Improvement**

The rake task is functional but violates several Rails best practices and has maintainability concerns. The code mixes concerns, lacks proper abstraction, and has performance issues that will become problematic at scale.

---

## 🧩 Separation of Concerns

### Issues Found

1. **Business Logic in Rake Task** ❌
   - The transcription generation logic (command building, file handling, error processing) should be extracted into a service object
   - Rake tasks should be thin wrappers that orchestrate services, not contain business logic

2. **Mixed Responsibilities** ❌
   - File system operations, command execution, database updates, and logging are all mixed together
   - Should be separated into distinct concerns (service, file handler, logger)

3. **Direct Model Manipulation** ⚠️
   - The task directly accesses `video.station.directory` which can cause N+1 queries
   - Should use eager loading or delegate to the model

### Current Structure
```ruby
# Lines 14-56: Everything is in one block
Parallel.each(...) do |video|
  # Validation
  # File operations
  # Command building
  # Command execution
  # Database updates
  # Error handling
end
```

---

## 🔁 DRY Principles

### Issues Found

1. **Repeated Environment Checks** ❌
   ```ruby
   # Lines 7, 10-12: Repeated Rails.env.development? checks
   batch_size = Rails.env.development? ? 1 : 4
   model = Rails.env.development? ? 'small' : 'medium'
   device = Rails.env.development? ? 'cpu' : 'cuda'
   compute_type = Rails.env.development? ? 'int8' : 'float16'
   ```
   **Fix**: Extract to a configuration object or method

2. **File Existence Checks** ⚠️
   ```ruby
   # Lines 22, 29, 43, 45: Multiple File.exist? checks
   unless File.exist?(video.path)
   FileUtils.mkdir_p(directory_path) unless Dir.exist?(directory_path)
   if File.exist?(output_file)
   FileUtils.rm(output_file) if File.exist?(output_file)
   ```
   **Fix**: Use atomic operations (`FileUtils.mkdir_p` doesn't need existence check, `FileUtils.rm_f` is safe)

3. **String Manipulation** ⚠️
   ```ruby
   # Line 32: Manual string replacement
   output_file = File.join(directory_path, video.location.gsub('.mp4', '.txt'))
   ```
   **Fix**: Extract to a helper method or use `Pathname` methods

---

## 🧼 Code Quality & Clean Code

### Issues Found

1. **Inconsistent Logging** ❌
   - Uses `puts` instead of `Rails.logger` (lines 17, 23, 34, 46, 48, 51-52, 55)
   - Should use proper logging levels (`info`, `warn`, `error`)
   - Makes it hard to track in production logs

2. **Poor Error Handling** ❌
   - Generic `rescue StandardError` catches everything (line 54)
   - Doesn't distinguish between recoverable and fatal errors
   - No retry mechanism for transient failures
   - Errors are swallowed with `puts` instead of being logged properly

3. **Magic Strings** ⚠️
   ```ruby
   # Line 16: Hard-coded file extension check
   video.location.end_with?('.mp4')
   # Line 32: Hard-coded extension replacement
   video.location.gsub('.mp4', '.txt')
   # Line 38: Hard-coded language
   --language Spanish
   ```

4. **Unused Variable** ⚠️
   ```ruby
   # Line 40: stdout is captured but never used
   _stdout, stderr, status = Open3.capture3(command)
   ```

5. **Commented Code** ⚠️
   ```ruby
   # Line 37: Dead code should be removed
   # command = "whisper-ctranslate2 ... --vad_filter True ..."
   ```

6. **Inconsistent Naming** ⚠️
   - Spanish comments mixed with English code
   - Variable names are clear but could be more descriptive

---

## 🧭 Rails Best Practices

### Issues Found

1. **Not Using Model Scopes** ❌
   ```ruby
   # Line 14: Should use existing scope
   Video.where(transcription: nil)
   # Should be:
   Video.no_transcription
   ```

2. **N+1 Query Problem** ❌
   ```ruby
   # Line 28: Accesses station.directory without eager loading
   directory_path = Rails.public_path.join('videos', video.station.directory, 'temp')
   ```
   **Fix**: Use `.includes(:station)` or `.joins(:station)`

3. **Missing Validations** ⚠️
   - No validation that transcription was actually saved
   - No rollback mechanism if file cleanup fails

4. **Direct Database Updates** ⚠️
   ```ruby
   # Line 44: Direct update without validation
   video.update(transcription: File.read(output_file))
   ```
   Should handle validation errors

5. **No Transaction Safety** ❌
   - File operations and database updates are not atomic
   - If database update fails, file is already deleted

---

## ⚙️ Performance & Scalability

### Issues Found

1. **N+1 Query** ❌
   ```ruby
   # Line 14: No eager loading
   Parallel.each(Video.where(transcription: nil).order(posted_at: :desc), ...)
   # Line 28: Accesses association inside loop
   video.station.directory
   ```
   **Impact**: With 1000 videos, this creates 1000+ queries instead of 2

2. **Inefficient File Operations** ⚠️
   ```ruby
   # Line 45: Double file existence check
   FileUtils.rm(output_file) if File.exist?(output_file)
   ```
   **Fix**: `FileUtils.rm_f` is safe and doesn't need existence check

3. **Memory Concerns** ⚠️
   ```ruby
   # Line 44: Reads entire file into memory
   video.update(transcription: File.read(output_file))
   ```
   For large transcriptions, this could be problematic (though unlikely for text files)

4. **No Batch Processing** ⚠️
   - Processes all videos without limit
   - Could overwhelm system resources
   - No way to process in smaller chunks

5. **Parallel Processing Without Limits** ⚠️
   - `Parallel.each` with `in_processes: batch_size` could still overwhelm CPU
   - No consideration for system load or resource availability

---

## 🧠 Maintainability

### Issues Found

1. **Hard to Test** ❌
   - Cannot test transcription logic without executing external command
   - No dependency injection
   - Tightly coupled to file system and external tool

2. **Hard to Extend** ❌
   - Adding new transcription providers would require modifying the rake task
   - No abstraction for transcription service
   - Configuration is hardcoded

3. **No Monitoring/Telemetry** ❌
   - No metrics on success/failure rates
   - No timing information
   - No way to track which videos are problematic

4. **Poor Error Recovery** ❌
   - If a video fails, it's silently skipped
   - No retry mechanism
   - No way to mark videos as "failed" for later retry

5. **Configuration Not Centralized** ⚠️
   - Transcription settings scattered in rake task
   - Should be in initializer or environment config

---

## 🔧 Concrete Recommendations

### Priority 1: Critical Fixes

1. **Extract to Service Object**
   ```ruby
   # app/services/transcription_services/generate_transcription.rb
   module TranscriptionServices
     class GenerateTranscription < ApplicationService
       def initialize(video, options = {})
         @video = video
         @options = default_options.merge(options)
       end
       
       def call
         validate_video!
         generate_transcription_file
         save_transcription
         cleanup_temp_files
         handle_success(@video)
       rescue StandardError => e
         handle_error(e.message)
       end
       
       private
       
       def default_options
         {
           model: Rails.env.development? ? 'small' : 'medium',
           device: Rails.env.development? ? 'cpu' : 'cuda',
           compute_type: Rails.env.development? ? 'int8' : 'float16',
           language: 'Spanish'
         }
       end
       
       # ... rest of implementation
     end
   end
   ```

2. **Fix N+1 Query**
   ```ruby
   # In rake task
   Video.no_transcription
     .includes(:station)
     .order(posted_at: :desc)
   ```

3. **Use Proper Logging**
   ```ruby
   Rails.logger.info("Processing transcription for video #{video.id}")
   Rails.logger.error("Failed to generate transcription: #{error}")
   ```

4. **Use Model Scope**
   ```ruby
   Video.no_transcription.includes(:station).order(posted_at: :desc)
   ```

### Priority 2: Important Improvements

5. **Extract Configuration**
   ```ruby
   # config/initializers/transcription.rb
   TranscriptionConfig = OpenStruct.new(
     development: {
       batch_size: 1,
       model: 'small',
       device: 'cpu',
       compute_type: 'int8'
     },
     production: {
       batch_size: 4,
       model: 'medium',
       device: 'cuda',
       compute_type: 'float16'
     }
   )
   ```

6. **Add Model Methods**
   ```ruby
   # app/models/video.rb
   def transcription_output_path
     temp_dir.join(location.sub(/\.mp4\z/, '.txt'))
   end
   
   def temp_directory
     Rails.public_path.join('videos', station.directory, 'temp')
   end
   ```

7. **Improve Error Handling**
   ```ruby
   rescue TranscriptionError => e
     Rails.logger.error("Transcription failed: #{e.message}")
     mark_as_failed(e)
   rescue SystemCallError => e
     Rails.logger.error("System error: #{e.message}")
     retry_with_backoff
   end
   ```

8. **Add Atomic File Operations**
   ```ruby
   # Use FileUtils.rm_f instead of conditional rm
   FileUtils.rm_f(output_file)
   ```

### Priority 3: Nice to Have

9. **Add Monitoring**
   ```ruby
   ActiveSupport::Notifications.instrument('transcription.generated', video_id: video.id)
   ```

10. **Add Retry Mechanism**
    ```ruby
    retries = 0
    begin
      generate_transcription
    rescue => e
      retries += 1
      retry if retries < 3
      raise
    end
    ```

11. **Add Progress Tracking**
    ```ruby
    total = Video.no_transcription.count
    processed = 0
    # Log progress every 10%
    ```

12. **Extract Constants**
    ```ruby
    TRANSCRIPTION_LANGUAGE = 'Spanish'.freeze
    TEMP_DIRECTORY_NAME = 'temp'.freeze
    ```

---

## 📝 Refactored Rake Task (Example)

```ruby
# frozen_string_literal: true

desc 'Generate text transcription of video files'
task generate_transcription: :environment do
  config = TranscriptionConfig.send(Rails.env)
  
  videos = Video.no_transcription
                 .includes(:station)
                 .order(posted_at: :desc)
                 .limit(ENV.fetch('BATCH_LIMIT', 1000).to_i)
  
  processed = 0
  failed = 0
  
  Parallel.each(videos, in_processes: config.batch_size) do |video|
    result = TranscriptionServices::GenerateTranscription.call(
      video,
      model: config.model,
      device: config.device,
      compute_type: config.compute_type
    )
    
    if result.success?
      processed += 1
      Rails.logger.info("Transcription generated for video #{video.id}")
    else
      failed += 1
      Rails.logger.error("Failed transcription for video #{video.id}: #{result.error}")
    end
  end
  
  Rails.logger.info("Transcription batch complete: #{processed} succeeded, #{failed} failed")
end
```

---

## ✅ Summary

**Critical Issues**: 5
- N+1 queries
- Business logic in rake task
- Poor error handling
- No proper logging
- Not using model scopes

**Important Issues**: 4
- Configuration not centralized
- Hard to test
- No monitoring
- File operation inefficiencies

**Minor Issues**: 3
- Magic strings
- Commented code
- Inconsistent naming

**Estimated Refactoring Time**: 4-6 hours
**Risk Level**: Medium (changes are isolated to transcription feature)
**Recommended Action**: Refactor in phases, starting with service extraction and N+1 fix

