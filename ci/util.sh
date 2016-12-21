#!/usr/bin/env bash
# Utility script used to interact with a deployment
# @author Tim Rozet (trozet@redhat.com)

# Backwards compat for old ENV Vars
# Remove in E Release
if [ -n "$CONFIG" ]; then
    echo -e "${red}WARNING: ENV var CONFIG is Deprecated, please unset CONFIG and export BASE in its place${reset}"
    echo -e "${red}WARNING: CONFIG will be removed in E${reset}"
    BASE=$CONFIG
fi
if [ -n "$RESOURCES" ]; then
    echo -e "${red}WARNING: ENV var RESOURCES is Deprecated, please unset RESOURCES and export IMAGES in its place${reset}"
    echo -e "${red}WARNING: RESOURCES will be removed in E${reset}"
    IMAGES=$RESOURCES
fi

BASE=${BASE:-'/var/opt/opnfv'}
IMAGES=${IMAGES:-"$BASE/images"}
LIB=${LIB:-"$BASE/lib"}
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
  echo -e "   undercloud [ user [ command ] ]   Connect to Undercloud VM as user and optionally execute a command"
  echo -e "                                     user    Optional: Defaults to 'stack'"
  echo -e "                                     command Optional: Defaults to none"
  echo -e ""
  echo -e "   opendaylight                      Connect to OpenDaylight Karaf console"
  echo -e ""
  echo -e "   overcloud  [ node [ command ] ]   Connect to an Overcloud node and optionally execute a command"
  echo -e "                                     node    Required: in format controller|compute<number>.  Example: controller0"
  echo -e "                                     command Optional: Defaults to none"
  echo -e ""
  echo -e "   debug-stack                       Print parsed deployment failures to stdout"
  echo -e ""
  echo -e "   mock-detached on | off            Add firewall rules to the jump host to mock a detached deployment\n"
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
                    echo "Ensuring we can talk to gerrit.opnfv.org"
                    iptables -A OUTPUT -p tcp -d gerrit.opnfv.org --dport 443 -j ACCEPT
                    echo "Blocking output http (80) traffic"
                    iptables -A OUTPUT -p tcp --dport 80 -j REJECT
                    iptables -A FORWARD -p tcp --dport 80 -j REJECT
                    echo "Blocking output https (443) traffic"
                    iptables -A OUTPUT -p tcp --dport 443 -j REJECT
                    iptables -A FORWARD -p tcp --dport 443 -j REJECT
                    echo "Blocking output dns (53) traffic"
                    iptables -A FORWARD -p tcp --dport 53 -j REJECT
                elif [ "$2" == "off" ]; then
                    echo "Cleaning gerrit.opnfv.org specific rule"
                    iptables -D OUTPUT -p tcp -d gerrit.opnfv.org --dport 443 -j ACCEPT
                    echo "Allowing output http (80) traffic"
                    iptables -D OUTPUT -p tcp --dport 80 -j REJECT
                    iptables -D FORWARD -p tcp --dport 80 -j REJECT
                    echo "Allowing output https (443) traffic"
                    iptables -D OUTPUT -p tcp --dport 443 -j REJECT
                    iptables -D FORWARD -p tcp --dport 443 -j REJECT
                    echo "Allowing output dns (53) traffic"
                    iptables -D OUTPUT -p tcp --dport 53 -j REJECT
                    iptables -D FORWARD -p tcp --dport 53 -j REJECT
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
