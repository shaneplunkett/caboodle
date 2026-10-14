# Vim Cheatsheet

## Motions I'm Building

  b           back one word (opposite of w)
  f{char}     jump TO {char} on this line (; to repeat)
  t{char}     jump TILL {char} (one before it)
  {n}j / {n}k jump n lines down/up (use relative numbers!)
  0           jump to start of line
  ^           jump to first non-blank character
  $           jump to end of line
  %           jump to matching bracket

## Things I Keep Forgetting

  a           append (insert AFTER cursor, not before)
  A           append at END of line
  V           visual LINE mode (select whole lines)
  Ctrl-r      redo (undo the undo)
  db          delete backwards to start of word

## Operator + Motion Combos

  ciw         change inner word (delete word, enter insert)
  diw         delete inner word
  ci"         change inside quotes
  di(         delete inside parens
  da{         delete around braces (including the braces)
  yi"         yank inside quotes
  ya{         yank around braces
  dt{char}    delete up TILL {char}
  cf{char}    change from cursor through {char}
  yt{char}    yank up TILL {char}

## Yank & Put Tricks

  yy          yank whole line
  y5j         yank this line + 5 below
  V then y    visual select lines then yank
  p           put AFTER cursor / below line
  P           put BEFORE cursor / above line

## Text Objects (the i/a pattern)

  iw  inner word       aw  a word (+ space)
  i"  inner quotes     a"  a quotes (+ quotes)
  i(  inner parens     a(  a parens (+ parens)
  i{  inner braces     a{  a braces (+ braces)
  it  inner tag        at  a tag (HTML)
