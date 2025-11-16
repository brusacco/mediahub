# frozen_string_literal: true

# Extend ActiveRecord::Relation to add analysis methods
# This allows calling word_occurrences and bigram_occurrences directly on relations
module ActiveRecord
  class Relation
    def bigram_occurrences(limit = 100)
      VideoAnalysisService.bigram_occurrences(self, limit)
    end

    def word_occurrences(limit = 100)
      VideoAnalysisService.word_occurrences(self, limit)
    end
  end
end





