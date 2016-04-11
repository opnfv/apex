#!/usr/bin/env bash
# Utility script used to interact with a deployment
# @author Tim Rozet (trozet@redhat.com)

CONFIG=/var/opt/opnfv

source $CONFIG/utility-functions.sh

display_usage() {
  echo -e "Usage:\n$0 [arguments] \n"
  echo -e "   -u|--undercloud : Connect to Undercloud VM \n"
  echo -e "   -d|--debug_stack : Print parsed deployment failures to stdout \n"
}

##translates the command line parameters into variables
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {

  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
        -h|--help)
                display_usage
                exit 0
            ;;
        -u|--undercloud)
                undercloud_connect
                exit 0
            ;;
        -d|--debug-stack)
                undercloud_connect "$(typeset -f debug_stack); debug_stack"
                exit 0
            ;;
        *)
                echo -e "\n\nThis script is used to interact with Apex deployments\n\n"
                echo "Use -h to display help"
                exit 1
            ;;
    esac
  done
}


main() {
  parse_cmdline "$@"
}

main "$@"