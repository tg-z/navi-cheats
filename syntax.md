Cheatsheet syntax
-----------------

Cheatsheets are described in `.cheat` files that look like this:

```sh
% git, code
# Change branch
git checkout <branch>
$ branch: git branch | awk '{print $NF}'
```

### Syntax overview

- lines starting with `%` determine the start of a new cheatsheet and should contain tags, useful for searching;
- lines starting with `#` should be descriptions of commands;
- lines starting with `;` are ignored. You can use them for metacomments;
- lines starting with `$` should contain commands that generate a list of possible values for a given argument;
- all the other non-empty lines are considered as executable commands.

It's irrelevant how many files are used to store cheatsheets. They can be all in a single file if you ish, as long as you split them accordingly with lines starting with `%`.

### Variables

The interface prompts for variable names inside brackets (eg `<branch>`). 

Variable names should only include alphanumeric characters and `_`.

If there's a corresponding line starting with `$` for a variable, suggestions will be displayed. Otherwise, the user will be able to type any value for it.

If you hit `<tab>` the query typed will be prefered. If you hit `<enter>` the selection will be prefered.

### Advanced variable options

For lines starting with `$` you can use `---` to customize the behavior of `fzf` or how the value is going to be used:

```sh
# This will pick the 3rd column and use the first line as header
docker rmi <image_id>
# Even though "false/true" is displayed, this will print "0/1"
echo <mapped>
$ image_id: docker images --- --column 3 --header-lines 1 --delimiter '\s\s+'
$ mapped: echo 'false true' | tr ' ' '\n' --- --map "[[ $0 == t* ]] && echo 1 || echo 0"
```

The supported parameters are:
- `--prevent-extra` *(experimental)*: limits the user to select one of the suggestions;
- `--column <number>`: extracts a single column from the selected result;
- `--map <bash_code>` *(experimental)*: applies a map function to the selected variable value;

In addition, it's possible to forward the following parameters to `fzf`:
- `--multi`;
- `--header-lines <number>`;
- `--delimiter <regex>`;
- `--query <text>`;
- `--filter <text>`;
- `--header <text>`;
- `--preview <bash_code>`;
- `--preview-window <text>`.

### Variable dependency

The command for generating possible inputs can refer previous variables:
```sh
# If you select "hello" for <x>, the possible values of <y> will be "hello foo" and "hello bar"
echo <x> <y>
$ x: echo "hello hi" | tr ' ' '\n'
$ y: echo "$x foo;$x bar" | tr ';' '\n'
```

### Multiline snippets

Commands may be multiline:
```sh
# This will output "foo\nyes"
echo foo
true \
   && echo yes \
   || echo no
```

### Variable as multiple arguments

```sh
# This will result into: cat "file1.json" "file2.json"
jsons=($(echo "<jsons>"))
cat "${jsons[@]}"
$ jsons: find . -iname '*.json' -type f -print --- --multi
```

List customization
------------------

Lists can be stylized with the [$FZF_DEFAULT_OPTS](https://github.com/junegunn/fzf#layout) environment variable or similar variables/parameters (please refer to `navi --help`). This way, you can change the [color scheme](https://github.com/junegunn/fzf/wiki/Color-schemes), for example.
w
