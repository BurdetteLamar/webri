---
layout: default
title: webri
---

# `webri`

Console application `webri` lets you open web pages
for Ruby documentation from the command line:

- You enter the name (full or partial) of a Ruby class/module, method, or file.
- `webri` opens the corresponding page of the Ruby documentation in your browser.

If the name specifies a Ruby class/module or file,
`webri` opens the page for that class/module or file:

- `'Array'` opens the page for
  class [`Array`](https://docs.ruby-lang.org/en/master/Array.html).
- `'Enumerable'` opens the page for
  module [`Enumerable`](https://docs.ruby-lang.org/en/master/Enumerable.html).
- `'ruby:dig_methods_rdoc'` opens the page for
  file [`dig_methods`](https://docs.ruby-lang.org/en/master/language/dig_methods_rdoc.html).

If the name specifies a Ruby method,
`webri` opens the page for its class/module and scrolls to the method's documentation.

- `'Array#sort'` opens the page for class Array and scrolls to
  method [`#sort`](https://docs.ruby-lang.org/en/master/Array.html#method-i-sort).
- `'File::open'` opens the page for class File and scrolls to
  method [`::open`](https://docs.ruby-lang.org/en/master/File.html#method-c-open).

`webri` is a Ruby gem; see [Installation](installation.html).