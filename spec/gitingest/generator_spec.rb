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

  describe "#valid_api_endpoint? (SSRF protection)" do
    let(:options) { { repository: repo_name, token: "fake_token" } }
    let(:generator) { described_class.new(**options) }

    # Valid endpoints that should be allowed
    describe "allows valid HTTPS endpoints" do
      it "accepts valid GitHub Enterprise endpoints" do
        expect(generator.send(:valid_api_endpoint?, "https://github.example.com/api/v3/")).to be true
      end

      it "accepts valid public domain endpoints" do
        expect(generator.send(:valid_api_endpoint?, "https://api.github.com/")).to be true
      end

      it "accepts endpoints with ports" do
        expect(generator.send(:valid_api_endpoint?, "https://github.example.com:8443/api/v3/")).to be true
      end
    end

    # Invalid endpoints that should be blocked
    describe "blocks invalid or insecure endpoints" do
      it "rejects HTTP endpoints" do
        expect(generator.send(:valid_api_endpoint?, "http://github.example.com/api/v3/")).to be false
      end

      it "rejects malformed URLs" do
        expect(generator.send(:valid_api_endpoint?, "not-a-url")).to be false
      end

      it "rejects empty URLs" do
        expect(generator.send(:valid_api_endpoint?, "")).to be false
      end

      it "rejects URLs without host" do
        expect(generator.send(:valid_api_endpoint?, "https:///path")).to be false
      end
    end

    # SSRF protection - blocked hostnames
    describe "blocks localhost (SSRF protection)" do
      it "rejects localhost" do
        expect(generator.send(:valid_api_endpoint?, "https://localhost/api/v3/")).to be false
      end

      it "rejects localhost with port" do
        expect(generator.send(:valid_api_endpoint?, "https://localhost:8443/api/v3/")).to be false
      end

      it "rejects LOCALHOST (case insensitive)" do
        expect(generator.send(:valid_api_endpoint?, "https://LOCALHOST/api/v3/")).to be false
      end
    end

    # SSRF protection - loopback IPs (127.0.0.0/8)
    describe "blocks loopback IPs (SSRF protection)" do
      it "rejects 127.0.0.1" do
        expect(generator.send(:valid_api_endpoint?, "https://127.0.0.1/api/v3/")).to be false
      end

      it "rejects 127.0.0.1 with port" do
        expect(generator.send(:valid_api_endpoint?, "https://127.0.0.1:8443/api/v3/")).to be false
      end

      it "rejects other 127.x.x.x addresses" do
        expect(generator.send(:valid_api_endpoint?, "https://127.1.2.3/api/v3/")).to be false
      end
    end

    # SSRF protection - Private Class A (10.0.0.0/8)
    describe "blocks private Class A IPs (SSRF protection)" do
      it "rejects 10.0.0.1" do
        expect(generator.send(:valid_api_endpoint?, "https://10.0.0.1/api/v3/")).to be false
      end

      it "rejects 10.255.255.255" do
        expect(generator.send(:valid_api_endpoint?, "https://10.255.255.255/api/v3/")).to be false
      end
    end

    # SSRF protection - Private Class B (172.16.0.0/12)
    describe "blocks private Class B IPs (SSRF protection)" do
      it "rejects 172.16.0.1" do
        expect(generator.send(:valid_api_endpoint?, "https://172.16.0.1/api/v3/")).to be false
      end

      it "rejects 172.31.255.255" do
        expect(generator.send(:valid_api_endpoint?, "https://172.31.255.255/api/v3/")).to be false
      end

      it "allows 172.15.0.1 (outside private range)" do
        expect(generator.send(:valid_api_endpoint?, "https://172.15.0.1/api/v3/")).to be true
      end

      it "allows 172.32.0.1 (outside private range)" do
        expect(generator.send(:valid_api_endpoint?, "https://172.32.0.1/api/v3/")).to be true
      end
    end

    # SSRF protection - Private Class C (192.168.0.0/16)
    describe "blocks private Class C IPs (SSRF protection)" do
      it "rejects 192.168.0.1" do
        expect(generator.send(:valid_api_endpoint?, "https://192.168.0.1/api/v3/")).to be false
      end

      it "rejects 192.168.255.255" do
        expect(generator.send(:valid_api_endpoint?, "https://192.168.255.255/api/v3/")).to be false
      end
    end

    # SSRF protection - Link-local/Cloud metadata (169.254.0.0/16)
    describe "blocks link-local/cloud metadata IPs (SSRF protection)" do
      it "rejects 169.254.0.1" do
        expect(generator.send(:valid_api_endpoint?, "https://169.254.0.1/api/v3/")).to be false
      end

      it "rejects 169.254.169.254 (AWS metadata endpoint)" do
        expect(generator.send(:valid_api_endpoint?, "https://169.254.169.254/api/v3/")).to be false
      end
    end

    # Verify initialization fails with SSRF-blocked endpoints
    describe "initialization with blocked endpoints" do
      it "raises ArgumentError for localhost endpoint" do
        expect do
          described_class.new(repository: repo_name, token: "fake_token", api_endpoint: "https://localhost/api/v3/")
        end.to raise_error(ArgumentError, /Invalid API endpoint URL/)
      end

      it "raises ArgumentError for private IP endpoint" do
        expect do
          described_class.new(repository: repo_name, token: "fake_token", api_endpoint: "https://192.168.1.1/api/v3/")
        end.to raise_error(ArgumentError, /Invalid API endpoint URL/)
      end

      it "raises ArgumentError for cloud metadata endpoint" do
        expect do
          described_class.new(repository: repo_name, token: "fake_token",
                              api_endpoint: "https://169.254.169.254/latest/meta-data/")
        end.to raise_error(ArgumentError, /Invalid API endpoint URL/)
      end
    end
  end
end
