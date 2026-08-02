class DocMaker

  attr_accessor :ansi

  def initialize
    self.ansi = true
  end

  def make_docs
    File.write('help/intro.txt', intro_doc)
    File.write('help/help.txt', help_doc)
    File.write('help/names.txt', names_doc)
    File.write('help/files.txt', files_doc)
    File.write('help/modules.txt', modules_doc)
    File.write('help/instance_methods.txt', instance_methods_doc)
    # File.write('help/singleton_methods.txt', singleton_methods_doc)
    # File.write('help/modes.txt', modes_doc)
    self.ansi = false
    File.write('README.txt',
               help_doc +
               names_doc +
               files_doc +
               modules_doc +
               instance_methods_doc
               )
  end
  def intro_doc
    <<EOT
#{bold_italic('Introduction')}

#{webri} is a console application that lets you type command-line commands
that open Ruby documentation pages in your web browser.

For example, you can type #{command('webri Array')}    
EOT
  end

  def help_doc
    `ruby exe/webri --help`
  end

  def names_doc
    <<EOT
#{bold_italic('Names')}

Argument #{variable('name')} is one of four types, as determined by its prefix:

|------------------|----------------|--------------------|
|       Type       |     Prefix     |      Example       |
|------------------|----------------|--------------------|
| Class/module     | Capital letter | #{tokenq('Array')}            |
| Singleton method | #{tokenq('::')}           | #{tokenq('::new')}            |
| Instance method  | #{tokenq('#')}            | #{tokenq('#inspect')}         |
| Ruby file        | #{tokenq('ruby:')}        | #{tokenq('ruby:syntax_rdoc')} |
|------------------|----------------|--------------------|

Note: On the command-line, your shell may require you to escape the instance method prefix:

    #{string('\\#size')} (instead of just #{string('#size')})


EOT
  end

  def files_doc
    <<EOT
#{bold_italic('Files')}

To get the web page for a Ruby file,
type a #{variable('name')} starting with #{tokenq('ruby:')}.

When the #{variable('name')} is:

- The exact name of a Ruby file (but not the beginning of other such names):
  #{webri} opens the page for that file.
  Examples: #{tokenq('ruby:README_md')}, #{tokenq('ruby:LEGAL')}, #{tokenq('ruby:NEWS_md')}, #{tokenq('ruby:syntax_rdoc')}.

- The partial name of exactly one file:
  #{webri} asks whether to open the page for that file.
  Examples: 
 
  - #{tokenq('ruby:maint')}              (for #{tokenq('ruby:maintainers_md')})
  - #{tokenq('ruby:syntax/assign')}      (for #{tokenq('ruby:syntax/assignment_rdoc')})
  - #{tokenq('ruby:language/pack')}      (for #{tokenq('ruby:language/packed_data_rdoc')})
  - #{tokenq('ruby:contributing/build')} (for #{tokenq('ruby:contributing/building_ruby_md')})
  - #{tokenq('ruby:optparse/arg')}       (for #{tokenq('ruby:optparse/argument_converters_rdoc')}).

- The partial name of multiple files:
  #{webri} displays those names and lets you choose.
  Examples: #{tokenq('ruby:syntax')}, #{tokenq('ruby:contrib')}, #{tokenq('ruby:lang')}, #{tokenq('ruby:jit')}.

- Not the partial name of any file:
  #{webri} asks whether show all file names.
  Examples: #{tokenq('ruby:xyzzy')}, #{tokenq('ruby:nosuch')}.

EOT
  end

  def modules_doc
    <<EOT
#{bold_italic('Classes and Modules')}

To get the web page for a class or module,
type a #{variable('name')} starting with a capital letter.

When the #{variable('name')} is:

- The exact name of a class/module (but not the beginning of other such names):
  #{webri} opens the page for that class/module.
  Examples: #{tokenq('Array')}, #{tokenq('Hash')}, #{tokenq('Struct')}, #{tokenq('Integer')}, #{tokenq('Symbol')}.

