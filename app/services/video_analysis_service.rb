# frozen_string_literal: true

class VideoAnalysisService
  # Phrases to filter out from analysis
  FILTERED_PHRASES = [
    'artículos relacionados',
    'adn digital',
    'share tweet',
    'tweet share',
    'copy link',
    'link copied'
  ].freeze

  MIN_WORD_LENGTH = 2

  def initialize(videos)
    @videos = videos
  end

  def self.bigram_occurrences(videos, limit = 100)
    new(videos).bigram_occurrences(limit)
  end

  def self.word_occurrences(videos, limit = 100)
    new(videos).word_occurrences(limit)
  end

  def bigram_occurrences(limit = 100)
    word_occurrences = Hash.new(0)

    @videos.find_each do |video|
      next if video.transcription.nil?

      words = video.transcription.gsub(/[[:punct:]]/, '').split
      bigrams = words.each_cons(2).map { |word1, word2| "#{word1.downcase} #{word2.downcase}" }
      
      bigrams.each do |bigram|
        next unless valid_bigram?(bigram)

        word_occurrences[bigram] += 1
      end
    end

    word_occurrences.select { |_bigram, count| count > 1 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  def word_occurrences(limit = 100)
    word_occurrences = Hash.new(0)

    @videos.find_each do |video|
      next if video.transcription.nil?

      words = video.transcription.gsub(/[[:punct:]]/, ' ').split
      
      words.each do |word|
        cleaned_word = word.downcase
        next unless valid_word?(cleaned_word)

        word_occurrences[cleaned_word] += 1
      end
    end

    word_occurrences.select { |_word, count| count > 1 }
                    .sort_by { |_k, v| v }
                    .reverse
                    .take(limit)
  end

  private

  def valid_bigram?(bigram)
    words = bigram.split
    return false unless words.length == 2
    
    first_word = words.first
    last_word = words.last
    
    return false if first_word.length <= MIN_WORD_LENGTH || last_word.length <= MIN_WORD_LENGTH
    return false if STOP_WORDS.include?(first_word) || STOP_WORDS.include?(last_word)
    return false if FILTERED_PHRASES.include?(bigram)

    true
  end

  def valid_word?(word)
    return false if STOP_WORDS.include?(word)
    return false if word.length <= MIN_WORD_LENGTH
    return false if ['https'].include?(word)

    true
  end
end

