# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitingest::RepositoryFetcher do
  let(:mock_client) { instance_double(Octokit::Client) }
  let(:mock_repo) { "user/repo" }
  let(:mock_branch) { "main" }
  let(:fetcher) { described_class.new(mock_client, mock_repo, mock_branch) }

  describe "#fetch" do
    let(:tree) { double("tree", tree: []) }
    let(:mock_repository) { double("repository", default_branch: "main") }

    before do
      allow(mock_client).to receive(:repository).and_return(mock_repository)
      allow(mock_client).to receive(:branch)
      allow(mock_client).to receive(:tree).and_return(tree)
    end

    it "fetches and filters repository contents" do
      file1 = double("file1", type: "blob", path: "lib/gitingest.rb")
      file2 = double("file2", type: "blob", path: "node_modules/package.json")
      file3 = double("file3", type: "tree", path: "lib")

      allow(tree).to receive(:tree).and_return([file1, file2, file3])

      # Mock exclusion filter behavior
      exclusion_filter = instance_double(Gitingest::ExclusionFilter)
      allow(exclusion_filter).to receive(:excluded?).with("lib/gitingest.rb").and_return(false)
      allow(exclusion_filter).to receive(:excluded?).with("node_modules/package.json").and_return(true)

      fetcher = described_class.new(mock_client, mock_repo, mock_branch, exclusion_filter)

      files = fetcher.fetch
      expect(files).to eq([file1])
    end

    it "limits the number of files processed" do
      files = (1..1100).map { |i| double("file#{i}", type: "blob", path: "file#{i}.rb") }
      allow(tree).to receive(:tree).and_return(files)

      files = fetcher.fetch
      expect(files.size).to eq(Gitingest::RepositoryFetcher::MAX_FILES)
    end

    it "raises error for unauthorized access" do
      allow(mock_client).to receive(:repository).and_raise(Octokit::Unauthorized)
      expect { fetcher.fetch }.to raise_error(/Authentication error/)
    end

    it "raises error for repository not found" do
      allow(mock_client).to receive(:repository).and_raise(Octokit::NotFound)
      expect { fetcher.fetch }.to raise_error(/not found or is private/)
    end
  end
end
