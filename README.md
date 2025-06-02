# WebRI

WebRI is a command-line utility for displaying Ruby documentation.

It is in some ways similar to [Ruby's RI utility](https://ruby.github.io/rdoc/RI_md.html),
but differs mainly in that:

- RI displays text-only documentation the the user's command window.
- WebRI opens documentation web pages
  from [Ruby official on-line documentation](https://docs.ruby-lang.org/en)
  in the user's default web browser.

WebRI displays documentation for:

- A class or module: opens its web page.
- A method: opens the web page for its class/module _scrolled to the method's documentation_.
- A Ruby 'topics': opens a free-standing web page.

## Examples

### Class or Module

```
# Class or module by full name.
$ webri Array
Found one class or module name starting with 'Array':
  Array
Opening web page https://docs.ruby-lang.org/en/3.4/Array.html
```

```
# Class or module by partial name (one match).
$ webri Arr
Found one class or module name starting with 'Arr':
  Array
Open page Array.html? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/Array.html
```

```
# Class or module by partial name (multiple matches).
$ webri Ar
Found 2 class and module names starting with 'Ar'.
Show names?' (y or n):  y
       0:  ArgumentError
       1:  Array
Choose (0..1):  0
Opening web page https://docs.ruby-lang.org/en/3.4/ArgumentError.html
```

```
# Class or module that does not exist.
$ webri Foo
Found no class or module name starting with 'Foo'.
Show names of all 1364 classes and modules? (y or n):  n
```

### Singleton Methods

```
# Singleton method full name (one match).
$ webri ::write_binary
Found one singleton method name starting with '::write_binary'
  ::write_binary
Opening web page https://docs.ruby-lang.org/en/3.4/Gem.html#method-c-write_binary.
```

````
# Singleton method full name (multiple matches).
$ webri ::wrap
Found 3 singleton method names starting with '::wrap'.
Show names?' (y or n):  y
       0:  ::wrap (in Gem::Package::DigestIO)
       1:  ::wrap (in JSON::JSONError)
       2:  ::wrap (in Zlib::GzipFile)
Choose (0..2):  1
Opening web page https://docs.ruby-lang.org/en/3.4/JSON/JSONError.html#method-c-wrap.
````

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/webri. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/webri/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Webri project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/webri/blob/master/CODE_OF_CONDUCT.md).
