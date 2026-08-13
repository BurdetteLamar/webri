# `webri` - Command-Line Access to Ruby Online Documentation

## Caveat Lector (13-Aug-2026)

The earlier [webri gem](https://rubygems.org/gems/webri) remains available:

```ruby
gem install webri
```

For now, I need this forward-looking README to be here in the GitHub pages,
so that I can verify that the in-development `webri` can open it properly.

I expect to have everything completed, up, and running by the next Ruby release (4.1)
at Christmas.  Also, will then add docs data for that release.

`webri` is a console application for displaying Ruby online documentation
in your web browser.

You type a name specifying what documentation to display,
and `webri` opens the desired page in your web browser.

`webri` is in some ways similar to [Ruby's `ri` utility][ri],
but differs mainly in that:

- `ri` displays text-only documentation your command window.
- `webri` opens web pages from [Ruby official on-line documentation][ruby documentation].
  in your web browser.

For:

- A class or module: `webri` opens its web page.
- A method: `webri` opens the web page for its class/module and scrolls to the method.
- A Ruby file: `webri` opens a free-standing Ruby file.

## Usage

```
webri [options] [name]
```

`webri` has two modes:

- Immediate mode (name given on command line);
  processes just the one name (possibly with minor interaction).
- Interactive mode (no name given on command line);
  enters loop: accept name, process name, repeat.

A name may be:

- The name of a [class or module][classes and modules].
- The name of a [singleton method][singleton methods].
- The name of an [instance method][instance methods].
- The name of a [Ruby file][files].
- An abbreviation of any of the above.

### Classes and Modules

To open the page for a class or module,
type its name (e.g., `'Array'`),
which may be abbreviated to an initial substring (e.g., `'Ar'`).

`webri` finds the names of classes and modules beginning with that name.

When only one matching class or module name is found,
`webri` opens its web page (if the full name),
or asks whether to open it (if an abbreviation).

When multiple matching class and module names are found,
`webri` lists them and lets you choose.

When no matching class or module name is found,
`webri` offers to list all class and module names and let you choose.

### Singleton Methods

For a `name` beginning with `::`,
WebRI finds the names of singleton methods beginning
with that name.

When exactly one such singleton method name is found:

- If `name` is the exact name of one singleton method, opens its class/module page at that method:

```
webri> ::zcat
Found one singleton method name starting with '::zcat'
  ::zcat
Opening web page https://docs.ruby-lang.org/en/3.4/Zlib/GzipReader.html at method ::zcat.

```

- If `name` is the start of the found name, offers to open its page:

```
webri> ::zca
Found one singleton method name starting with '::zca'
  ::zcat
Open page Zlib/GzipReader.html at method ::zcat? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/Zlib/GzipReader.html at method ::zcat.
```

When multiple such singleton method names are found offer to list the found names:

```
webri> ::z
Found 5 singleton method names starting with '::z'.
Show 5 names?' (y or n):  y
       0:  ::zcat (in Zlib::GzipReader)
       1:  ::zero? (in File)
       2:  ::zip? (in RDoc::Parser)
       3:  ::zlib_version (in Zlib)
       4:  ::zone_offset (in Time)
Type a number to choose, or Return to skip:  3
Opening web page https://docs.ruby-lang.org/en/3.4/Zlib.html at method ::zlib_version.

```

When no such singleton method name is found, offers to list all singleton method names:

```
webri> ::nosuch
Found no singleton method name starting with '::nosuch'.
Show names of all 2288 singleton methods? (y or n):  n
```

### Instance Methods

For a `name` beginning with `#`,
WebRI finds the names of instance methods beginning
with that name.

When exactly one such instance method name is found:

- If `name` is the exact name of one instance method, opens its class/module page at that method:

```
webri> #yield_self
Found one instance method name starting with '#yield_self'
  #yield_self
Opening web page https://docs.ruby-lang.org/en/3.4/Kernel.html at method #yield_self.
```

- If `name` is the start of the found name, offers to open its page:

```
webri> #yield_s
Found one instance method name starting with '#yield_s'
  #yield_self
Open page Kernel.html at method #yield_self? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/Kernel.html at method #yield_self.
```

When multiple such instance method names are found offer to list the found names:

```
webri> #yield
Found 4 instance method names starting with '#yield'.
Show 4 names?' (y or n):  y
       0:  #yield (in Proc)
       1:  #yield_node (in Prism::DSL)
       2:  #yield_self (in Kernel)
       3:  #yields_directive (in RDoc::MarkupReference)
Type a number to choose, or Return to skip:  0
Opening web page https://docs.ruby-lang.org/en/3.4/Proc.html at method #yield.
```

When no such instance method name is found, offers to list all instance method names:

```
webri>
webri> #nosuch
Found no instance method name starting with '#nosuch'.
Show names of all 10370 instance methods? (y or n):  n
```

### Files

For a name beginning with `ruby:`,
finds the names of ruby pages beginning
with that name.

When exactly one such page name is found:

- If the name is the exact name of the found name, opens its page:

```
webri> ruby:operators
Found one page name starting with 'operators'
  operators (syntax/operators_rdoc.html)
```

- If `name` is the start of the found name, offers to open its page:

```
webri> ruby:opera
Found one page name starting with 'opera'
  operators (syntax/operators_rdoc.html)
Open page syntax/operators_rdoc.html? (y or n):  y
Opening web page https://docs.ruby-lang.org/en/3.4/syntax/operators_rdoc.html.

```

When multiple such page names are found offer to list the found names:

```
webri> ruby:o
Found 4 page names starting with 'o'.
Show 4 names?' (y or n):  y
       0:  operators (syntax/operators_rdoc.html)
       1:  option_dump (ruby/option_dump_md.html)
       2:  option_params (optparse/option_params_rdoc.html)
       3:  options (ruby/options_md.html)
Type a number to choose, or Return to skip:  2

```

When no such page name is found, offers to list all page names:

```
webri> ruby:nosuch
Found no page name starting with 'nosuch'.
Show names of all 83 pages? (y or n):  y
       0:  COPYING (COPYING.html)
       1:  COPYING.ja (COPYING_ja.html)
       2:  LEGAL (LEGAL.html)
       3:  NEWS (NEWS_md.html)
       4:  NEWS-1.8.7 (NEWS/NEWS-1_8_7.html)
       5:  NEWS-1.9.1 (NEWS/NEWS-1_9_1.html)
       6:  NEWS-1.9.2 (NEWS/NEWS-1_9_2.html)
       7:  NEWS-1.9.3 (NEWS/NEWS-1_9_3.html)
       8:  NEWS-2.0.0 (NEWS/NEWS-2_0_0.html)
       9:  NEWS-2.1.0 (NEWS/NEWS-2_1_0.html)
      10:  NEWS-2.2.0 (NEWS/NEWS-2_2_0.html)
      11:  NEWS-2.3.0 (NEWS/NEWS-2_3_0.html)
      12:  NEWS-2.4.0 (NEWS/NEWS-2_4_0.html)
      13:  NEWS-2.5.0 (NEWS/NEWS-2_5_0.html)
      14:  NEWS-2.6.0 (NEWS/NEWS-2_6_0.html)
      15:  NEWS-2.7.0 (NEWS/NEWS-2_7_0.html)
      16:  NEWS-3.0.0 (NEWS/NEWS-3_0_0_md.html)
      17:  NEWS-3.1.0 (NEWS/NEWS-3_1_0_md.html)
      18:  NEWS-3.2.0 (NEWS/NEWS-3_2_0_md.html)
      19:  NEWS-3.3.0 (NEWS/NEWS-3_3_0_md.html)
      20:  README (README_md.html)
      21:  README.ja (README_ja_md.html)
      22:  argument_converters (optparse/argument_converters_rdoc.html)
      23:  assignment (syntax/assignment_rdoc.html)
      24:  bsearch (bsearch_rdoc.html)
      25:  bug_triaging (bug_triaging_rdoc.html)
      26:  building_ruby (contributing/building_ruby_md.html)
      27:  calendars (date/calendars_rdoc.html)
      28:  calling_methods (syntax/calling_methods_rdoc.html)
      29:  case_mapping (case_mapping_rdoc.html)
      30:  character_selectors (character_selectors_rdoc.html)
      31:  command_injection (command_injection_rdoc.html)
      32:  comments (syntax/comments_rdoc.html)
      33:  contributing (contributing_md.html)
      34:  control_expressions (syntax/control_expressions_rdoc.html)
      35:  creates_option (optparse/creates_option_rdoc.html)
      36:  dig_methods (dig_methods_rdoc.html)
      37:  distribution (distribution_md.html)
      38:  documentation_guide (contributing/documentation_guide_md.html)
      39:  dtrace_probes (dtrace_probes_rdoc.html)
      40:  encodings (encodings_rdoc.html)
      41:  exceptions (exceptions_md.html)
      42:  exceptions (syntax/exceptions_rdoc.html)
      43:  extension (extension_rdoc.html)
      44:  extension.ja (extension_ja_rdoc.html)
      45:  fiber (fiber_md.html)
      46:  format_specifications (format_specifications_rdoc.html)
      47:  globals (globals_rdoc.html)
      48:  glossary (contributing/glossary_md.html)
      49:  implicit_conversion (implicit_conversion_rdoc.html)
      50:  index (index_md.html)
      51:  keywords (syntax/keywords_rdoc.html)
      52:  literals (syntax/literals_rdoc.html)
      53:  maintainers (maintainers_md.html)
      54:  making_changes_to_ruby (contributing/making_changes_to_ruby_md.html)
      55:  making_changes_to_stdlibs (contributing/making_changes_to_stdlibs_md.html)
      56:  marshal (marshal_rdoc.html)
      57:  memory_view (memory_view_md.html)
      58:  methods (regexp/methods_rdoc.html)
      59:  methods (syntax/methods_rdoc.html)
      60:  miscellaneous (syntax/miscellaneous_rdoc.html)
      61:  modules_and_classes (syntax/modules_and_classes_rdoc.html)
      62:  operators (syntax/operators_rdoc.html)
      63:  option_dump (ruby/option_dump_md.html)
      64:  option_params (optparse/option_params_rdoc.html)
      65:  options (ruby/options_md.html)
      66:  packed_data (packed_data_rdoc.html)
      67:  pattern_matching (syntax/pattern_matching_rdoc.html)
      68:  precedence (syntax/precedence_rdoc.html)
      69:  ractor (ractor_md.html)
      70:  refinements (syntax/refinements_rdoc.html)
      71:  reporting_issues (contributing/reporting_issues_md.html)
      72:  rjit (rjit/rjit_md.html)
      73:  security (security_rdoc.html)
      74:  signals (signals_rdoc.html)
      75:  standard_library (standard_library_md.html)
      76:  strftime_formatting (strftime_formatting_rdoc.html)
      77:  syntax (syntax_rdoc.html)
      78:  testing_ruby (contributing/testing_ruby_md.html)
      79:  tutorial (optparse/tutorial_rdoc.html)
      80:  unicode_properties (regexp/unicode_properties_rdoc.html)
      81:  windows (windows_md.html)
      82:  yjit (yjit/yjit_md.html)
Type a number to choose, or Return to skip:  80
Opening web page https://docs.ruby-lang.org/en/3.4/regexp/unicode_properties_rdoc.html.
```

### Special Names

To display the WebRI help text, use the special name `@help`:

```
$ ruby exe/webri
webri> @help
Showing help.
webri is a console application for displaying Ruby online HTML documentation.
Documentation pages are opened in the default web browser.

Usage: webri [options]

For more information, see https://github.com/BurdetteLamar/webri/blob/main/README.md.

Options:
    -i, --info                       Prints information about webri.
    -r, --release=RELEASE            Sets the Ruby release to document.
        --noreline                   Does not use Reline (helps testing).
    -n, --noop                       Does not actually open web pages.
    -h, --help                       Prints this help.
    -v, --version                    Prints the version of webri.
```

To open the WebRI README page, use the special name `@readme`:

```
webri> @readme
Opening web page https://github.com/BurdetteLamar/webri/blob/main/README.md.
```

### Reline

`webri` uses [Reline][Reline]
(on Linux, but not on other OS platforms).

Reline enables editing of text at the `webri` prompt (use left- and right-arrows),
and gives access to history (use up-arrow).

### Options

Option `--info` prints information about WebRI,
including the documentation release to be used (`3.4` in this example),
then exits:

```
$ webri --info
Ruby documentation release:  '3.4'
Ruby documentation URL:      'https://docs.ruby-lang.org/en/3.4/table_of_contents.html'
Executable to open page:     'start'
Names:
   1364 class names
   1175 singleton_method names
   4407 instance_method names
     81 page names
```

Option `--release` sets the release of the documentation to be used.
The collections of names will vary among releases:

```
$ webri --release=3.2 --info
Ruby documentation release:  '3.2'
Ruby documentation URL:      'https://docs.ruby-lang.org/en/3.2/table_of_contents.html'
Executable to open page:     'start'
Names:
   1262 class names
   1301 singleton_method names
   4397 instance_method names
     73 page names
$ webri --release=3.3 --info
Ruby documentation release:  '3.3'
Ruby documentation URL:      'https://docs.ruby-lang.org/en/3.3/table_of_contents.html'
Executable to open page:     'start'
Names:
   1469 class names
   1270 singleton_method names
   4638 instance_method names
     77 page names
```

Issues a message if the given release is unknown:

```
$ webri --release foo
Unknown documentation release:  foo
Master release:                 master
Supported releases:             3.4, 3.3, 3.2
Unsupported releases:           3.1, 3.0
```

Option `--noop` suppresses the actual opening of a web page,
instead reporting the relevant command:

```
$ webri --noop Array
Found one class/module name starting with 'Array'
  Array (Array.html)
Opening web page https://docs.ruby-lang.org/en/3.4/Array.html.
Command: 'start https://docs.ruby-lang.org/en/3.4/Array.html'
```

Option `--noreline` blocks Reline behavior; see [Reline][reline].

Option `--help` prints the WebRI help text.

Option `--version` prints the WebRI version.

## Installation

To install the gem:

```
$ gem install webri
```

## Bugs and Issues

Bug reports and comments are welcome at [issues][issues].

## License

The gem is available as open source under the terms
of the [MIT License][mit license].

## Code of Conduct

Everyone interacting in the Webri project's codebases,
issue trackers, chat rooms and mailing lists is expected
to follow the [code of conduct][code of conduct]

[classes and modules]: #classes-and-modules
[singleton methods]:   #singleton-methods
[instance methods]:    #instance-methods
[files]:               #files
[special names]:       #special-names
[reline]:              #reline

[code of conduct]: https://github.com/BurdetteLamar/webri/blob/main/CODE_OF_CONDUCT.md
[issues]:          https://github.com/BurdetteLamar/webri/issues

[Reline]:             https://ruby.github.io/reline/Reline.html
[ri]:                 https://ruby.github.io/rdoc/RI_md.html)
[ruby documentation]: https://docs.ruby-lang.org/en
[mit license]:        https://opensource.org/licenses/MIT