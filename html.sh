#!/bin/bash

INDENT="    " #doua spatii
INDENT_LEVEL=0

INLINE_TAGS="span|a|b|i|strong|em|p|title|br|li|h[1-6]|button|label|option|figcaption|textarea"
SELF_CLOSING_TAGS="img|br|hr|input|meta|link"
ROOT_LEVEL_TAGS="html|head|body"
LAST_ELEM="block"
INLINE_STACK=()
SUBLIST=()

process_fragment() {
  local fragment="$1"

  if [[ "$fragment" =~ ^\<\!DOCTYPE[[:space:]]+html\> ]]; then
    printf "%s\n" "$fragment" >> "$OUTPUT_FILE"
    return
  fi

  if [[ "$fragment" =~ ^\<([a-zA-Z0-9]+)([^>]*)\> ]]; then
    tag="${BASH_REMATCH[1]}"
    attrs="${BASH_REMATCH[2]}"

    if [[ "$tag" =~ ^($SELF_CLOSING_TAGS)$ ]]; then
      if [[ "$tag" =~ ^($INLINE_TAGS)$ ]]; then
        printf "<%s%s>" "$tag" "$attrs">> "$OUTPUT_FILE"
      else
        if [[ ${#INLINE_STACK[@]} -ne 0 ]]; then
          ((INDENT_LEVEL++))
          printf "\n" >> "$OUTPUT_FILE"
          printf "%s%s\n" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" "<$tag$attrs>" >> "$OUTPUT_FILE"
          printf "%s" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" >> "$OUTPUT_FILE"
          ((INDENT_LEVEL--))
      else
         printf "%s%s\n" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" "<$tag$attrs>" >> "$OUTPUT_FILE"
      fi
        LAST_ELEM="block"
      fi
    elif [[ "$tag" =~ ^($INLINE_TAGS)$ ]]; then
      if [[ ${#INLINE_STACK[@]} == 0 ]] || [[ ${#SUBLIST[@]} -gt 0 && ${#INLINE_STACK[@]} == ${SUBLIST[${#SUBLIST[@]}-1]} ]]; then 
        printf "%s" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" >> "$OUTPUT_FILE"
        printf "<%s%s>" "$tag" "$attrs">> "$OUTPUT_FILE"
      else
        printf "<%s%s>" "$tag" "$attrs">> "$OUTPUT_FILE"
      fi
      LAST_ELEM="inline"
      INLINE_STACK+=($tag)
    elif [[ "$tag" =~ ^($ROOT_LEVEL_TAGS)$ ]]; then
      INDENT_LEVEL=1
      printf "%s\n" "<$tag$attrs>" >> "$OUTPUT_FILE"
      LAST_ELEM="block"
    else
      if [[ ${#INLINE_STACK[@]} -ne 0 ]]; then
        ((INDENT_LEVEL++))
        printf "\n" >> "$OUTPUT_FILE"
        printf "%s%s\n" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" "<$tag$attrs>" >> "$OUTPUT_FILE"
        SUBLIST+=(${#INLINE_STACK[@]})
      else
        printf "%s%s\n" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" "<$tag$attrs>" >> "$OUTPUT_FILE"
      fi
      ((INDENT_LEVEL++))
      LAST_ELEM="block"
    fi
    return
  fi

  if [[ "$fragment" =~ ^\<\/([a-zA-Z0-9]+)\> ]]; then
    tag="${BASH_REMATCH[1]}"

    if [[ "$tag" =~ ^($ROOT_LEVEL_TAGS)$ ]]; then
      printf "%s\n" "</$tag>" >> "$OUTPUT_FILE"
      LAST_ELEM="block"
    elif [[ "$tag" =~ ^($INLINE_TAGS)$ ]]; then
      unset 'INLINE_STACK[${#INLINE_STACK[@]}-1]' 
      if [[ ${#INLINE_STACK[@]} == 0 ]] || [[ ${#SUBLIST[@]} -gt 0 && ${#INLINE_STACK[@]} == ${SUBLIST[${#SUBLIST[@]}-1]} ]]; then
        printf "%s\n" "</$tag>" >> "$OUTPUT_FILE"
      else
        printf "%s" "</$tag>" >> "$OUTPUT_FILE"
      fi
      LAST_ELEM="inline"
    else
      ((INDENT_LEVEL--))
      printf "%s%s\n" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" "</$tag>" >> "$OUTPUT_FILE"
      LAST_ELEM="block"
      if [[ ${#SUBLIST[@]} -gt 0 && ${#INLINE_STACK[@]} == ${SUBLIST[${#SUBLIST[@]}-1]} ]]; then
        ((INDENT_LEVEL--))
        unset 'SUBLIST[${#SUBLIST[@]}-1]'
        printf "%s" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" >> "$OUTPUT_FILE"
      fi
    fi
    return
  fi

  if [[ -n "$fragment" ]] && [[ "$LAST_ELEM" == "block" ]]; then
    printf "%s%s\n" "$(printf "$INDENT%.0s" $(seq 1 $INDENT_LEVEL))" "$fragment" >> "$OUTPUT_FILE"
  else
    printf "%s" "$fragment" >> "$OUTPUT_FILE"
  fi

}



pretty_print() {
  while IFS= read -r line || [[ -n "$line" ]]; do 
    line=$(echo "$line" | sed -E 's/[[:space:]]+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') 

    while [[ -n "$line" ]]; do
      if [[ "$line" =~ ^([^<]*)(\<[^>]+\>)(.*) ]]; then 
        text="${BASH_REMATCH[1]}" 
        tag="${BASH_REMATCH[2]}"
        rest="${BASH_REMATCH[3]}"

        [[ -n "$text" ]] && process_fragment "$text"

        process_fragment "$tag"

        line="$rest"
      else
        process_fragment "$line"
        line=""
      fi
    done
  done
}

if [[ $# -lt 2 ]]; then 
  echo "Usage: $0 <input_file.html> <output_file.html>"
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [[ ! -f "$INPUT_FILE" ]]; then 
  echo "Error: Input file not found: $INPUT_FILE"
  exit 1
fi

> "$OUTPUT_FILE" 

cat "$INPUT_FILE" | pretty_print 
echo "Formatted HTML written to $OUTPUT_FILE"


