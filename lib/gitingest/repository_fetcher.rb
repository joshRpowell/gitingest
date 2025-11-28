# frozen_string_literal: true

require "octokit"

module Gitingest
  class RepositoryFetcher
    MAX_FILES = 1000

    def initialize(client, repository, branch = :default, exclusion_filter = nil)
      @client = client
      @repository = repository
      @branch = branch
      @exclusion_filter = exclusion_filter
    end

    def fetch
      validate_repository_access
      repo_tree = @client.tree(@repository, @branch, recursive: true)

      files = repo_tree.tree.select do |item|
        item.type == "blob" && !@exclusion_filter&.excluded?(item.path)
      end

      if files.size > MAX_FILES
        # We might want to warn here, but for now we just truncate
        files = files.first(MAX_FILES)
      end

      files
    rescue Octokit::Unauthorized
      raise "Authentication error: Invalid or expired GitHub token."
    rescue Octokit::NotFound
      raise "Repository not found: '#{@repository}' or branch '#{@branch}' doesn't exist or is private."
    rescue Octokit::Error => e
      raise "Error accessing repository: #{e.message}"
    end

    private

    def validate_repository_access
      repo = @client.repository(@repository)
      @branch = repo.default_branch if @branch == :default

      begin
        @client.branch(@repository, @branch)
      rescue Octokit::NotFound
        raise "Branch '#{@branch}' not found in repository '#{@repository}'"
      end
    rescue Octokit::Unauthorized
      raise "Authentication error: Invalid or expired GitHub token"
    rescue Octokit::NotFound
      raise "Repository '#{@repository}' not found or is private. Check the repository name or provide a valid token."
    end
  end
end
