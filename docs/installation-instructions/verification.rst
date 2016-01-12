Verifying the Setup
-------------------

Once the deployment has finished, the OPNFV deployment can be accessed via the Instack node. From
the jump host ssh to the instack host and become the stack user. Alternativly ssh keys have been
setup such that the root user on the jump host can ssh to Instack directly as the stack user.

| ``ssh root@192.0.2.1``
| ``su - stack``

Once connected to Instack as the stack user look for two keystone files that can be used to
interact with the undercloud and the overcloud. Source the appropriate RC file to interact with
the respective OpenStack deployment.

| ``source stackrc`` (undercloud / Instack)
| ``source overcloudrc`` (overcloud / OPNFV)

The contents of these files include the credentials for the administrative user for Instack and
OPNFV respectivly. At this point both Instack and OPNFV can be interacted with just as any
OpenStack installation can be. Start by listing the nodes in the undercloud that were used
to deploy the overcloud.

| ``source stackrc``
| ``openstack server list``

The control and compute nodes will be listed in the output of this server list command. The IP
addresses that are listed are the control plane addresses that were used to provision the nodes.
Use these IP addresses to connect to these nodes. Initial authentication requires using the
user heat-admin.

| ``ssh heat-admin@192.0.2.7``

To begin creating users, images, networks, servers, etc in OPNFV source the overcloudrc file or
retrieve the admin user's credentials from the overcloudrc file and connect to the web Dashboard.


You are now able to follow the `OpenStack Verification`_ section.

OpenStack Verification
----------------------

Once connected to the OPNFV Dashboard make sure the OPNFV target system is working correctly:

1.  In the left pane, click Compute -> Images, click Create Image.

2.  Insert a name "cirros", Insert an Image Location
    ``http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img``.

3.  Select format "QCOW2", select Public, then click Create Image.

4.  Now click Project -> Network -> Networks, click Create Network.

5.  Enter a name "internal", click Next.

6.  Enter a subnet name "internal_subnet", and enter Network Address ``172.16.1.0/24``, click Next.

7. Now go to Project -> Compute -> Instances, click Launch Instance.

8. Enter Instance Name "first_instance", select Instance Boot Source "Boot from image",
   and then select Image Name "cirros".

9. Click Launch, status will cycle though a couple states before becoming "Active".

10. Steps 7 though 9 can be repeated to launch more instances.

11. Once an instance becomes "Active" their IP addresses will display on the Instances page.

12. Click the name of an instance, then the "Console" tab and login as "cirros"/"cubswin:)"

13. To verify storage is working, click Project -> Compute -> Volumes, Create Volume

14. Give the volume a name and a size of 1 GB

15. Once the volume becomes "Available" click the dropdown arrow and attach it to an instance.

Congratulations you have successfully installed OPNFV!
