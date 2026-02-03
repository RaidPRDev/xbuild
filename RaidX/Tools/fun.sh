#!/bin/bash

IS_DARWIN=$([ -x "$(command -v sw_vers)" ] && echo true || echo false)
if [ "$IS_DARWIN" = true ]; then
  RAID_X_HOME="$HOME/RaidX"
else
  RAID_X_HOME="/mnt/e/vms/macos/raidx/RaidX"
fi

GLOBALS_FILE="$RAID_X_HOME/Tools/ios/Support/globals.sh"
# shellcheck source=/dev/null
source "$GLOBALS_FILE"


# Animate dots around a rectangle while a background job runs
# rectangle_progress() {
#   local pid=$1
#   local frames=(
#     "[●     ]"  # left top
#     "[ ●    ]"
#     "[  ●   ]"
#     "[   ●  ]"
#     "[    ● ]"  # right top
#     "[     ●]"
#     "[    ● ]"
#     "[   ●  ]"
#     "[  ●   ]"
#     "[ ●    ]"  # left bottom
#   )

#   while kill -0 $pid 2>/dev/null; do
#     for frame in "${frames[@]}"; do
#       printf "\r%s" "$frame"
#       sleep 0.2
#       # break early if process finished mid-loop
#       kill -0 $pid 2>/dev/null || break
#     done
#   done
#   printf "\r[ Done ]\n"
# }

# Example: run sshpass scp in background
# sshpass -p "mypassword" scp file.txt user@remote:/path/ &
sleep 5 &

pid=$!
spinner_progress $pid uploading project
wait $pid