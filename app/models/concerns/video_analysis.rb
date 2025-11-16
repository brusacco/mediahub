# frozen_string_literal: true

module VideoAnalysis
  extend ActiveSupport::Concern

  included do
    # These methods are delegated to VideoAnalysisService
    # They work on ActiveRecord::Relation instances via the initializer extension
  end

  module ClassMethods
    def bigram_occurrences(limit = 100)
      VideoAnalysisService.bigram_occurrences(all, limit)
    end

    def word_occurrences(limit = 100)
      VideoAnalysisService.word_occurrences(all, limit)
    end
  end
end

