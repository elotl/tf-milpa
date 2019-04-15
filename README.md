# Set up a Milpa server with Terraform

This is a Terraform configuration for provisioning a simple (one server, embedded etcd, no high availability) [Milpa](https://www.elotl.co/kiyotdocs) cluster.

## Setup

Create a file at `~/env.tfvars`:

    cluster-name = "my-cluster-name"
    aws-access-key-id = "my-access-key"
    aws-secret-access-key = "my-secret-key"
    ssh-key-name = "my-ssh-key-on-EC2"
    # Get your license at https://www.elotl.co/trial.
    license-key = ""
    license-id = ""
    license-username = ""
    license-password = ""

Fill in all those variables, then apply the configuration:

    $ terraform init # Only needed the first time.
    [...]
    $ terraform apply -var-file ~/env.tfvars
    [...]
    Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
    
    Outputs:
    
    milpa_ip = 54.162.87.155

This will create a VPC, an instance and installs Milpa on it.

SSH into the instance and check the status of the cluster:

    ubuntu@ip-10-0-100-92:~$ milpactl version
    Milpa server version: {"Major":"1","Minor":"1","GitVersion":"1.1.4","GitCommit":"b21b8ef","GitTreeState":"clean"}
    ubuntu@ip-10-0-100-92:~$

At this point, the cluster is ready to use.

## Teardown

Use Terraform to tear down the infrastructure:

    $ terraform destroy -var-file ~/env.tfvars
    [...]
    Plan: 0 to add, 0 to change, 7 to destroy.
    
    Do you really want to destroy all resources?
      Terraform will destroy all your managed infrastructure, as shown above.
      There is no undo. Only 'yes' will be accepted to confirm.
    
      Enter a value: yes

    [...]

    Destroy complete! Resources: 7 destroyed.
