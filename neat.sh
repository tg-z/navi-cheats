#!/usr/bin/env bash

# neat 
# neat usage: 

fd . -e cheat -t f -d 2 
neat () {
  echo "cheats:" 
}


count() {
  # Usage: count /path/to/dir/*
  #        count /path/to/dir/*/
  # count ~/repos/navi-cheats/*/*.cheat
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


