# frozen_string_literal: true

require_relative "gitingest/version"
require_relative "gitingest/exclusion_filter"
require_relative "gitingest/repository_fetcher"
require_relative "gitingest/progress_indicator"
require_relative "gitingest/content_fetcher"
require_relative "gitingest/generator"

module Gitingest
  class Error < StandardError; end
  # Your code goes here...
end
