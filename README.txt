Console application webri displays Ruby online HTML documentation
in the default web browser.

Usage: webri [options] [name]

Options:

    -r, --release RELEASE            Specify documentation release (one of ["3.2", "3.4", "4.0"]).
    -i, --info                       Print information about webri.
    -h, --help                       Print this help.
    -v, --version                    Print the version of webri.

Options useful for testing webri:

        --noreline                   Do not use Reline.
        --noansi                     Do not output ansi escape codes.
        --noop                       Do not actually open web pages.
Names

Argument name is one of four types, as determined by its prefix:

|------------------|----------------|--------------------|
|       Type       |     Prefix     |      Example       |
|------------------|----------------|--------------------|
| Class/module     | Capital letter | 'Array'            |
| Singleton method | '::'           | '::new'            |
| Instance method  | '#'            | '#inspect'         |
| Ruby file        | 'ruby:'        | 'ruby:syntax_rdoc' |
|------------------|----------------|--------------------|

Note: On the command-line, your shell may require you to escape the instance method prefix:

    '\#size' (instead of just '#size')


Files

To get the web page for a Ruby file,
type a name starting with 'ruby:'.

When the name is:

- The exact name of a Ruby file (but not the beginning of other such names):
  webri opens the page for that file.
  Examples: 'ruby:README_md', 'ruby:LEGAL', 'ruby:NEWS_md', 'ruby:syntax_rdoc'.

- The partial name of exactly one file:
  webri asks whether to open the page for that file.
  Examples: 
 
  - 'ruby:maint'              (for 'ruby:maintainers_md')
  - 'ruby:syntax/assign'      (for 'ruby:syntax/assignment_rdoc')
  - 'ruby:language/pack'      (for 'ruby:language/packed_data_rdoc')
  - 'ruby:contributing/build' (for 'ruby:contributing/building_ruby_md')
  - 'ruby:optparse/arg'       (for 'ruby:optparse/argument_converters_rdoc').

- The partial name of multiple files:
  webri displays those names and lets you choose.
  Examples: 'ruby:syntax', 'ruby:contrib', 'ruby:lang', 'ruby:jit'.

- Not the partial name of any file:
  webri asks whether show all file names.
  Examples: 'ruby:xyzzy', 'ruby:nosuch'.

Classes and Modules

To get the web page for a class or module,
type a name starting with a capital letter.

When the name is:

- The exact name of a class/module (but not the beginning of other such names):
  webri opens the page for that class/module.
  Examples: 'Array', 'Hash', 'Struct', 'Integer', 'Symbol'.

- The abbreviated name of exactly one class/module:
  webri asks whether to open the page for that class/module.
  Examples:

  - 'Cov'          (for 'Coverage').
  - 'Eng'          (for 'English').
  - 'Ker'          (for 'Kernel').
  - 'Net::HTTP::D' (for 'Net::HTTP::Delete').}

- The abbreviated name of multiple classes/modules:
  webri asks whether to open the page for that class/module;
  if Yes, webri displays those names and lets you choose.
  Examples: 'String', 'Float', 'Regexp', 'Net::HTTP'.

- Not the abbreviated name of any class/module:
  webri asks whether show all class/module names.
  Examples: 'Xyzzy', 'Nosuch'.

Instance Methods

You can open the web page for an instance method (and scroll to that method).

With the Class/Module Name

If you know the name of the class/module that has the method,

Without the Class/Module Name

If you're not sure of the class/module that has the method,

To get the web page for an instance method (and scroll to that method),
type a name starting with '#'.

When the name is:

- The exact name of an instance method (but not the beginning of other such names):

  - If that method appears in only one class/module,
    webri opens the page for that class-module and scrolls to the method.
    Examples: '#abbreviate', '#mountpoint?', '#xmlschema'.

  - If the method appears in multiple classes/modules,
    webri shows them and lets you choose; for your choice,
    webri opens the page for that class-module and scrolls to the method.
    Examples: '#birthtime', '#frozen?', '#owner'.
 
- The partial name of multiple instance methods:
  webri asks whether to show those names;
  if Yes, shows them and lets you choose; for your choice,
  webri opens the page for that class-module and scrolls to the method.
  Examples: '#alias', '#line', '#rm'.

- Not the partial name of any instance method:
  webri asks whether show all instance method names.
  Examples: '#xyzzy', '#nosuch'.

