# frozen_string_literal: true

module ApplicationHelper
  def find_max_and_min_occurrences(word_occurrences)
    # Check if the input list is empty
    return if word_occurrences.empty?

    # Initialize variables to hold the maximum and minimum values
    max_occurrence = word_occurrences.first[1]
    min_occurrence = word_occurrences.first[1]

    # Iterate through the list and update max_occurrence and min_occurrence
    word_occurrences.each do |_word, occurrence|
      if occurrence > max_occurrence
        max_occurrence = occurrence
      elsif occurrence < min_occurrence
        min_occurrence = occurrence
      end
    end

    # Return the maximum and minimum occurrences as a hash
    {
      max: max_occurrence,
      min: min_occurrence
    }
  end

  def normalize_to_scale(value, max_value, min_value)
    # Ensure that max_value is greater than min_value to avoid division by zero
    # raise ArgumentError, 'max_value must be greater than min_value' if max_value <= min_value

    # Calculate the normalized value on a scale from 1 to 10
    normalized = (((value - min_value) * 9) / ((max_value - min_value) + 1))

    # Ensure the result is within the range [1, 10]
    normalized.clamp(1, 10)
  end

  def number_with_delimiter(number, options = {})
    delimiter = options[:delimiter] || '.'
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1#{delimiter}").reverse
  end
end
