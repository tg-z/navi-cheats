#!/usr/bin/env bash

set -e

if [ -t 1 ] && [ -z "$NEAT_NO_COLOR" ]; then
  c_reset=$(tput sgr0)
  c_bold=$(tput bold)
  c_blue=$(tput setaf 4)
  c_white=$(tput setaf 7)
fi

### utilities

warn() {
  echo "neat: $@" 1>&2;
}

# Get data for a cheat with the given name
get_cheat_data() {
  local name=$1
  echo $NEAT_CHEAT_DATA | tr '|' '\n' | grep "^${name};"
}

cheat_field() {
  echo $1 | cut -d ';' -f $2
}

cheat_name() { cheat_field "$1" 1; }
cheat_file() { cheat_field "$1" 2; }
cheat_tags() { cheat_field "$1" 3 | tr ':' '\n'; }

realpath() {
  local native=$(type -p grealpath realpath | head -1)
  if [ -n "$native" ]; then
    $native "$1"
  else
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
  fi
}

# Returns 0 if an exact match is included in a list, non-zero otherwise.
includes() {
  echo "$1" | grep -q "^$2$"
}

# Takes a semicolon-delimited list and prints it with a nice title. Prints
# nothing if the list is empty.
fancy_list() {
  local items="$1" title="$2"
  [ -z "$items" ] && return
  echo -e "\n${c_bold}${c_blue}== ${c_white}$title${c_blue} ==${c_reset}"
  echo "$items"
}

singularize_type() {
  case "$1" in
    aliases) echo alias ;;
    functions) echo function ;;
    variables) echo variable ;;
  esac
}

# Takes the name of an item (function, alias, or variable) and echos the names
# of any cheats it is included in, if any, followed by the type of item. The
# cheat name and type of item are separated by a colon.


cheat_cache_dir() {
  if [ -n "$NEAT_CACHE_DIR" ]; then
    echo "$NEAT_CACHE_DIR"
    return
  fi

  echo "$HOME/.neat_cheat_cache"
}

initialize_cache() {
  local cache_dir=$(cheat_cache_dir)
  if [ ! -d "$cache_dir" ]; then
    mkdir "$cache_dir" || { warn "Could not create cache directory: $cache_dir"; return 1; }
  fi
}

cheat_name_for_path() {
  basename "${1%.*}"
}

cache_file_path() {
  local cheat_name="$(cheat_name_for_path "$1")"
  echo "$(cheat_cache_dir)/$cheat_name"
}

write_cache() {
  local cheat_path="$1" cheat_content="$2"
  initialize_cache || return 1
  local cheat_cache_file=$(cache_file_path "$cheat_path")
  echo "$cheat_content" > "$cheat_cache_file"
}

read_cache() {
  local cheat_path="$1"
  [ -d "$(cheat_cache_dir)" ] || return 1
  local cheat_cache_file=$(cache_file_path "$cheat_path")
  [ -f "$cheat_cache_file" ] || return 1
  [ "$cheat_path" -nt "$cheat_cache_file" ] && return 1
  cat "$cheat_cache_file"
}

# Prints comments from this file starting at the given line number and stopping
# when the next line does not start with a comment.
print_comments_starting_at_line() {
  cat "$BASH_SOURCE" | tail -n "+$1" | awk '{if (/^#/) print; else exit}' | cut -c3-
  echo ''
}

### Top-level functions

# Usage: neat list
#
# Lists the names of cheats that have been previously loaded with
# `neat load <cheat_file>'. The name of a cheat is the file name with
# any extension removed.
list_cheats() {
  echo $NEAT_CHEAT_DATA | tr '|' '\n' | cut -d ';' -f 1
}

