# frozen_string_literal: true

module Gitingest
  class ProgressIndicator
    BAR_WIDTH = 30

    def initialize(total, logger)
      @total = total
      @logger = logger
      @last_percent = 0
      @start_time = Time.now
      @last_update_time = Time.now
      @update_interval = 0.5
    end

    def update(current)
      now = Time.now
      return if now - @last_update_time < @update_interval && current != @total

      @last_update_time = now
      percent = (current.to_f / @total * 100).round
      return unless percent > @last_percent || current == @total

      elapsed = now - @start_time
      progress_chars = (BAR_WIDTH * (current.to_f / @total)).round
      bar = "[#{"|" * progress_chars}#{" " * (BAR_WIDTH - progress_chars)}]"

      rate = if elapsed.positive?
               (current / elapsed).round(1)
             else
               0 # Avoid division by zero if elapsed time is zero
             end
      eta_string = current.positive? && percent < 100 && rate.positive? ? " ETA: #{format_time((@total - current) / rate)}" : ""

      print "\r\e[K#{bar} #{percent}% | #{current}/#{@total} files (#{rate} files/sec)#{eta_string}"
      print "\n" if current == @total
      if (percent % 10).zero? && percent != @last_percent || current == @total
        @logger.info "Processing: #{percent}% complete (#{current}/#{@total} files)#{eta_string}"
      end
      @last_percent = percent
    end

    private

    def format_time(seconds)
      return "< 1s" if seconds < 1

      case seconds
      when 0...60 then "#{seconds.round}s"
      when 60...3600 then "#{(seconds / 60).floor}m #{(seconds % 60).round}s"
      else "#{(seconds / 3600).floor}h #{((seconds % 3600) / 60).floor}m"
      end
    end
  end
end
