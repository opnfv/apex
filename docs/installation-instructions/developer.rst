Developer Guide and Troubleshooting
===================================

This section aims to explain a bit more in detail the steps that Apex follows to make a deployment. It also tries to explain possible issues you might find in the process of building or deploying an environment.

After installing the Apex RPMs in the jumphost, some files will be located around the system. 

1.  /etc/opnfv-apex: this directory contains a bunch of scenarios to be deployed with different characteristics such HA (High Availability), SDN controller integration (OpenDaylight/ONOS), BGPVPN, FDIO, etc. Having a look at any of these files will give you an idea of how to make a customized scenario setting up different flags.

2.  /bin/: it contains the binaries for the commands opnfv-deploy, opnfv-clean and opnfv-util.

3.  /var/opt/opnfv/: it contains several files and directories.

   3.1.   images/: this folder contains the images that will be deployed according to the chosen scenario.

   3.2.   lib/: bunch of scripts that will be executed in the different phases of deployment.


Utilization of images
---------------------

As mentioned earlier in this guide, the Undercloud VM will be in charge of deploying OPNFV (Overcloud VMs). Since the Undercloud is an all-in-one OpenStack deployment, it will use Glance to manage the images that will be deployed as the Overcloud.

So whatever customization that is done to the images located in the jumpserver (/var/opt/opnfv/images) will be uploaded to the undercloud and consequently, to the overcloud.

Make sure, the customization is performed on the right image. For example, if I virt-customize the following image overcloud-full-opendaylight.qcow2, but then I deploy OPNFV with the following command:

        ``sudo opnfv-deploy -n network_settings.yaml -d /etc/opnfv-apex/os-onos-nofeature-ha.yaml``

It will not have any effect over the deployment, since the customized image is the opendaylight one, and the scenario indicates that the image to be deployed is the overcloud-full-onos.qcow2.


Post-deployment Configuration
-----------------------------

Post-deployment scripts will perform some configuration tasks such ssh-key injection, network configuration, NATing, OpenVswitch creation. It will take care of some OpenStack tasks such creation of endpoints, external networks, users, projects, etc.

If any of these steps fail, the execution will be interrupted. In some cases, the interruption occurs at very early stages, so a new deployment must be execute. However, some other cases it could be worth it to try to debug it.

        1.  There is not external connectivity from the overcloud nodes:

                Post-deployment scripts will configure the routing, nameservers and a bunch of other things between the overcloud and the undercloud. If local connectivity, like pinging between the
                different nodes, is working fine, script must have failed when configuring the NAT via iptables. The main rules to enable external connectivity would look like these:

                ``iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE``
                ``iptables -t nat -A POSTROUTING -s ${external_cidr} -o eth0 -j MASQUERADE``
                ``iptables -A FORWARD -i eth2 -j ACCEPT``
                ``iptables -A FORWARD -s ${external_cidr} -m state --state ESTABLISHED,RELATED -j ACCEPT``
                ``service iptables save``

                These rules must be executed as root (or sudo) in the undercloud machine.


        2.  I can see in the output log a post-deployment error messages:

                Puppet applies some manifests during this phase. If one of these processes fail, you could try to see the error and after that, re-run puppet to apply that manifest. Log into the
                controller (see verification section for that) and check as root /var/log/messages. Search for the error you have encountered and see if you can fix it. In order to re-run the puppet
                manifest, search for "puppet apply" in that same log. You will have to run the last "puppet apply" before the error. And It should look like this:

                ``FACTER_heat_outputs_path="/var/run/heat-config/heat-config-puppet/5b4c7a01-0d63-4a71-81e9-d5ee6f0a1f2f"  FACTER_fqdn="overcloud-controller-0.localdomain.com" \
                FACTER_deploy_config_name="ControllerOvercloudServicesDeployment_Step4"  puppet apply --detailed-exitcodes -l syslog -l console \
                /var/lib/heat-config/heat-config-puppet/5b4c7a01-0d63-4a71-81e9-d5ee6f0a1f2f.pp``

                As a comment, there are four "puppet apply" steps at the moment running four different manifests.

OpenDaylight integration
------------------------

When a user deploys any of the following scenarios:

        - os-odl_l2-bgpvpn-ha.yaml
        - os-odl_l2-fdio-ha.yaml
        - os-odl_l2-fdio-noha.yaml
        - os-odl_l2-nofeature-ha.yaml
        - os-odl_l2-sfc-noha.yaml
        - os-odl_l3-nofeature-ha.yaml

OpenDaylight (ODL) SDN controller will be deployed too and completely integrated with OpenStack. ODL is running as a systemd service, so you can manage it as a regular service:

        ``systemctl start/restart/stop opendaylight.service``

This command must be executed as root in the controller node of the overcloud, where OpenDaylight is running. ODL files are located in /opt/opendaylight.
ODL uses karaf as a Java container management system that allows the users to install new features, check logs and configure a lot of things. In order to connect to Karaf's console, use the 
following command:

        ``opnfv-util opendaylight``

This command is very easy to use, but in case it is not connecting to Karaf, this is the command that is executing underneath:

        ``ssh -p 8101 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no karaf@localhost``

Of course, localhost when the command is executed in the overcloud controller, but you use its public IP to connect from elsewhere.


