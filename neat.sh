#!/usr/bin/env bash

# neat usage
# neat 

neat () {
  echo "cheats:" 
  fd . -e cheat -t f -d 2 
}


count() {
  # Usage: count /path/to/dir/*
  #        count /path/to/dir/*/
  # count ~/repos/navi-cheats/*.cheat
  printf '%s\n' "$#"
}
head() {
  # Usage: head "n" "file"
  mapfile -tn "$1" line < "$2"
  printf '%s\n' "${line[@]}"
}

list_cheats() {
  echo $NEAT_CHEAT_DATA | tr '|' '\n' | cut -d ';' -f 1
}
basename() {
  # Usage: basename "path" ["suffix"]
  local tmp
  
  tmp=${1%"${1##*[!/]}"}
  tmp=${tmp##*/}
  tmp=${tmp%"${2/"$tmp"}"}
  
  printf '%s\n' "${tmp:-/}"
}


for file in ~/repos/navi-cheats/*.cheat; do
  printf '%s\n' "$file"
done

usage()
{
  cat <<EOF
  neat
  description: utility to manage navi cheat files
  usage: neat [flag] [cheat] or neat [flag]
  -t  show tags associated with cheat file
  -s  Shorten the URL
  -e  Expand a shortened URL
  -r  search tags + files
  -h  show this help text 
  -v  get the tool version
  example:
  input:  bash neat.sh -t brew
  output: brew tags: osx, cli
  EOF
}
