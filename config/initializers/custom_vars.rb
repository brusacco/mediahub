DAYS_RANGE = 7
stop = Rails.root.join('stop-words.txt').readlines.map(&:strip)
STOP_WORDS = stop << ['fbclid']