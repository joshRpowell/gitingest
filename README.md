[![Gem Version](https://badge.fury.io/rb/gitingest.svg)](https://badge.fury.io/rb/gitingest)

# Gitingest

Turn any GitHub repo into an LLM-ready prompt.

## Install

```bash
gem install gitingest
```

## Usage

```bash
# Basic
gitingest -r user/repo

# With token (for private repos)
gitingest -r user/repo -t YOUR_TOKEN

# Custom output
gitingest -r user/repo -o prompt.txt

# Show repo structure
gitingest -r user/repo -s
```

### As a Library

```ruby
require "gitingest"

generator = Gitingest::Generator.new(
  repository: "user/repo",
  token: "YOUR_TOKEN"  # optional
)

# Write to file
generator.run

# Or get content as string
content = generator.generate_prompt
```

## Options

| Flag | Description |
|------|-------------|
| `-r, --repository` | GitHub repo (user/repo) |
| `-t, --token` | GitHub token |
| `-o, --output` | Output file |
| `-b, --branch` | Branch name |
| `-e, --exclude` | Patterns to exclude |
| `-s, --show-structure` | Show directory tree |
| `-T, --threads` | Thread count |
| `-q, --quiet` | Quiet mode |
| `-v, --verbose` | Verbose mode |

## Limits

- Max 1000 files per repo
- 60 req/hour without token, 5000 with token
- Private repos require a token

## License

MIT

## Credits

Inspired by [cyclotruc/gitingest](https://github.com/cyclotruc/gitingest).
