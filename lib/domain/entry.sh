#!/usr/bin/env bash
# Domain: Entry parsing and formatting

entry_header_create() {
  local mood="$1" title="$2" tags="${3:-}"
  local date_str
  date_str=$(date '+%Y-%m-%d %H:%M:%S')
  
  cat <<EOF
# Date: $date_str
# Mood: $mood
# Title: $title
# Tags: $tags
#────────────────────────────────────────
EOF
}

# Parse an entry file and extract metadata
entry_parse() {
  local file="$1"
  local -n _meta="$2"
  
  [[ -f "$file" ]] || return 1
  
  _meta[date]=$(grep -m1 '^# Date:' "$file" | cut -d':' -f2- | xargs)
  _meta[mood]=$(grep -m1 '^# Mood:' "$file" | cut -d':' -f2- | xargs)
  _meta[title]=$(grep -m1 '^# Title:' "$file" | cut -d':' -f2- | xargs)
  _meta[tags]=$(grep -m1 '^# Tags:' "$file" | cut -d':' -f2- | xargs)
  _meta[filename]=$(basename "$file")
  _meta[path]="$file"
  
  # Calculate body stats
  local body
  body=$(sed '1,/^#─*$/d' "$file")
  _meta[body]="$body"
  _meta[words]=$(echo "$body" | wc -w | xargs)
  _meta[lines]=$(echo "$body" | wc -l | xargs)
  _meta[chars]=$(echo "$body" | wc -c | xargs)
}

# Get a preview of entry content (first N characters)
entry_preview() {
  local file="$1" max_chars="${2:-80}"
  local body
  body=$(sed '1,/^#─*$/d' "$file" | tr '\n' ' ' | sed 's/  */ /g')
  
  if [[ ${#body} -gt $max_chars ]]; then
    echo "${body:0:$max_chars}..."
  else
    echo "$body"
  fi
}

# Get mood color based on value
entry_mood_color() {
  local mood="$1"
  local color="$GREEN"
  
  if [[ $mood =~ ^[0-9]+$ ]]; then
    if (( mood <= 3 )); then
      color="$RED"
    elif (( mood <= 6 )); then
      color="$YELLOW"
    fi
  else
    case "${mood,,}" in
      happy|great|good|excited|joy*|elated*|wonderful|amazing|fantastic)
        color="$GREEN" ;;
      meh|okay|fine|neutral|average|alright)
        color="$YELLOW" ;;
      sad|depress*|angry|bad|tired|anxious|stressed|upset|terrible)
        color="$RED" ;;
      *)
        color="$CYAN" ;;
    esac
  fi
  
  echo "$color"
}

# Convert numeric mood to emoji (for display)
entry_mood_emoji() {
  local mood="$1"
  
  if [[ $mood =~ ^[0-9]+$ ]]; then
    case $mood in
      1|2)   echo "😢" ;;
      3|4)   echo "😕" ;;
      5|6)   echo "😐" ;;
      7|8)   echo "🙂" ;;
      9|10)  echo "😄" ;;
      *)     echo "❓" ;;
    esac
  else
    case "${mood,,}" in
      happy|great|good|excited|joy*|elated*|wonderful|amazing)
        echo "😄" ;;
      meh|okay|fine|neutral|average)
        echo "😐" ;;
      sad|depress*|upset|terrible)
        echo "😢" ;;
      angry|frustrated|annoyed)
        echo "😠" ;;
      tired|exhausted)
        echo "😴" ;;
      anxious|stressed|worried)
        echo "😰" ;;
      *)
        echo "📝" ;;
    esac
  fi
}

# Validate entry file structure
entry_validate() {
  local file="$1"
  
  [[ -f "$file" ]] || return 1
  grep -q '^# Date:' "$file" || return 1
  grep -q '^#─\{10,\}' "$file" || return 1
  
  return 0
}
