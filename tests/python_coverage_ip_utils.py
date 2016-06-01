import sys
from apex import ip_utils

iface = ip_utils.get_interface(sys.argv[1])

erroring_tests = (
        "ip_utils.get_interface('')",
        "ip_utils.get_interface('lo', address_family=0)",
        "ip_utils.get_interface('lo', address_family=6)",
        "ip_utils.get_interface('lo')",
        "ip_utils.get_ip_range()",
        "ip_utils.get_ip_range(interface=iface)")

for t in erroring_tests:
    try:
        eval(t)
    except:
        pass

#ip_utils.generate_ip_range(ArgsObject())
ip_utils.find_gateway(interface=iface)
ip_utils.get_ip(1, cidr="10.10.10.0/24")
ip_utils.get_ip(1, interface=iface)
ip_utils.get_ip_range(interface=iface, start_offset=1, end_offset=20)
ip_utils.get_ip_range(interface=iface, start_offset=1, count=10)
ip_utils.get_ip_range(interface=iface, end_offset=20, count=10)
#ip_utils.get_ip_range(start_offset=None, count=None, end_offset=None, 
#                         cidr=None, interface=None): 