- The abbreviated name of exactly one class/module:
  #{webri} asks whether to open the page for that class/module.
  Examples:

  - #{tokenq('Cov')}          (for #{tokenq('Coverage')}).
  - #{tokenq('Eng')}          (for #{tokenq('English')}).
  - #{tokenq('Ker')}          (for #{tokenq('Kernel')}).
  - #{tokenq('Net::HTTP::D')} (for #{tokenq('Net::HTTP::Delete')}).}

- The abbreviated name of multiple classes/modules:
  #{webri} asks whether to open the page for that class/module;
  if Yes, #{webri} displays those names and lets you choose.
  Examples: #{tokenq('String')}, #{tokenq('Float')}, #{tokenq('Regexp')}, #{tokenq('Net::HTTP')}.

- Not the abbreviated name of any class/module:
  #{webri} asks whether show all class/module names.
  Examples: #{tokenq('Xyzzy')}, #{tokenq('Nosuch')}.

EOT
  end

  def instance_methods_doc
    <<EOT
#{bold_italic('Instance Methods')}

You can open the web page for an instance method (and scroll to that method).

#{bold('With the Class/Module Name')}

If you know the exact names of the class/module and the method,
type the two, separated by a hash character (#{tokenq('#')})
type the name of the class/module

#{bold('Without the Class/Module Name')}

If you're not sure of the class/module that has the method,

To get the web page for an instance method (and scroll to that method),
type a #{variable('name')} starting with #{tokenq('#')}.

When the #{variable('name')} is:

- The exact name of an instance method (but not the beginning of other such names):

  - If that method appears in only one class/module,
    #{webri} opens the page for that class-module and scrolls to the method.
    Examples: #{tokenq('#abbreviate')}, #{tokenq('#mountpoint?')}, #{tokenq('#xmlschema')}.

  - If the method appears in multiple classes/modules,
    #{webri} shows them and lets you choose; for your choice,
    #{webri} opens the page for that class-module and scrolls to the method.
    Examples: #{tokenq('#birthtime')}, #{tokenq('#frozen?')}, #{tokenq('#owner')}.
 
- The partial name of multiple instance methods:
  #{webri} asks whether to show those names;
  if Yes, shows them and lets you choose; for your choice,
  #{webri} opens the page for that class-module and scrolls to the method.
  Examples: #{tokenq('#alias')}, #{tokenq('#line')}, #{tokenq('#rm')}.

- Not the partial name of any instance method:
  #{webri} asks whether show all instance method names.
  Examples: #{tokenq('#xyzzy')}, #{tokenq('#nosuch')}.

EOT
  end

  def bold(s)
    ansi ? "\033[1m#{s}\033[0m" : s
  end

  def bold_italic(s)
    ansi ? "\033[1;3m#{s}\033[0m" : s
  end

  def variable(s)
    ansi ? ansi_color(s, :yellow) : s
  end

  def token(s)
    color = case s
            when /^[A-Z]/
              :bright_blue
            when /^::/
              :bright_yellow
            when /^#/
              :bright_green
            when /^ruby:/
              :bright_red
            else
              :bright_cyan
            end
    ansi_color("#{s}", color)
  end

  ANSI_COLOR = {
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37,
    bright_black: 90,
    bright_red: 91,
    bright_green: 92,
    bright_yellow: 93,
    bright_blue: 94,
    bright_magenta: 95,
    bright_cyan: 96,
    bright_white: 97,
  }

  def ansi_color(s, color)
    ansi ? "\e[#{ANSI_COLOR[color]}m#{s}\e[0m" : s
  end

  def tokenq(s)
    "'" + token("#{s}") + "'"
  end

  def webri
    ansi_color('webri', :cyan)
  end

  def string(s)
    self.ansi_color("'#{s}'", :green)
  end

end