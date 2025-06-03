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
- A Ruby 'topic': opens a free-standing web page.

## Usage

```
$ webri name options
```

The `webri` command takes a single argument `name`,
which may be the name of a class, module, or method,
or the first part of such a name.

### Examples

#### Class or Module

For a `name` beginning with a capital letter,
WebRI finds the names of classes and modules beginning
with that name.

For one match:

- For a full name,
  reports the found name and opens its web page:

    ```
    $ webri Array
    Found one class or module name starting with 'Array':
      Array
    Opening web page https://docs.ruby-lang.org/en/3.4/Array.html
    ```

- For a partial name,
  reports the found name and asks whether to open its page:

    ```
    $ webri Arr
    Found one class or module name starting with 'Arr':
      Array
    Open page Array.html? (y or n):  y
    Opening web page https://docs.ruby-lang.org/en/3.4/Array.html
    ```

For multiple matches,
reports the count of matches and asks whether to list them:

```
$ webri Ar
Found 2 class and module names starting with 'Ar'.
Show names?' (y or n):  y
       0:  ArgumentError
       1:  Array
Choose (0..1):  0
Opening web page https://docs.ruby-lang.org/en/3.4/ArgumentError.html
```

For no matches,
reports that finding and asks whether to list all names:

```
$ webri Foo
Found no class or module name starting with 'Foo'.
Show names of all 1364 classes and modules? (y or n):  n
```

#### Singleton Method

For a `name` beginning with `::`,
WebRI finds the names of singleton methods beginning
with that `name`.

For one match:

- For a full name:


    - If there is only one such method:

    - If there are multiple such methods:


- For a partial name:

    - If there is only one such matching method:

    - It there are multiple such matching methods:

For multiple matches:

- For a full name:


- For a partial name:


For no matches:


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
to the [code of conduct](https://github.com/[USERNAME]/webri/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms
of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Webri project's codebases,
issue trackers, chat rooms and mailing lists is expected
to follow the [code of conduct](https://github.com/[USERNAME]/webri/blob/master/CODE_OF_CONDUCT.md).
