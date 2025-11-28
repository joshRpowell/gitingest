# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitingest::ExclusionFilter do
  describe "#excluded?" do
    let(:filter) { described_class.new }

    it "excludes dotfiles" do
      expect(filter.excluded?(".env")).to be true
    end

    it "excludes files in dot directories" do
      expect(filter.excluded?(".github/workflows/ci.yml")).to be true
    end

    it "excludes files matching default patterns" do
      expect(filter.excluded?("node_modules/package.json")).to be true
      expect(filter.excluded?("image.png")).to be true
      expect(filter.excluded?("vendor/cache/gems")).to be true
    end

    it "doesn't exclude regular code files" do
      expect(filter.excluded?("lib/gitingest.rb")).to be false
      expect(filter.excluded?("README.md")).to be false
    end

    context "with custom excludes" do
      it "excludes files matching simple glob patterns" do
        filter = described_class.new(["*.md"])
        expect(filter.excluded?("README.md")).to be true
        expect(filter.excluded?("docs/guide.md")).to be true
        expect(filter.excluded?("src/app.rb")).to be false
      end

      it "handles multiple glob patterns" do
        filter = described_class.new(["*.md", "*.yml"])
        expect(filter.excluded?("README.md")).to be true
        expect(filter.excluded?("config.yml")).to be true
        expect(filter.excluded?("src/app.rb")).to be false
      end

      it "handles directory-specific glob patterns" do
        filter = described_class.new(["docs/"])
        expect(filter.excluded?("docs/guide.md")).to be true
        expect(filter.excluded?("docs/api.json")).to be true
        expect(filter.excluded?("src/docs.rb")).to be false
        expect(filter.excluded?("README.md")).to be false
      end

      it "combines glob patterns with default excludes" do
        filter = described_class.new(["*.md"])

        # Should exclude both .git directory (default) and markdown files (custom)
        expect(filter.excluded?(".git/config")).to be true
        expect(filter.excluded?("README.md")).to be true

        # Should not exclude regular code files
        expect(filter.excluded?("src/app.rb")).to be false
      end
    end
  end
end
