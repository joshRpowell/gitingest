# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitingest do
  it "has a version number" do
    expect(Gitingest::VERSION).not_to be nil
  end

  describe Gitingest::Generator do
    let(:mock_repo) { "user/repo" }
    let(:mock_branch) { "main" }

    it "requires a repository option" do
      expect { Gitingest::Generator.new({}) }.to raise_error(ArgumentError)
    end

    it "sets default values" do
      generator = Gitingest::Generator.new(repository: mock_repo)
      expect(generator.options[:branch]).to eq(:default)
      expect(generator.options[:output_file]).to eq("repo_prompt.txt")
      expect(generator.options[:threads]).to eq(Gitingest::ContentFetcher::DEFAULT_THREAD_COUNT)
      expect(generator.options[:thread_timeout]).to eq(Gitingest::ContentFetcher::DEFAULT_THREAD_TIMEOUT)
    end

    describe "integration" do
      let(:generator) { Gitingest::Generator.new(repository: mock_repo) }
      let(:fetcher) { instance_double(Gitingest::RepositoryFetcher) }
      let(:content_fetcher) { instance_double(Gitingest::ContentFetcher) }
      let(:files) { [double("file", path: "test.rb")] }

      before do
        allow(Gitingest::RepositoryFetcher).to receive(:new).and_return(fetcher)
        allow(Gitingest::ContentFetcher).to receive(:new).and_return(content_fetcher)
        allow(fetcher).to receive(:fetch).and_return(files)
        allow(content_fetcher).to receive(:fetch)
      end

      it "coordinates fetching and generation" do
        expect(fetcher).to receive(:fetch)
        expect(content_fetcher).to receive(:fetch)

        generator.run
      end

      it "generates directory structure when requested" do
        generator = Gitingest::Generator.new(repository: mock_repo, show_structure: true)

        expect(fetcher).to receive(:fetch)
        expect(generator).to receive(:puts).with(/Directory structure:/)
        expect(content_fetcher).not_to receive(:fetch)

        generator.run
      end
    end
  end
end
