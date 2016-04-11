#!/usr/bin/env bash
# Utility script used to interact with a deployment
# @author Tim Rozet (trozet@redhat.com)

CONFIG=/var/opt/opnfv
VALID_CMDS="undercloud debug-stack -h --help"

source $CONFIG/utility-functions.sh

resolve_cmd() {
  local given=$1
  shift
  local list=($*)
  local inv=(${list[*]##${given}*})
  local OIFS=$IFS; IFS='|'; local pat="${inv[*]}"; IFS=$OIFS
  shopt -s extglob
  echo "${list[*]##+($pat)}"
  shopt -u extglob
}

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   undercloud <user> : Connect to Undercloud VM as <user>\n"
  echo -e "   debug_stack : Print parsed deployment failures to stdout \n"
}

##translates the command line argument
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {
  local match

  match=($(resolve_cmd $1 $VALID_CMDS))
  if [ ${#match[*]} -gt 1 ]; then
    echo "$1 is ambiguous, possible matches: ${match[*]}" >&2
    exit 1
  elif [ ${#match[*]} -lt 1 ]; then
    echo "$1 is not a recognized command.  Use -h to see acceptable list" >&2
    exit 1
  else
    match=$(echo $match | tr -d ' ')
  fi

  case "$match" in
        -h|--help)
                display_usage
                exit 0
            ;;
        undercloud)
                if [ -z "$2" ]; then
                  # connect as stack by default
                  undercloud_connect stack
                else
                  undercloud_connect $2
                fi
                exit 0
            ;;
        debug-stack)
                undercloud_connect stack "$(typeset -f debug_stack); debug_stack"
                exit 0
            ;;
        *)
                echo -e "\n\nThis script is used to interact with Apex deployments\n\n"
                echo "Use -h to display help"
                exit 1
            ;;
  esac
}


main() {
  parse_cmdline "$@"
}

main "$@"