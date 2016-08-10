#!/usr/bin/env bash
# Utility script used to interact with a deployment
# @author Tim Rozet (trozet@redhat.com)

CONFIG=${CONFIG:-'/var/opt/opnfv'}
RESOURCES=${RESOURCES:-"$CONFIG/images"}
LIB=${LIB:-"$CONFIG/lib"}
VALID_CMDS="undercloud overcloud opendaylight debug-stack mock-detached -h --help"

source $LIB/utility-functions.sh

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
  echo -e "Usage:\n$0 subcommand [ arguments ]\n"
  echo -e "Arguments:\n"
  echo -e "   undercloud [ user [ command ] ]   Connect to Undercloud VM as user and optionally execute a command\n"
  echo -e "                                     user    Optional: Defaults to 'stack'\n"
  echo -e "                                     command Optional: Defaults to none\n"
  echo -e ""
  echo -e "   opendaylight                      Connect to OpenDaylight Karaf console\n"
  echo -e ""
  echo -e "   overcloud  [ node [ command ] ]   Connect to an Overcloud node and optionally execute a command\n"
  echo -e "                                     node    Required: in format controller|compute<number>.  Example: controller0\n"
  echo -e "                                     command Optional: Defaults to none\n"
  echo -e ""
  echo -e "   debug-stack                       Print parsed deployment failures to stdout \n"
  echo -e ""
  echo -e "   mock-detached on | off            Add firewall rules to the jump host to mock a detached deployment \n"
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
                elif [ -z "$3" ]; then
                  undercloud_connect "$2"
                else
                  undercloud_connect "$2" "$3"
                fi
                exit 0
            ;;
        overcloud)
                if [ -z "$2" ]; then
                  overcloud_connect
                elif [ -z "$3" ]; then
                  overcloud_connect "$2"
                else
                  overcloud_connect "$2" "$3"
                fi
                exit 0
            ;;
        opendaylight)
                opendaylight_connect
                exit 0
            ;;
        debug-stack)
                undercloud_connect stack "$(typeset -f debug_stack); debug_stack"
                exit 0
            ;;
        mock-detached)
                if [ "$2" == "on" ]; then
                    echo "Blocking output http and https traffic"
                    iptables -A OUTPUT -p tcp --dport 80 -j REJECT
                    iptables -A OUTPUT -p tcp --dport 443 -j REJECT
                elif [ "$2" == "off" ]; then
                    echo "Allowing output http and https traffic"
                    iptables -D OUTPUT -p tcp --dport 80 -j REJECT
                    iptables -D OUTPUT -p tcp --dport 443 -j REJECT
                else
                    display_usage
                fi
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