# Usage: neat show <cheat_name>
#
# Prints information about the cheat with the given name, including the
# name and file path, as well as the functions, aliases, and variables
# defined in the cheat.
show_cheat() {
  local cheat_data=$(get_cheat_data $1)
  [ -z "$cheat_data" ] && die "Unknown cheat name: $1"
  local name source_file aliases funcs vars
  name=$(cheat_name "$cheat_data")
  source_file=$(cheat_file "$cheat_data")
  aliases=$(cheat_aliases "$cheat_data")
  funcs=$(cheat_functions "$cheat_data")
  vars=$(cheat_variables "$cheat_data")

  echo "${c_bold}Plugin name:${c_reset} $name"
  echo "${c_bold}Source file:${c_reset} $source_file"
  fancy_list "$aliases" 'Aliases'
  fancy_list "$funcs" 'Functions'
  fancy_list "$vars" 'Variables'
  echo ''
}

# Usage: neat edit <cheat_or_item_name>
#
# Opens a cheat file in your editor.
#
# If the name of a cheat is given, the file for the cheat with with that
# name is opened.
#
# If the names of a function, alias, or variable defined in a function is
# given, then the cheat file containing the item is opened.
#
# The editor used will be chosen from the NEAT_EDITOR environment variable
# or the EDITOR environment variable, in that order. If neither is set then
# vi is used.
edit_cheat() {
  local item_name="$1"
  local cheat_data=$(get_cheat_data $item_name)
  if [ -z "$cheat_data" ]; then
    local cheat_name_and_item_type=$(find_item $item_name)
    if [ -n "$cheat_name_and_item_type" ]; then
      cheat_data=$(get_cheat_data ${cheat_name_and_item_type%:*})
    fi
  fi
  [ -z "$cheat_data" ] && die "Unknown cheat, function, alias, or variable: $1"

  local editor=$NEAT_EDITOR
  [ -z "$editor" ] && editor=$EDITOR
  [ -z "$editor" ] && editor=nvim

  $editor $(cheat_file "$cheat_data")
}

