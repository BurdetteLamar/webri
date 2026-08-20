---
layout: default
title: webri
---

# webri

Console application `webri` lets you access the web pages
from Ruby documentation in your web browser:

- You enter the name (full or partial) of a Ruby class/module, method, or file.
- `webri` opens the corresponding page of the Ruby documentation in your browser.

If the name specifies a Ruby class/module or file,
`webri` opens the page for that class/module or file:

- `'Array'` opens the
  [page for class Array](https://docs.ruby-lang.org/en/master/Array.html).
- `'Enumerable'` opens the
  [page for module Enumerable](https://docs.ruby-lang.org/en/master/Enumerable.html).
- `'ruby:dig_methods_rdoc'` opens the
  [page for file dig_methods_rdoc](https://docs.ruby-lang.org/en/master/language/dig_methods_rdoc.html).

If the name specifies a Ruby method,
`webri` opens the page for its class/module and scrolls to the method's documentation.
