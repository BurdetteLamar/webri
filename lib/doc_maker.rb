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

Use console application #{webri} to open a Ruby documentation page in your web browser.

Example commands:

  #{command('webri Array')}           Open page for class #{token('Array')}.
  #{command('webri Enumerable')}      Open page for module #{token('Enumerable')}.
  #{command('webri Array::new')}      Open page for class #{token('Array')}; scroll to method #{token('::new')}.
  #{command('webri Array#size')}      Open page for class #{token('Array')}; scroll to method #{token('#size')}.
  #{command('webri ruby:README_md')}  Open page for file #{token('ruby::README_md')}.

If you're not sure of exact name, #{webri} can still help:

- Class/module:

  #{command('webri Ar')}              Show names of all classes/modules whose names begin with #{string('Ar')}.
  #{command('webri Enum')}            Show names of all classes/modules whose names begin with #{string('Enum')}.

- Instance method:

  #{command('webri Array#')}          Show names of all instance methods in class #{token('Array')}.
  #{command('webri Array#co')}        Show names of instance methods in class #{token('Array')} whose names begin with #{string('co')}.
  #{command('webri Enumerable#')}     Show names of all instance methods in module #{token('Enumerable')}.
  #{command('webri Enumerable#ch')}   Show names of instance methods in module #{token('Enumerable')} whose names begin with #{string('ch')}.
  #{command('webri #')}               Show names of all instance methods.

- Singleton method:

  #{command('webri File::')}          Show names of all singleton methods in class #{token('File')}.
  #{command('webri File::ch')}        Show names of singleton methods in class #{token('File')} whose names begin with #{string('ch')}.
  #{command('webri FileUtils::')}     Show names of all singleton methods in class #{token('FileUtils')}.
  #{command('webri FileUtils::ch')}   Show names of singleton methods in class #{token('FileUtils')} whose names begin with #{string('ch')}.
  #{command('webri ::')}              Show names of all singleton methods.

- File:

  #{command('webri ruby:')}           Show names of all files.
  #{command('webri ruby:CO')}         Show names of files whose names begin with #{string('CO')}. 

EOT
  end

  def help_doc
    `ruby exe/webri --help`
  end

  def names_doc
    <<EOT
#{bold_italic('Names')}

In #{webri}, a #{variable('name')} is a string of one of four types, as determined by its prefix:

