# frozen_string_literal: true

module Gitingest
  class ExclusionFilter
    # Default exclusion patterns for common files and directories
    DEFAULT_EXCLUDES = [
      # Version control
      '\.git/', '\.github/', '\.gitignore', '\.gitattributes', '\.gitmodules', '\.svn', '\.hg',

      # System files
      '\.DS_Store', 'Thumbs\.db', 'desktop\.ini',

      # Log files
      '.*\.log$', '.*\.bak$', '.*\.swp$', '.*\.tmp$', '.*\.temp$',

      # Images and media
      '.*\.png$', '.*\.jpg$', '.*\.jpeg$', '.*\.gif$', '.*\.svg$', '.*\.ico$',
      '.*\.pdf$', '.*\.mov$', '.*\.mp4$', '.*\.mp3$', '.*\.wav$',

      # Archives
      '.*\.zip$', '.*\.tar\.gz$',

      # Dependency directories
      "node_modules/", "vendor/", "bower_components/", "\.npm/", "\.yarn/", "\.pnpm-store/",
      "\.bundle/", "vendor/bundle", "packages/", "site-packages/",

      # Virtual environments
      "venv/", "\.venv/", "env/", "\.env", "virtualenv/",

      # IDE and editor files
      "\.idea/", "\.vscode/", "\.vs/", "\.settings/", ".*\.sublime-.*",
      "\.project", "\.classpath", "xcuserdata/", ".*\.xcodeproj/", ".*\.xcworkspace/",

      # Lock files
      "package-lock\.json", "yarn\.lock", "poetry\.lock", "Pipfile\.lock",
      "Gemfile\.lock", "Cargo\.lock", "bun\.lock", "bun\.lockb",

      # Build directories and artifacts
      "build/", "dist/", "target/", "out/", "\.gradle/", "\.settings/",
      ".*\.egg-info", ".*\.egg", ".*\.whl", ".*\.so", "bin/", "obj/", "pkg/",

      # Cache directories
      "\.cache/", "\.sass-cache/", "\.eslintcache/", "\.pytest_cache/",
      "\.coverage", "\.tox/", "\.nox/", "\.mypy_cache/", "\.ruff_cache/",
      "\.hypothesis/", "\.terraform/", "\.docusaurus/", "\.next/", "\.nuxt/",

      # Compiled code
      ".*\.pyc$", ".*\.pyo$", ".*\.pyd$", "__pycache__/", ".*\.class$",
      ".*\.jar$", ".*\.war$", ".*\.ear$", ".*\.nar$",
      ".*\.o$", ".*\.obj$", ".*\.dll$", ".*\.dylib$", ".*\.exe$",
      ".*\.lib$", ".*\.out$", ".*\.a$", ".*\.pdb$", ".*\.nupkg$",

      # Language-specific files
      ".*\.min\.js$", ".*\.min\.css$", ".*\.map$", ".*\.tfstate.*",
      ".*\.gem$", ".*\.ruby-version", ".*\.ruby-gemset", ".*\.rvmrc",
      ".*\.rs\.bk$", ".*\.gradle", ".*\.suo", ".*\.user", ".*\.userosscache",
      ".*\.sln\.docstates", "gradle-app\.setting",
      ".*\.pbxuser", ".*\.mode1v3", ".*\.mode2v3", ".*\.perspectivev3", ".*\.xcuserstate",
      "\.swiftpm/", "\.build/"
    ].freeze

    # Pattern for dot files/directories
    DOT_FILE_PATTERN = %r{(?-mix:(^\.|/\.))}

    def initialize(custom_excludes = [])
      @custom_excludes = custom_excludes || []
      compile_excluded_patterns
    end

    def excluded?(path)
      return true if path.match?(DOT_FILE_PATTERN)

      # Check for directory exclusion patterns (ending with '/')
      matched_dir_pattern = @directory_patterns.find { |dir_pattern| path.start_with?(dir_pattern) }
      return true if matched_dir_pattern

      # Check default regex patterns
      matched_default_pattern = @default_patterns.find { |pattern| path.match?(pattern) }
      return true if matched_default_pattern

      # Check custom glob patterns using File.fnmatch
      matched_glob_pattern = @custom_glob_patterns.find do |glob_pattern|
        File.fnmatch(glob_pattern, path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
      end
      return true if matched_glob_pattern

      false
    end

    private

    def compile_excluded_patterns
      @default_patterns = DEFAULT_EXCLUDES.map { |pattern| Regexp.new(pattern) }
      @custom_glob_patterns = [] # For File.fnmatch
      @directory_patterns = []

      @custom_excludes.each do |pattern_str|
        if pattern_str.end_with?("/")
          @directory_patterns << pattern_str
        else
          # All other custom excludes are treated as glob patterns.
          # If the pattern does not contain a slash, prepend "**/"
          # to make it match at any depth (e.g., "*.md" becomes "**/*.md").
          @custom_glob_patterns << if pattern_str.include?("/")
                                     pattern_str
                                   else
                                     "**/#{pattern_str}"
                                   end
        end
      end
    end
  end
end
