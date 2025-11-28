# frozen_string_literal: true

require "spec_helper"
require "base64"
require "ostruct" # Add this line

RSpec.describe Gitingest::Generator do
  let(:repo_name) { "user/repo" }

  context "with directory exclusion pattern" do
    let(:options) { { repository: repo_name, exclude: ["spec/"], token: "fake_token" } }
    let(:generator) { described_class.new(**options) }
    let(:files_data) do
      [
        { path: "lib/gitingest.rb", type: "file", content: Base64.encode64("module Gitingest; end") },
        { path: "spec/gitingest_spec.rb", type: "file", content: Base64.encode64("require 'spec_helper'") },
        { path: "spec/support/helpers.rb", type: "file", content: Base64.encode64("module Helpers; end") },
        { path: "README.md", type: "file", content: Base64.encode64("# Gitingest") }
      ]
    end
    let(:tree_data) do
      files_data.map do |f|
        OpenStruct.new(path: f[:path], type: f[:type] == "file" ? "blob" : "tree", sha: "sha_#{f[:path]}")
      end
    end
    let(:mock_repo) { double("Repository", default_branch: "main") }
    let(:mock_branch) { double("Branch") }

    before do
      allow(generator.client).to receive(:repository).with(repo_name).and_return(mock_repo)
      allow(generator.client).to receive(:branch).with(repo_name, "main").and_return(mock_branch)
      allow(generator.client).to receive(:tree).with(repo_name, "main",
                                                     recursive: true).and_return(double(tree: tree_data))

      files_data.each do |file_hash|
        next unless file_hash[:type] == "file"

        blob_struct = OpenStruct.new(content: file_hash[:content], encoding: "base64")
        allow(generator.client).to receive(:blob)
          .with(repo_name, "sha_#{file_hash[:path]}")
          .and_return(blob_struct)
      end
    end

    it "excludes all files within the specified directory" do
      prompt = generator.generate_prompt
      expect(prompt).to include("File: lib/gitingest.rb")
      expect(prompt).to include("File: README.md")
      expect(prompt).not_to include("File: spec/gitingest_spec.rb")
      expect(prompt).not_to include("File: spec/support/helpers.rb")
    end
  end
end