# Usage: neat which <item_name>
#
# Finds which cheat a given function, alias, or variable is defined in.
which_cheat() {
  local item_name="$1"
  local cheat_name_and_item_type=$(find_item $item_name)
  if [ -n "$cheat_name_and_item_type" ]; then
    local cheat_name=${cheat_name_and_item_type%:*}
    local item_type=${cheat_name_and_item_type##*:}
    local article=a
    [ "$item_type" = "alias" ] && article=an
    echo "$item_name is $article $item_type in the cheat $cheat_name"
  else
    echo "($item_name not found in any cheat)" >&2
    return 1
  fi
}

# Usage: neat help [<command_name>]
#
# Prints help information.
#
# With no command name given, basic commands and usage are printed.
#
# If a command name is given, then usage for that command is printed.
print_help() {
  local cmd="$1"
  if [ -n "$cmd" ]; then
    local doc_first_line=$(grep -n "^# Usage: neat $cmd" "$BASH_SOURCE")
    if [ -n "$doc_first_line" ]; then
      local doc_first_line_number=$(echo "$doc_first_line" | cut -d ':' -f 1)
      print_comments_starting_at_line $doc_first_line_number
    else
      die "No such command '$cmd'"
    fi
  else
    print_comments_starting_at_line 9
  fi
}

# (Documentation comments for load command included here, even though it is defined
# in the init section, so that it is parseable with the rest of the top-level commands)

# Usage: neat load <cheat_file>
#
# Loads a cheat from the given file.
#
# A cheat is merely a file with normal shell code. When loaded, Shy sources the
# file and records the names of the functions, aliases, and environment variables
# defined (for the first time) while sourcing the file.

# Usage: neat init
#
# Prints Shy code that must be sourced in the interactive shell environment.
#
# This should generally only be used in the following initial configuration of
# Shy, which should be placed in your shell's rc file, after the main neat
# executable is placed on the PATH.
#
#   eval "$(neat init)"
print_initialization() {
  cat <<EOS
neat() {
  case "\$1" in

    ### Porcelain

    # Load a cheat from a file
    load)
      local cheat_file="\$2" cheat_basename cheat_name new_cheat_data
      if [ -z "\$cheat_file" ]; then
        neat _err "Usage: neat load CHEAT_NAME"
      elif [ ! -f "\$cheat_file" ]; then
        neat _err "neat: file does not exist: \$cheat_file"
      else
        cheat_file=\$(neat _realpath \$cheat_file)
        cheat_basename="\$(basename \$cheat_file)"
        cheat_name="\${cheat_basename%.*}"

        if new_cheat_data=\$(neat _read_cache "\$cheat_file"); then
          neat _debug "Plugin data retrieved from cache: \${cheat_file}"
          source "\$cheat_file"
          new_cheat_data="\$cheat_name;\$cheat_file;\$new_cheat_data"
        else
          neat _debug "Loading cheat (not from cache): \${cheat_file}..."
          neat _detect-env-additions source "\$cheat_file"
          new_cheat_data="\$cheat_name;\$cheat_file;\$NEAT_TMP_DATA"
          neat _write_cache "\$cheat_file" "\$NEAT_TMP_DATA"
          unset NEAT_TMP_DATA
        fi

        [ -n "\$NEAT_CHEAT_DATA" ] && NEAT_CHEAT_DATA="\$NEAT_CHEAT_DATA|"
        export NEAT_CHEAT_DATA="\$NEAT_CHEAT_DATA\$new_cheat_data"
      fi
      ;;

    list|cheats)
      command neat list
      ;;

    show)
      command neat "\$@"
      ;;

    ### Plumbing

    _debug)
      if [ -n "\$NEAT_DEBUG" ] && [ -n "\$2" ]; then
        echo "neat: \$2" >&2
      fi
      ;;

    _err)
      shift
      [ -n "\$@" ] && { echo "\$@" >&2; }
      return 1
      ;;

    _pathify)
      echo \$2 | tr "\$IFS" ':' | sed 's/:\$//'
      ;;

    _aliases)
      local raw_aliases
      if [ -n "\$ZSH_VERSION" ]; then
        raw_aliases="\$(alias)"
      else
        raw_aliases="\$(alias | cut -d ' ' -f 2-)"
       fi
      neat _pathify "\$(echo "\$raw_aliases" | cut -d '=' -f 1 | sort)"
      ;;

    _functions)
      local funcs
      if [ -n "\$ZSH_VERSION" ]; then
       funcs="\$(print -l \${(ok)functions})"
      else
        funcs="\$(typeset -F | cut -d ' ' -f 3)"
      fi
      neat _pathify "\$funcs"
      ;;

    _variables)
      neat _pathify "\$(env | cut -d '=' -f 1 | sort)"
      ;;

    # Capture names of aliases, functions, and variables in the current environment
    _capture-env)
      echo "\$(neat _aliases);\$(neat _functions);\$(neat _variables)"
      ;;

    # Run the given command command and detect additions to the environment that occurred
    _detect-env-additions)
      local before after additions additions_for_type
      before=\$(neat _capture-env)
      shift
      "\$@"
      after=\$(neat _capture-env)
      # TODO clean this up
      for n in 1 2 3; do
        additions_for_type=\$(comm -13 <(echo \$before | cut -d ';' -f "\$n" | tr ':' '\n') <(echo \$after | cut -d ';' -f "\$n" | tr ':' '\n'))
        additions="\${additions}\$(neat _pathify "\$additions_for_type")"
        [ "\$n" -lt "3" ] && additions="\$additions;"
      done
      # Ugh, figure out a way to not use this?
      NEAT_TMP_DATA="\$additions"
      ;;

    *)
      command neat "\$@"
      ;;

  esac
}
EOS
}

if [ -z "$1" ]; then
  print_help
else
  case "$1" in
    init) print_initialization ;;

    list) list_cheats ;;
    show|edit|which) ${1}_cheat "$2" ;;
    help) shift; print_help "$@" ;;

    _realpath|_read_cache|_write_cache)
      cmd=${1:1}
      shift
      $cmd "$@" ;;

  esac
fi
