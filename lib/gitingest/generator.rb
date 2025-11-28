# frozen_string_literal: true

require "octokit"
require "logger"

module Gitingest
  class Generator
    attr_reader :options, :client, :repo_files, :logger

    def initialize(options = {})
      @options = options
      @repo_files = []
      setup_logger
      validate_options
      configure_client
      @exclusion_filter = ExclusionFilter.new(@options[:exclude])
    end

    def run
      fetch_repository_contents
      if @options[:show_structure]
        puts generate_directory_structure
        return
      end
      generate_file
    end

    def generate_file
      fetch_repository_contents if @repo_files.empty?
      @logger.info "Generating file for #{@options[:repository]}"
      File.open(@options[:output_file], "w") do |file|
        process_content_to_output(file)
      end
      @logger.info "Prompt generated and saved to #{@options[:output_file]}"
      @options[:output_file]
    end

    def generate_prompt
      @logger.info "Generating in-memory prompt for #{@options[:repository]}"
      fetch_repository_contents if @repo_files.empty?
      content = StringIO.new
      process_content_to_output(content)
      result = content.string
      @logger.info "Generated #{result.size} bytes of content in memory"
      result
    end

    def generate_directory_structure
      fetch_repository_contents if @repo_files.empty?
      @logger.info "Generating directory structure for #{@options[:repository]}"
      repo_name = @options[:repository].split("/").last
      structure = DirectoryStructureBuilder.new(repo_name, @repo_files).build
      @logger.info "\n"
      structure
    end

    # Exposed for testing
    def excluded_patterns
      # This is a bit of a hack to maintain backward compatibility with tests
      # that check for excluded_patterns. In the new design, this is handled
      # by ExclusionFilter.
      @exclusion_filter.instance_variable_get(:@default_patterns) +
        @exclusion_filter.instance_variable_get(:@custom_glob_patterns).map { |p| Regexp.new(p.gsub("*", ".*")) }
    end

    private

    def setup_logger
      @logger = @options[:logger] || Logger.new($stdout)
      @logger.level = if @options[:quiet]
                        Logger::ERROR
                      elsif @options[:verbose]
                        Logger::DEBUG
                      else
                        Logger::INFO
                      end
      @logger.formatter = proc { |severity, _, _, msg| "#{severity == "INFO" ? "" : "[#{severity}] "}#{msg}\n" }
    end

    def validate_options
      raise ArgumentError, "Repository is required" unless @options[:repository]

      @options[:output_file] ||= "#{@options[:repository].split("/").last}_prompt.txt"
      @options[:branch] ||= :default
      @options[:exclude] ||= []
      @options[:threads] ||= ContentFetcher::DEFAULT_THREAD_COUNT
      @options[:thread_timeout] ||= ContentFetcher::DEFAULT_THREAD_TIMEOUT
      @options[:show_structure] ||= false
    end

    def configure_client
      @client = @options[:token] ? Octokit::Client.new(access_token: @options[:token]) : Octokit::Client.new
      if @options[:token]
        @logger.info "Using provided GitHub token for authentication"
      else
        @logger.warn "Warning: No token provided. API rate limits will be restricted and private repositories will be inaccessible."
        @logger.warn "For better results, provide a GitHub token with the --token option."
      end
    end

    def fetch_repository_contents
      @logger.info "Fetching repository: #{@options[:repository]} (branch: #{@options[:branch]})"
      fetcher = RepositoryFetcher.new(@client, @options[:repository], @options[:branch], @exclusion_filter)
      @repo_files = fetcher.fetch
      @logger.info "Found #{@repo_files.size} files after exclusion filters"
    end

    def process_content_to_output(output)
      fetcher = ContentFetcher.new(@client, @options[:repository], @repo_files, @logger, @options)
      fetcher.fetch(output)
    end
  end

  class DirectoryStructureBuilder
    def initialize(root_name, files)
      @root_name = root_name
      @files = files.map(&:path)
    end

    def build
      tree = { @root_name => {} }
      @files.sort.each do |path|
        parts = path.split("/")
        current = tree[@root_name]
        parts.each do |part|
          if part == parts.last then current[part] = nil
          else
            current[part] ||= {}
            current = current[part]
          end
        end
      end
      output = ["Directory structure:"]
      render_tree(tree, "", output)
      output.join("\n")
    end

    private

    def render_tree(tree, prefix, output)
      return if tree.nil?

      tree.keys.each_with_index do |key, index|
        is_last = index == tree.keys.size - 1
        current_prefix = if prefix.empty?
                           "    "
                         else
                           prefix + (is_last ? "    " : "│   ")
                         end
        connector = if prefix.empty?
                      "└── "
                    else
                      (is_last ? "└── " : "├── ")
                    end
        item = tree[key].is_a?(Hash) ? "#{key}/" : key
        output << "#{prefix}#{connector}#{item}"
        render_tree(tree[key], current_prefix, output) if tree[key].is_a?(Hash)
      end
    end
  end
end
