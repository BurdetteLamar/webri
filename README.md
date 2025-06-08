# WebRI

WebRI has a command-line utility, `webri`, for displaying Ruby online documentation.

It is in some ways similar to [Ruby's RI utility](https://ruby.github.io/rdoc/RI_md.html),
but differs mainly in that:

- RI displays text-only documentation the the user's command window.
- WebRI opens documentation web pages
  from [Ruby official on-line documentation](https://docs.ruby-lang.org/en)
  in the user's default web browser.

WebRI displays documentation for:

- A class or module: opens its web page.
- A method: opens the web page for its class/module _scrolled to the method's documentation_.
- A Ruby 'topic': opens a free-standing web page.

## Usage

```
$ webri name options
```

The `webri` command takes a single argument `name`,
which may be the name of a class, module, or method,
or the first part of such a name.

### Class or Module

For a `name` beginning with a capital letter,
WebRI finds the names of classes and modules beginning with that name.

When exactly one such class/module name is found:

- If `name` is the exact name of the found name, opens the page for that name:

```
webri Array
Found one class/module name starting with 'Array'
  Array (Array.html)
Opening web page https://docs.ruby-lang.org/en/3.4/Array.html.
```

- If `name` is the start of the found name, offers to open the page for that name:

```
$ webri Arr
Found one class/module name starting with 'Arr'
  Array (Array.html)
Open page Array.html? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/Array.html.
```

When multiple such class/module names are found offer to list the found names:

```bash
$ webri Ar
Found 2 class/module names starting with 'Ar'.
Show 2 class/module names?' (y or n):  y
       0:  ArgumentError (ArgumentError.html)
       1:  Array (Array.html)
Type a number to choose, 'x' to exit, or 'r' to open the README:  0
Opening web page https://docs.ruby-lang.org/en/3.4/ArgumentError.html.
```

```bash
$ webri Ar
Found 2 class/module names starting with 'Ar'.
Show 2 class/module names?' (y or n):  y
       0:  ArgumentError (ArgumentError.html)
       1:  Array (Array.html)
Type a number to choose, 'x' to exit, or 'r' to open the README:  x
```

```bash
$ webri Ar
Found 2 class/module names starting with 'Ar'.
Show 2 class/module names?' (y or n):  y
       0:  ArgumentError (ArgumentError.html)
       1:  Array (Array.html)
Type a number to choose, 'x' to exit, or 'r' to open the README:  r
"https://github.com/BurdetteLamar/webri/blob/main/README.md"
Opening web page https://github.com/BurdetteLamar/webri/blob/main/README.md.
```

When no such class/module name is found, offers to list all class/module names:

```
$ webri Nosuch
Found no class/module name starting with 'Nosuch'.
Show 1364 class/module names? (y or n):  n
```

### Singleton Method

For a `name` beginning with `::`,
WebRI finds the names of singleton methods beginning
with that name.

When exactly one such singleton method name is found:

- If `name` is the exact name of the found name, opens the page for that name:

```
$ webri ::zcat
Found one singleton method name starting with '::zcat'
  ::zcat
Opening web page https://docs.ruby-lang.org/en/3.4/Zlib/GzipReader.html at method ::zcat.
```

- If `name` is the start of the found name, offers to open the page for that name:

```
$ webri ::zca
Found one singleton method name starting with '::zca'
  ::zcat
Open page Zlib/GzipReader.html at method ::zcat? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/Zlib/GzipReader.html at method ::zcat.
```

When multiple such singleton method names are found offer to list the found names:

```bash
$ webri ::z
Found 5 singleton method names starting with '::z'.
Show 5 names?' (y or n):  y
       0:  ::zcat (in Zlib::GzipReader)
       1:  ::zero? (in File)
       2:  ::zip? (in RDoc::Parser)
       3:  ::zlib_version (in Zlib)
       4:  ::zone_offset (in Time)
Type a number to choose, 'x' to exit, or 'r' to open the README:  2
Opening web page https://docs.ruby-lang.org/en/3.4/RDoc/Parser.html at method ::zip?.
```

```bash
$ webri ::z
Found 5 singleton method names starting with '::z'.
Show 5 names?' (y or n):  y
       0:  ::zcat (in Zlib::GzipReader)
       1:  ::zero? (in File)
       2:  ::zip? (in RDoc::Parser)
       3:  ::zlib_version (in Zlib)
       4:  ::zone_offset (in Time)
Type a number to choose, 'x' to exit, or 'r' to open the README:  x
```

```bash
$ webri ::z
Found 5 singleton method names starting with '::z'.
Show 5 names?' (y or n):  y
       0:  ::zcat (in Zlib::GzipReader)
       1:  ::zero? (in File)
       2:  ::zip? (in RDoc::Parser)
       3:  ::zlib_version (in Zlib)
       4:  ::zone_offset (in Time)
Type a number to choose, 'x' to exit, or 'r' to open the README:  r
"https://github.com/BurdetteLamar/webri/blob/main/README.md"
Opening web page https://github.com/BurdetteLamar/webri/blob/main/README.md.
```

When no such singleton method name is found, offers to list all singleton method names:

```
$ webri ::nosuch
Found no singleton method name starting with '::nosuch'.
Show names of all 2288 singleton methods? (y or n):  n
```

### Instance Method

For a `name` beginning with `#`,
WebRI finds the names of instance methods beginning
with that name.

Note that for certain command windows,
the leading `'#'` character may be seen as the beginning of a comment,
and must be escaped:

```bash
$ webri #nosuch
No name given.
```

When exactly one such instance method name is found:

- If `name` is the exact name of the found name, opens the page for that name:

```
$ webri \#yield_self
Found one instance method name starting with '#yield_self'
  #yield_self
Opening web page https://docs.ruby-lang.org/en/3.4/Kernel.html at method #yield_self.
```

- If `name` is the start of the found name, offers to open the page for that name:

```
Found one instance method name starting with '#yield_sel'
  #yield_self
Open page Kernel.html at method #yield_self? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/Kernel.html at method #yield_self.
```

When multiple such instance method names are found offer to list the found names:

```bash
$ webri \#yield
Found 4 instance method names starting with '#yield'.
Show 4 names?' (y or n):  y
       0:  #yield (in Proc)
       1:  #yield_node (in Prism::DSL)
       2:  #yield_self (in Kernel)
       3:  #yields_directive (in RDoc::MarkupReference)
Type a number to choose, 'x' to exit, or 'r' to open the README:  0
Opening web page https://docs.ruby-lang.org/en/3.4/Proc.html at method #yield.
```

```bash
$ webri \#yield
Found 4 instance method names starting with '#yield'.
Show 4 names?' (y or n):  y
       0:  #yield (in Proc)
       1:  #yield_node (in Prism::DSL)
       2:  #yield_self (in Kernel)
       3:  #yields_directive (in RDoc::MarkupReference)
Type a number to choose, 'x' to exit, or 'r' to open the README:  x
```

```bash
$ webri \#yield
Found 4 instance method names starting with '#yield'.
Show 4 names?' (y or n):  y
       0:  #yield (in Proc)
       1:  #yield_node (in Prism::DSL)
       2:  #yield_self (in Kernel)
       3:  #yields_directive (in RDoc::MarkupReference)
Type a number to choose, 'x' to exit, or 'r' to open the README:  r
"https://github.com/BurdetteLamar/webri/blob/main/README.md"
Opening web page https://github.com/BurdetteLamar/webri/blob/main/README.md.
```

When no such instance method name is found, offers to list all singleton method names:

```
$ webri \#nosuch
Found no instance method name starting with '#nosuch'.
Show names of all 10370 instance methods? (y or n):  n
```

### Ruby 'File'

For a `name` beginning with `ruby:`,
WebRI finds the names of ruby files beginning
with that name.

When exactly one such file name is found:

- If `name` is the exact name of the found name, opens the page for that name:

```
Found one file name starting with 'operators'
  operators (syntax/operators_rdoc.html)
Opening web page https://docs.ruby-lang.org/en/3.4/syntax/operators_rdoc.html.
```

- If `name` is the start of the found name, offers to open the page for that name:

```
$ webri ruby:opera
Found one file name starting with 'opera'
  operators (syntax/operators_rdoc.html)
Open page syntax/operators_rdoc.html? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/syntax/operators_rdoc.html.
```

When multiple such file names are found offer to list the found names:

```bash
$ webri ruby:o
Found 4 file names starting with 'o'.
Show 4 names?' (y or n):  y
       0:  operators (syntax/operators_rdoc.html)
       1:  option_dump (ruby/option_dump_md.html)
       2:  option_params (optparse/option_params_rdoc.html)
       3:  options (ruby/options_md.html)
Type a number to choose, 'x' to exit, or 'r' to open the README:  3
Opening web page https://docs.ruby-lang.org/en/3.4/ruby/options_md.html.
```

```bash
$ webri ruby:o
Found 4 file names starting with 'o'.
Show 4 names?' (y or n):  y
       0:  operators (syntax/operators_rdoc.html)
       1:  option_dump (ruby/option_dump_md.html)
       2:  option_params (optparse/option_params_rdoc.html)
       3:  options (ruby/options_md.html)
Type a number to choose, 'x' to exit, or 'r' to open the README:  x
```

```bash
$ webri ruby:o
Found 4 file names starting with 'o'.
Show 4 names?' (y or n):  y
       0:  operators (syntax/operators_rdoc.html)
       1:  option_dump (ruby/option_dump_md.html)
       2:  option_params (optparse/option_params_rdoc.html)
       3:  options (ruby/options_md.html)
Type a number to choose, 'x' to exit, or 'r' to open the README:  r
"https://github.com/BurdetteLamar/webri/blob/main/README.md"
Opening web page https://github.com/BurdetteLamar/webri/blob/main/README.md.
```

When no such file name is found, offers to list all singleton method names:

```
$ webri ruby:nosuch
Found no file name starting with 'nosuch'.
Show names of all 83 files? (y or n):  n
```

## Installation

Install the gem and add to the application's Gemfile by executing:

```
$ bundle add webri
```

If bundler is not being used to manage dependencies, install the gem by executing:

```
$ gem install webri
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake test` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`,
and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and the created tag, and push the `.gem` file
to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/BurdetteLamar/webri.
This project is intended to be a safe, welcoming space for collaboration,
and contributors are expected to adhere
to the [code of conduct](https://github.com/BurdetteLamar/webri/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms
of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Webri project's codebases,
issue trackers, chat rooms and mailing lists is expected
to follow the [code of conduct](https://github.com/BurdetteLamar/webri/blob/master/CODE_OF_CONDUCT.md).
