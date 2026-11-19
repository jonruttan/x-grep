# x-grep card

## Run

```sh
x -l grep 'PATTERN' FILE...
x -l grep -- -in -e 'PATTERN' -f PATTERN-FILE FILE...
printf 'aa\nbb\n' | x -l grep a -> aa
printf 'aa\nbb\n' | x -l grep -- -v a -> bb
printf 'aa\nbb\n' | x -l grep -- -c a -> 1
printf 'aa\nbb\n' | x -l grep -- -n b -> 2:bb
printf 'Aa\nbb\n' | x -l grep -- -i a -> Aa
printf 'a.c\nabc\n' | x -l grep -- -F a.c -> a.c
printf 'ab\ncd\n' | x -l grep -- -E 'a|x' -> ab
printf 'cat\ncats\n' | x -l grep -- -w cat -> cat
printf 'cat\ncats\n' | x -l grep -- -x cats -> cats
printf 'key=val\n' | x -l grep -- -o 'v.*' -> val
printf 'a\na\na\n' | x -l grep -- -c -m 2 a -> 2
printf 'a\n' | x -l grep -- -q a; echo $? -> 0
printf 'a\n' | x -l grep b; echo $? -> 1
```

| Operand      | Meaning                                                  |
|--------------|----------------------------------------------------------|
| `--`         | ends x's own options; grep's options follow it           |
| `PATTERN`    | the first operand, unless `-e` or `-f` gave the patterns |
| `-e PATTERN` | a pattern; may be given more than once                   |
| `-f FILE`    | patterns from FILE, one a line; more than once           |
| `FILE...`    | the files to read; `-` and no file are standard input    |

## Patterns

| Basic         | With `-E`     | Matches                                |
|---------------|---------------|----------------------------------------|
| `.`           | `.`           | any one character                      |
| `*`           | `*`           | the one before it, any number of times |
| `^` `$`       | `^` `$`       | the start of the line, the end         |
| `[abc]`       | `[abc]`       | one of these characters                |
| `[^abc]`      | `[^abc]`      | one character that is none of these    |
| `[a-z]`       | `[a-z]`       | one character in the range             |
| `[[:digit:]]` | `[[:digit:]]` | one of a named class                   |
| `\(RE\)`      | `(RE)`        | a group                                |
| `\{2,4\}`     | `{2,4}`       | the one before it, two to four times   |
| `\+` `\?`     | `+` `?`       | one or more; none or one               |
| `A\\|B`       | `A\|B`         | either                                 |
| `\.` `\*`     | `\.` `\*`     | the character itself                   |
| any text      | any text      | with `-F`: the text itself, no forms   |

```input
alice 30 nyc
bob 25 sf
carol 35 nyc
```

```grep
nyc
```

```output
alice 30 nyc
carol 35 nyc
```

```grep
^b
```

```output
bob 25 sf
```

```grep
sf$
```

```output
bob 25 sf
```

```grep
3[0-9]
```

```output
alice 30 nyc
carol 35 nyc
```

```grep
^[^ ]* 2
```

```output
bob 25 sf
```

```grep
o.* [[:digit:]]\{2\}
```

```output
bob 25 sf
carol 35 nyc
```

```grep
ali\|bob
```

```output
alice 30 nyc
bob 25 sf
```

### A pattern file

```input
alice 30 nyc
bob 25 sf
carol 35 nyc
```

```grep
^a
35
```

```output
alice 30 nyc
carol 35 nyc
```

## Options

### Which lines

| Option | Selects                                              |
|--------|------------------------------------------------------|
| `-i`   | without regard to case                               |
| `-v`   | the lines that do not match                          |
| `-w`   | a match that is a whole word                         |
| `-x`   | a match that is the whole line                       |
| `-E`   | patterns are extended regular expressions            |
| `-F`   | patterns are fixed strings                           |
| `-m N` | stop after N selected lines                          |

### What is printed

| Option | Prints                                               |
|--------|------------------------------------------------------|
| `-n`   | the line number before each line                     |
| `-c`   | only a count of the selected lines                   |
| `-o`   | only the part that matched, each match on a line     |
| `-l`   | only the names of files with a selected line         |
| `-L`   | only the names of files with none                    |
| `-q`   | nothing: the status is the answer                    |
| `-H`   | the file name before each line                       |
| `-h`   | no file name, even with several files                |
| `-A N` | N lines after each selected line                     |
| `-B N` | N lines before                                       |
| `-C N` | N lines before and after                             |

### Where it reads

| Option    | Reads                                             |
|-----------|---------------------------------------------------|
| `-r` `-R` | each directory named, and all beneath it          |
| `-s`      | without a message for a file it cannot read       |

### Status

| Status | Means                    |
|--------|--------------------------|
| `0`    | a line was selected      |
| `1`    | none was                 |
| `2`    | trouble: a file, a pattern, an option |

## Differs

| Here                                    | In the grep on most systems      |
|-----------------------------------------|----------------------------------|
| `\1` in a pattern is refused            | a back-reference                 |
| `-oE 'a\|ab'` on `ab` prints `a`         | `ab`: the longest alternative    |
| options stop at the first operand       | GNU grep takes them anywhere     |

## More

| Where                         | What                                  |
|-------------------------------|---------------------------------------|
| `README.md`                   | what is built, and each difference    |
| `tests/specs/02-match.spec.md` | one case a behaviour                 |
| `make card`                   | runs every pattern file on this page  |