|------------------|----------------------|--------------------|
|    Name Type     |       Prefix         |      Example       |
|------------------|----------------------|--------------------|
| Class/module     | Capital letter       | #{tokenq('Array')}            |
| Singleton method | Double-colon (#{tokenq('::')})  | #{tokenq('::new')}            |
| Instance method  | Hash character (#{tokenq('#')}) | #{tokenq('#inspect')}         |
| Ruby file        | String #{tokenq('ruby:')}       | #{tokenq('ruby:syntax_rdoc')} |
|------------------|----------------------|--------------------|

Exception: there is one core class whose name begins with a lowercase letter: #{tokenq('fatal')}.

Note: On command-line, your shell may require you to escape certain characters:

    #{command('webri \\#size')}
    #{command('webri "Array.[]"')}
    #{command('webri compact#\\!')}

EOT
  end

  def files_doc
    <<EOT
#{bold_italic('Files')}

To open the web page for a Ruby file, type a #{variable('name')} starting with #{tokenq('ruby:')}.

When #{variable('name')} is the exact name of a Ruby file (but not the abbreviation of other file names),
#{webri} opens page for that file.
Examples: #{tokenq('ruby:README_md')}, #{tokenq('ruby:LEGAL')}, #{tokenq('ruby:NEWS_md')}, #{tokenq('ruby:syntax_rdoc')}.

When #{variable('name')} is the abbreviated name of exactly one file,
#{webri} asks whether to open page for that file.
Examples: 
 
  #{tokenq('ruby:maint')}              (for #{tokenq('ruby:maintainers_md')})
  #{tokenq('ruby:syntax/assign')}      (for #{tokenq('ruby:syntax/assignment_rdoc')})
  #{tokenq('ruby:language/pack')}      (for #{tokenq('ruby:language/packed_data_rdoc')})
  #{tokenq('ruby:contributing/build')} (for #{tokenq('ruby:contributing/building_ruby_md')})
  #{tokenq('ruby:optparse/arg')}       (for #{tokenq('ruby:optparse/argument_converters_rdoc')}).

When #{variable('name')} is the abbreviated name of multiple files,
#{webri} displays those names and lets you choose.
Examples: #{tokenq('ruby:syntax')}, #{tokenq('ruby:contrib')}, #{tokenq('ruby:lang')}, #{tokenq('ruby:jit')}.

When #{variable('name')} is not the abbreviated name of any file:
#{webri} asks whether show all file names.
Examples: #{tokenq('ruby:xyzzy')}, #{tokenq('ruby:nosuch')}.

EOT
  end

  def modules_doc
    <<EOT
#{bold_italic('Classes and Modules')}

To open web page for a class or module,
type a #{variable('name')} starting with a capital letter.

When #{variable('name')} is:

- The exact name of a class/module (but not beginning of other such names):
  #{webri} opens page for that class/module.
  Examples: #{tokenq('Array')}, #{tokenq('Hash')}, #{tokenq('Struct')}, #{tokenq('Integer')}, #{tokenq('Symbol')}.

- The abbreviated name of exactly one class/module:
  #{webri} asks whether to open page for that class/module.
  Examples:

    #{tokenq('Cov')}          (for #{tokenq('Coverage')}).
    #{tokenq('Eng')}          (for #{tokenq('English')}).
    #{tokenq('Ker')}          (for #{tokenq('Kernel')}).
    #{tokenq('Net::HTTP::D')} (for #{tokenq('Net::HTTP::Delete')}).}

- The abbreviated name of multiple classes/modules:
  #{webri} asks whether to show names if matching class/module names;
  if Yes, #{webri} displays those names and lets you choose.
  Examples: #{tokenq('String')}, #{tokenq('Float')}, #{tokenq('Regexp')}, #{tokenq('Net::HTTP')}.

- Not abbreviated name of any class/module:
  #{webri} asks whether show all class/module names.
  Examples: #{tokenq('Xyzzy')}, #{tokenq('Nosuch')}.

EOT
  end

  def instance_methods_doc
    <<EOT
#{bold_italic('Instance Methods')}

For an instance method, use #{webri} to open the web page for its class/module,
then automatically scroll to that method.

#{bold('Exact Full Name')}

If you know exact names of both the class/module and the instance method,
type both names, separated by a hash character (#{tokenq('#')}).

If the method name is not the abbreviation of other method names in that class/module,
#{webri} opens page for that class/module and scrolls to the method.
Examples: #{tokenq('Set#add?')}, #{tokenq('URI::Generic#absolute')}.

If the method name is the abbreviation of other method names in that class/module,
#{webri} lets you choose among those names.
Examples: #{tokenq('IO#close')}, #{tokenq('IO#each')}.

#{bold('Exact Class/Module Name')}

If you know exact name of class/module,
but not exact name of instance method,
type the name of the class/module followed by (#{tokenq('#')})
and abbreviated name of method.
Examples: #{tokenq('Pathname#ch')}, #{tokenq('Pathname#get')}.

To see names of all instance methods in a class/module,
type name of class/module followed by (#{tokenq('#')}).
Examples: #{tokenq('Pathname#')}, #{tokenq('IO#')}.

#{bold('Exact Instance Method Name')}

If you know the exact name of the instance method you want,
but are not sure which class/module has the method,
type (#{tokenq('#')}) followed by the exact method name.

If that instance method is defined in only one class/module,
#{webri} opens page for that class/module and scrolls to the method.
Examples: #{tokenq('File::Stat#uid')}, #{tokenq('FileUtils#uptodate?')}.

If the instance method is defined in multiple classes/modules,
#{webri} lets you choose among those names.
 
- The abbreviated name of multiple instance methods:
  #{webri} asks whether to show those names;
  if Yes, shows them and lets you choose; for your choice,
  #{webri} opens page for that class-module and scrolls to method.
  Examples: #{tokenq('#alias')}, #{tokenq('#line')}, #{tokenq('#rm')}.

- Not abbreviated name of any instance method:
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
    green_background: 42,
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
    ansi_color("'#{s}'", :green)
  end

  def command(s)
    bold('$ ' + s)
  end

end