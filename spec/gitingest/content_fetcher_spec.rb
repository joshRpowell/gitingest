# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitingest::ContentFetcher do
  let(:mock_client) { instance_double(Octokit::Client) }
  let(:mock_repo) { "user/repo" }
  let(:logger) { Logger.new(nil) }
  let(:files) { [] }
  let(:fetcher) { described_class.new(mock_client, mock_repo, files, logger) }
  let(:output) { StringIO.new }

  describe "#fetch" do
    let(:file_double) { double("file", path: "lib/file.rb", sha: "sha123") }
    let(:blob) { double("blob", content: Base64.encode64("file content"), encoding: "base64") }

    before do
      fetcher.instance_variable_set(:@files, [file_double])
      allow(mock_client).to receive(:blob).with(mock_repo, "sha123").and_return(blob)
    end

    it "fetches and decodes file content" do
      fetcher.fetch(output)
      expect(output.string).to include("file content")
      expect(output.string).to include("File: lib/file.rb")
    end

    it "retries when rate limited" do
      call_count = 0
      allow(fetcher).to receive(:sleep)

      allow(mock_client).to receive(:blob) do
        call_count += 1
        call_count < 2 ? raise(Octokit::TooManyRequests) : blob
      end

      fetcher.fetch(output)
      expect(output.string).to include("file content")
      expect(call_count).to eq(2)
    end

    it "handles unexpected errors gracefully" do
      allow(mock_client).to receive(:blob).and_raise(StandardError, "Test error")

      expect(logger).to receive(:error).with(/Unexpected error processing/)
      fetcher.fetch(output)
    end
  end

  describe "#prioritize_files" do
    it "prioritizes documentation files first" do
      readme = double("readme", path: "README.md")
      code = double("code", path: "lib/file.rb")
      other = double("other", path: "unknown.xyz")

      files = [code, other, readme]
      sorted = fetcher.send(:prioritize_files, files)

      expect(sorted.first).to eq(readme)
      expect(sorted.last).to eq(other)
    end
  end
end
