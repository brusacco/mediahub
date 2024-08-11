# frozen_string_literal: true

require 'open3'

# Home controller
class HomeController < ApplicationController
  def index
    @videos = Video.where.not(transcription: nil).order(posted_at: :desc).limit(20)
  end

  def deploy
    Dir.chdir('/opt/rails/mediahub') do
      system('export RAILS_ENV=production')

      # Check out the latest code from the Git repository
      system('git pull')

      # Install dependencies
      system('bundle install')

      # Migrate the database
      system('RAILS_ENV=production rails db:migrate')

      # Precompile assets
      system('RAILS_ENV=production rake assets:precompile')

      # Restart the Puma server
      system('touch tmp/restart.txt')
    end

    render plain: 'Deployment complete!'
  end

  def merge_videos
    input_files = params[:selected_videos] # Array of input file paths
    output_directory = Rails.public_path.join('videos')
    output_file = File.join(output_directory, 'merged_video.mp4')

    # Extract filenames and sort selected files by filename
    input_files.sort_by! { |file_path| extract_filename(file_path) }
    temp_files = []

    # Execute FFmpeg commands for each selected video
    input_files.each_with_index do |file, index|
      temp_file = File.join(output_directory, "temp#{index + 1}.ts")
      temp_files << temp_file
      ffmpeg_command = "ffmpeg -y -i #{file} -c copy -bsf:v h264_mp4toannexb -f mpegts #{temp_file} 2>/dev/null &"
      Open3.capture3(ffmpeg_command)
    end

    # Concatenate temp files
    concat_command = "ffmpeg -f mpegts -i \"concat:#{temp_files.join('|')}\" -c copy -bsf:a aac_adtstoasc #{output_file}"
    Open3.capture3(concat_command)

    # Remove temp files
    temp_files.each { |temp_file| File.delete(temp_file) }

    # Respond with success or failure
    if File.exist?(output_file)
      flash[:success] = 'Videos merged successfully'
    else
      flash[:error] = 'Failed to merge videos'
    end

    # Execute the FFmpeg command

    redirect_to root_path
  end

  private

  def extract_filename(file_path)
    File.basename(file_path)
  end
end
